"""
Nuromathix Backend — Flask API  (Model 2 build)
Model 1 : Random Forest difficulty score 1-5 per chunk
Model 2 : Prompt-engineered adaptive question generator (Gemini 1.5 Flash)
          - mixes easy (fill-blank) / medium (short-answer) / hard (4-part problem)
          - prioritises chunks using Model 1's per-chunk difficulty + weak topics
          - progressive 10-level contextual hints (generated on request)
          - per-question timing, timeout/overtime tracking
XAI     : Full step-by-step explanation per answer (all formats)
Curve   : Ebbinghaus R(t)=e^(-t/S) forgetting curve, paced by study mode
"""
import os,json,uuid,math,pickle,re,logging,random
from datetime import datetime,timedelta
from flask import Flask,request,jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import PyMongoError
import fitz
import urllib.request,urllib.error

load_dotenv()  # reads backend/.env if present (never commit this file)

logging.basicConfig(level=logging.INFO)
log=logging.getLogger(__name__)
app=Flask(__name__)
CORS(app)

# ── Session storage: MongoDB, with in-memory fallback ─────────────────────────
MONGO_URI=os.environ.get("MONGO_URI","mongodb://localhost:27017")
MONGO_DB_NAME=os.environ.get("MONGO_DB_NAME","neuromathix")

_sessions_col=None
_materials_col=None
_memory_sessions:dict={}
_memory_materials:dict={}

try:
    _client=MongoClient(MONGO_URI,serverSelectionTimeoutMS=3000)
    _client.admin.command("ping")
    _sessions_col=_client[MONGO_DB_NAME]["sessions"]
    _materials_col=_client[MONGO_DB_NAME]["materials"]
    log.info("[OK] Connected to MongoDB at %s (db=%s)",MONGO_URI,MONGO_DB_NAME)
except PyMongoError as e:
    log.warning("[WARN] MongoDB not reachable (%s). Falling back to in-memory storage.",e)

def _session_get(sid):
    if _sessions_col is not None:
        return _sessions_col.find_one({"_id":sid})
    return _memory_sessions.get(sid)

def _session_save(sid,doc):
    doc["_id"]=sid
    if _sessions_col is not None:
        _sessions_col.replace_one({"_id":sid},doc,upsert=True)
    else:
        _memory_sessions[sid]=doc

def _session_update(sid,updates):
    if _sessions_col is not None:
        _sessions_col.update_one({"_id":sid},{"$set":updates})
    else:
        _memory_sessions.setdefault(sid,{}).update(updates)

def _session_exists(sid):
    return _session_get(sid) is not None

def _sessions_for_material(material_id):
    if _sessions_col is not None:
        return list(_sessions_col.find({"material_id":material_id}).sort("session_number",1))
    return sorted([s for s in _memory_sessions.values() if s.get("material_id")==material_id],
        key=lambda s:s.get("session_number",0))

# ── Materials: the uploaded PDF itself, persisted once under the user's
#    profile. A user can start any number of sessions (quiz attempts) against
#    the same material without re-uploading — this is what actually makes
#    "session 2 adapts to session 1" possible, since both sessions now share
#    one material_id and one chunk_coverage tracker. ──
def _material_get(mid):
    if _materials_col is not None:
        return _materials_col.find_one({"_id":mid})
    return _memory_materials.get(mid)

def _material_save(mid,doc):
    doc["_id"]=mid
    if _materials_col is not None:
        _materials_col.replace_one({"_id":mid},doc,upsert=True)
    else:
        _memory_materials[mid]=doc

def _material_update(mid,updates):
    if _materials_col is not None:
        _materials_col.update_one({"_id":mid},{"$set":updates})
    else:
        _memory_materials.setdefault(mid,{}).update(updates)

def _material_exists(mid):
    return _material_get(mid) is not None

def _materials_for_user(user_id):
    if _materials_col is not None:
        return list(_materials_col.find({"user_id":user_id}).sort("uploaded_at",-1))
    return sorted([m for m in _memory_materials.values() if m.get("user_id")==user_id],
        key=lambda m:m.get("uploaded_at",""),reverse=True)

GEMINI_API_KEY=os.environ.get("GEMINI_API_KEY","")
GEMINI_URL=f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
GEMINI_WORKS=False if not GEMINI_API_KEY else None
if not GEMINI_API_KEY:
    log.warning("[WARN] GEMINI_API_KEY not set — using local fallback generator/hints, not Gemini.")

MODEL1_RF=None;MODEL1_VEC=None;MODEL_INFO=None
try:
    with open("model1_random_forest.pkl","rb") as f: MODEL1_RF=pickle.load(f)
    with open("model1_vectorizer.pkl","rb") as f: MODEL1_VEC=pickle.load(f)
    try:
        with open("model_info.pkl","rb") as f: MODEL_INFO=pickle.load(f)
    except:pass
    log.info("[OK] Model 1 loaded classes=%s",MODEL1_RF.classes_.tolist())
except Exception as e:
    log.warning("[WARN] Model 1 not found: %s",e)

DLVL={1:"very_easy",2:"easy",3:"medium",4:"hard",5:"very_hard"}

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG — question mix, timing, session pacing
# ══════════════════════════════════════════════════════════════════════════════
MIN_QUESTIONS=20
MAX_QUESTIONS=50
TIME_ALLOTMENT={"easy":90,"medium":150,"hard":480}   # seconds per format
MAX_HINT_LEVEL=10
MASTERY_MAX_SESSIONS=8       # "until mastery" mode never plans more than this
MASTERY_MIN_GAP_DAYS=1
MASTERY_MAX_GAP_DAYS=14      # never lets a gap balloon into months/years
FIXED_MODE_MAX_GAP_DAYS=14
SESSION_TIME_BUDGET_SECONDS=2700   # ~45 min target ceiling for one sitting

MATH_KEYWORDS={"equation","equations","theorem","proof","integral","integrals","derivative",
    "derivatives","matrix","matrices","vector","vectors","polynomial","calculus","algebra",
    "geometry","probability","function","functions","variable","variables","coefficient",
    "limit","limits","differential","summation","formula","formulas","solve","solution",
    "root","roots","graph","axis","angle","triangle","vertex","slope","logarithm","exponent",
    "factorial","determinant","eigenvalue","statistics","distribution","mean","variance",
    "convergence","iteration","interval","numerical","approximation","theorem","hypothesis"}
MATH_SYMBOLS=set("+-*/=^√∫∑∞≤≥±×÷π∂∇∆θαβγλμσ")
MATH_SCORE_THRESHOLD=0.55   # heuristic; tune if false positives/negatives appear

def is_math_document(full_text):
    """Heuristic math-subject gate, run before Model 1. No ML training data
    needed — combines math keyword density, math symbol density, and digit
    density. Not perfect; logs its raw score so the threshold can be tuned."""
    text=full_text.lower()
    words=re.findall(r"[a-zA-Z]+",text)
    total_words=max(len(words),1)
    kw_hits=sum(1 for w in words if w in MATH_KEYWORDS)
    kw_ratio=kw_hits/total_words
    symbol_hits=sum(full_text.count(s) for s in MATH_SYMBOLS)
    symbol_density=symbol_hits/max(len(full_text),1)
    digit_ratio=sum(c.isdigit() for c in full_text)/max(len(full_text),1)
    score=(kw_ratio*40)+(symbol_density*300)+(digit_ratio*15)
    is_math=score>=MATH_SCORE_THRESHOLD
    confidence=round(min(1.0,score/2.0),3)
    reason=f"keyword_ratio={kw_ratio:.4f} symbol_density={symbol_density:.5f} digit_ratio={digit_ratio:.4f} raw_score={score:.3f} threshold={MATH_SCORE_THRESHOLD}"
    return is_math,confidence,reason

def extract_chunks(pdf_bytes,wpc=300,max_chunks=40):
    doc=fitz.open(stream=pdf_bytes,filetype="pdf")
    text=" ".join(p.get_text() for p in doc)
    words=text.split();out=[]
    for i in range(0,len(words),wpc):
        c=" ".join(words[i:i+wpc]).strip()
        if len(c)>60 and not _is_toc_like(c):out.append(c)
    if not out:
        # Whole document looked like TOC/reference matter — better to proceed
        # with something than reject outright; fall back to unfiltered chunks.
        log.warning("[extract_chunks] every chunk looked like TOC/index text — using unfiltered chunks")
        for i in range(0,len(words),wpc):
            c=" ".join(words[i:i+wpc]).strip()
            if len(c)>60:out.append(c)
    return out[:max_chunks],text

def _is_toc_like(text):
    """Detects table-of-contents / index / 'answers to exercises' listing
    pages so they're skipped before question generation. These pages are
    dense with unit/section markers and page-count parentheticals but have
    almost no real explanatory sentences — blanking a word from them
    produces meaningless questions."""
    markers=0
    markers+=len(re.findall(r"\bUNIT\s+\d",text,re.IGNORECASE))
    markers+=text.count("Exercises")
    markers+=len(re.findall(r"Answers to",text,re.IGNORECASE))
    markers+=len(re.findall(r"\b\d+\.\d+\b",text))          # section numbers: 9.1, 9.2, ...
    markers+=len(re.findall(r"\(\d+\s*pages?\)",text,re.IGNORECASE))  # "(9 pages)"
    word_count=max(len(text.split()),1)
    density=markers/word_count
    return density>0.10   # tuned threshold — TOC pages score far above this

def predict_difficulty(text):
    if MODEL1_RF and MODEL1_VEC:
        try:
            X=MODEL1_VEC.transform([text])
            score=int(MODEL1_RF.predict(X)[0])
            proba=MODEL1_RF.predict_proba(X)[0].tolist()
            return{"score":score,"level":DLVL.get(score,"medium"),"confidence":round(float(max(proba)),3),"source":"model1_rf"}
        except Exception as e:log.warning("M1 err:%s",e)
    words=text.split();avg=sum(len(w) for w in words)/max(len(words),1)
    s=min(5,max(1,round(avg-1)))
    return{"score":s,"level":DLVL.get(s,"medium"),"confidence":0.55,"source":"heuristic"}

# ══════════════════════════════════════════════════════════════════════════════
# MODEL 2 — chunk prioritisation + question-mix planning
# ══════════════════════════════════════════════════════════════════════════════
def determine_question_count(num_chunks):
    return max(MIN_QUESTIONS,min(MAX_QUESTIONS,num_chunks*2))

def determine_type_mix(profile):
    """Returns (easy_ratio, medium_ratio, hard_ratio). Uses accuracy_by_type
    and overtime patterns from a PRIOR session if available, else falls back
    to the same struggling/steady/excelling read used for difficulty.
    A first-ever session (no answer history) always gets the neutral mix —
    zero mistakes from zero data is not the same signal as zero mistakes
    from real answers, and defaulting to 'excelling' there would hand a
    brand-new student the hardest mix on their very first session."""
    if not profile.get("has_history",True):
        return 0.35,0.35,0.30
    acc=profile.get("accuracy_by_type") or {}
    mr=profile.get("mistake_rate",0.5);hr=profile.get("hint_press_rate",0.0)
    easy_acc=acc.get("easy");hard_acc=acc.get("hard")
    if mr>0.60 or hr>0.70:
        return 0.55,0.30,0.15
    if mr<0.20 and hr<0.20 and (hard_acc is None or hard_acc>=0.7):
        return 0.20,0.35,0.45
    if hard_acc is not None and hard_acc<0.3:
        return 0.45,0.35,0.20   # hard-type was rough last time, pull back
    if easy_acc is not None and easy_acc>=0.9:
        return 0.20,0.40,0.40   # easy is trivial for them, shift up
    return 0.35,0.35,0.30

def _weighted_chunk_order(chunks,profile):
    """Chunks are repeated proportionally to (a) Model 1 difficulty score and
    (b) whether their content touches a topic in the student's mistake_patterns,
    so question generation is drawn more often from the parts that matter.
    Used only as a fallback when no coverage data exists yet."""
    weak_topics={t.lower() for t in profile.get("mistake_patterns",[])}
    weighted=[]
    for c in chunks:
        w=c["difficulty"]["score"]
        if weak_topics and any(t in c["text"].lower() for t in weak_topics):
            w+=2
        weighted.extend([c]*max(1,w))
    random.shuffle(weighted)
    return weighted

def _coverage_aware_chunk_order(chunks,coverage,profile):
    """Primary chunk-selection strategy: chunks NEVER asked about yet always
    come first (so one pass through enough sessions touches the whole
    document), then chunks used the fewest times, then — among equally
    covered chunks — higher Model1 difficulty and weak-topic matches are
    preferred. This is what makes 'the session should cover all content'
    actually true across a multi-session study plan instead of the same
    weighted-random subset getting drawn every time."""
    weak_topics={t.lower() for t in profile.get("mistake_patterns",[])}
    def sort_key(c):
        used=coverage.get(str(c["index"]),0)
        weak_bonus=1 if(weak_topics and any(t in c["text"].lower() for t in weak_topics))else 0
        return(used,-c["difficulty"]["score"]-weak_bonus)
    return sorted(chunks,key=sort_key)

def _distribute_counts(total,easy_r,med_r,hard_r):
    e=round(total*easy_r);m=round(total*med_r);h=total-e-m
    if h<0:h=0;m=total-e
    return e,m,h

def _cap_to_time_budget(easy_n,med_n,hard_n,budget=SESSION_TIME_BUDGET_SECONDS):
    """Trims the mix so estimated total time fits one reasonable sitting.
    Hard (multi-part) questions are the most expensive, so they're trimmed
    first, then medium, keeping at least a few of each where possible."""
    def total_time(e,m,h):
        return e*TIME_ALLOTMENT["easy"]+m*TIME_ALLOTMENT["medium"]+h*TIME_ALLOTMENT["hard"]
    e,m,h=easy_n,med_n,hard_n
    while total_time(e,m,h)>budget and h>3:
        h-=1
    while total_time(e,m,h)>budget and m>3:
        m-=1
    while total_time(e,m,h)>budget and e>3:
        e-=1
    return e,m,h

# ══════════════════════════════════════════════════════════════════════════════
# MODEL 2 — Gemini prompt builders
# ══════════════════════════════════════════════════════════════════════════════
def build_model2_system_prompt(p,easy_n,med_n,hard_n):
    avg=p.get("avg_difficulty_score",3);hr=p.get("hint_press_rate",0.0)
    mr=p.get("mistake_rate",0.5);pace=p.get("preferred_pace","medium")
    pats=p.get("mistake_patterns",[]);sc=p.get("session_count",1);avgt=p.get("avg_time_seconds",35)
    acc=p.get("accuracy_by_type") or {}
    if mr>0.60 or hr>0.70:
        nd=max(1,avg-1);an="STRUGGLING: simplify language, add context clues, make distractors clearly distinct."
    elif mr<0.20 and hr<0.20:
        nd=min(5,avg+1);an="EXCELLING: increase depth, multi-step reasoning, precise terminology, subtle distractors."
    else:
        nd=avg;an="STEADY: maintain difficulty, mix straightforward and moderate questions."
    nl=DLVL.get(nd,"medium")
    pn=f"\nWEAK TOPICS (prioritise these): {', '.join(pats[:3])}." if pats else ""
    accn=f"\nLAST-SESSION ACCURACY BY TYPE: easy={acc.get('easy')}, medium={acc.get('medium')}, hard={acc.get('hard')}." if acc else ""
    return f"""You are the adaptive question generator for Nuromathix, a maths learning system.

LEARNER PROFILE:
Current difficulty : {avg}/5 ({DLVL.get(avg,'medium')})
Next difficulty     : {nd}/5 ({nl})
Hint usage rate     : {hr:.0%}
Mistake rate        : {mr:.0%}
Avg time/question   : {avgt:.0f}s
Preferred pace      : {pace}
Sessions done       : {sc}{pn}{accn}

ADAPTATION: {an}

This is a MATHEMATICS platform. Every question — including "easy" ones — must
require the student to perform or recall an actual mathematical step: evaluate
a formula at given values, identify the next value in an iterative sequence,
compute a derivative/integral/root/result, or apply a rule from the passage
to a new (but similar) case. NEVER produce a question that just blanks out a
random vocabulary word from a sentence — that tests reading, not mathematics.

GENERATE EXACTLY:
- {easy_n} EASY questions, format "fill_blank": a genuine computation with exactly 4 numeric/expression options (one correct, three plausible near-miss values — not word-guessing).
- {med_n} MEDIUM questions, format "short_answer": a computation requiring one typed final answer (a number or short expression). Include "expected_answer" (string) and, if numeric, "answer_tolerance" (float, absolute tolerance).
- {hard_n} HARD questions, format "multi_part": ONE multi-step problem with exactly 4 sub-parts (ids "a","b","c","d") that build on each other (e.g. successive iterations, or sequential steps of one derivation), each sub-part asking for ONE final value/expression (a small textbox, never a full written proof/essay). Each sub-part needs "expected_answer" and optional "answer_tolerance".

RULES:
1. Base every question on the supplied CHUNKS — do not invent content outside them. Reuse the formulas, worked examples, and numeric values already present in the text; construct new-but-analogous computations where the chunk supports it.
2. COVERAGE: draw from every chunk provided at least once before repeating any chunk, unless there are more questions than chunks. Chunks appear in priority order (most-needed first) — earlier chunks in the list should get first priority for a question.
3. Each question needs: "hint" (a single vague level-1 style nudge pointing at the relevant formula/method — deeper hints are generated separately later, so keep this one short and non-revealing), "topic_tags" (1-3 labels), "difficulty_score" (1-5), "difficulty_level".
4. "xai_explanation": a full correct-answer walkthrough (150-220 words) showing the actual working/steps — this is the model solution shown if the student gets it wrong. For multi_part, cover all 4 sub-parts' working.
5. Every question must include a distinct "id" like "q1","q2",... continuing sequentially across ALL {easy_n+med_n+hard_n} questions.

OUTPUT — valid JSON only, no markdown:
{{"questions":[
  {{"id":"q1","chunk_index":0,"question_type":"easy","format":"fill_blank","topic":"Topic","topic_tags":["t1"],"difficulty_score":{nd},"difficulty_level":"{nl}","question_text":"Using the bisection method on f(x)=x^3+4x^2-10 with a=1, b=2, what is the midpoint p1?","blank_word":"1.5","options":["1.5","1.25","1.75","2.0"],"correct_index":0,"hint":"...","xai_explanation":"..."}},
  {{"id":"q2","chunk_index":1,"question_type":"medium","format":"short_answer","topic":"Topic","topic_tags":["t1"],"difficulty_score":{nd},"difficulty_level":"{nl}","question_text":"Evaluate f(1.5) for f(x)=x^3+4x^2-10.","expected_answer":"2.375","answer_tolerance":0.01,"hint":"...","xai_explanation":"..."}},
  {{"id":"q3","chunk_index":2,"question_type":"hard","format":"multi_part","topic":"Topic","topic_tags":["t1"],"difficulty_score":{nd},"difficulty_level":"{nl}","question_text":"Perform 4 iterations of Newton-Raphson on f(x)=x^3-2x-5 starting at x0=2.","sub_parts":[{{"id":"a","prompt":"Part a) Find x1.","expected_answer":"2.1","answer_tolerance":0.01}},{{"id":"b","prompt":"Part b) Find x2.","expected_answer":"2.09457"}},{{"id":"c","prompt":"Part c) Find x3.","expected_answer":"2.09455"}},{{"id":"d","prompt":"Part d) Find x4.","expected_answer":"2.09455"}}],"hint":"...","xai_explanation":"..."}}
]}}"""

def build_question_user_prompt(chunks):
    txt="\n\n".join(f"[CHUNK {c['index']} | Model1:{c['difficulty']['score']}/5 ({c['difficulty']['level']})|conf:{c['difficulty']['confidence']}]\n{c['text']}" for c in chunks)
    return f"CHUNKS (higher Model1 difficulty chunks appear more often on purpose — draw more questions from them):\n\n{txt}\n\nReturn ONLY the JSON object with the exact question counts and formats requested."

def build_hint_prompt(q,level,current_answer):
    fmt=q.get("format","fill_blank")
    stage="The student has NOT started answering yet." if not (current_answer or "").strip() \
        else f"The student is mid-answer. What they've typed so far: \"{(current_answer or '')[:300]}\""
    qtext=q.get("question_text","")
    return f"""You are a patient maths tutor giving a PROGRESSIVE hint.
This is hint level {level} of {MAX_HINT_LEVEL} (1 = vague nudge, {MAX_HINT_LEVEL} = walk through the full method — but NEVER state the final answer value/expression outright, even at level {MAX_HINT_LEVEL}).

QUESTION ({fmt}): {qtext}
{"SUB-PARTS: "+json.dumps(q.get("sub_parts",[]),default=str) if fmt=="multi_part" else ""}
STUDENT STATE: {stage}

Guidance by level:
- 1-3: point to the relevant concept or formula only — do not set up the problem.
- 4-6: help set up the first step, referencing their partial work if they have any.
- 7-9: walk through the approach up to (not including) the final computation.
- {MAX_HINT_LEVEL}: show the full method/setup so only plugging in numbers remains.

Write 2-4 sentences. Return ONLY the hint text — no JSON, no preamble, no markdown."""

def build_xai_prompt_v2(q,answer_summary,is_correct,time_taken,time_allotted,hints_used):
    fmt=q.get("format","fill_blank")
    return f"""You are an XAI tutor for Nuromathix.

QUESTION FORMAT: {fmt}
QUESTION: {q.get('question_text','')}
{"SUB-PARTS: "+json.dumps(q.get('sub_parts',[]),default=str) if fmt=="multi_part" else ""}
STUDENT ANSWER: {json.dumps(answer_summary,default=str)}
RESULT: {'CORRECT' if is_correct else 'INCORRECT / PARTIALLY INCORRECT'}
TIME: {time_taken:.0f}s of {time_allotted:.0f}s allotted
HINTS USED: {len(hints_used)} (levels: {[h.get('level') for h in hints_used]})

Write feedback (200-260 words):
1. {'Confirm why the answer is correct and deepen the concept.' if is_correct else 'Explain the FULL correct step-by-step solution, numbered steps, showing all working — this is the model solution the student should learn from.'}
2. If incorrect, name the likely mistake pattern (e.g. sign error, wrong formula, arithmetic slip).
3. One memory trick or conceptual anchor.
4. One brief comment on their time usage and hint usage.
5. A short encouraging close.

Return ONLY: {{"xai_text":"...","confidence_boost":0.1-1.0,"review_topics":["t1"]}}"""

def call_gemini(sys_p,usr_p,max_tokens=8192):
    global GEMINI_WORKS
    payload=json.dumps({"system_instruction":{"parts":[{"text":sys_p}]},"contents":[{"parts":[{"text":usr_p}]}],"generationConfig":{"maxOutputTokens":max_tokens,"temperature":0.4}}).encode()
    req=urllib.request.Request(GEMINI_URL,data=payload,headers={"Content-Type":"application/json"},method="POST")
    try:
        with urllib.request.urlopen(req,timeout=90) as r:
            data=json.loads(r.read())
        GEMINI_WORKS=True
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except urllib.error.HTTPError as e:
        body=e.read().decode()
        if e.code==403:GEMINI_WORKS=False;raise RuntimeError("gemini_403")
        raise RuntimeError(f"Gemini {e.code}: {body[:200]}")

def parse_json_response(raw):
    raw=raw.strip()
    if "```" in raw:
        raw=raw.split("```")[1]
        if raw.startswith("json"):raw=raw[4:]
    return json.loads(raw.strip().rstrip("```").strip())

# ══════════════════════════════════════════════════════════════════════════════
# Offline fallback generator (used if Gemini unavailable/403)
# ══════════════════════════════════════════════════════════════════════════════
DISTRACTOR_POOL=[
    ["acceleration","velocity","momentum","displacement"],
    ["mitosis","meiosis","osmosis","diffusion"],
    ["oxidation","reduction","hydrolysis","neutralisation"],
    ["differentiation","integration","derivation","substitution"],
    ["convection","conduction","radiation","absorption"],
    ["frequency","amplitude","wavelength","period"],
    ["photosynthesis","respiration","transpiration","fermentation"],
    ["hypothesis","theory","law","postulate"],
    ["stoichiometry","enthalpy","entropy","equilibrium"],
    ["polynomial","monomial","binomial","trinomial"],
]

def _key_sentences(text,n=8):
    sents=re.split(r'(?<=[.!?])\s+',text)
    sents=[s.strip() for s in sents if len(s.split())>=7]
    def score(s):
        return sum(1 for kw in ['is','are','refers','defined','called','means','represents'] if kw in s.lower())
    return sorted(sents,key=score,reverse=True)[:n]

def _make_blank(sent):
    stop={'the','a','an','is','are','was','were','be','been','have','has','had','do','does','will','would','could','should','may','might','must','can','to','of','in','on','at','by','for','with','about','into','from','and','or','but','if','as','it','its','this','that','these','those','which','who','what','when','where','how','their','they','we','its','our','your'}
    words=sent.split()
    cands=[(i,w) for i,w in enumerate(words) if len(w)>5 and w.lower().rstrip(".,;:") not in stop and w[0].isalpha() and i>1]
    if not cands:return None
    ci,cw=random.choice(cands[-max(1,len(cands)//2):])
    clean=cw.rstrip('.,;:')
    blanked=" ".join("_____" if i==ci else w for i,w in enumerate(words))+"?"
    return blanked,clean

def _distractors(correct,level):
    for grp in DISTRACTOR_POOL:
        if correct.lower() in [g.lower() for g in grp]:
            return [g for g in grp if g.lower()!=correct.lower()][:3]
    base=correct[:max(4,len(correct)-3)]
    sfx=["tion","ism","ity","ance","ment","ness","ence"]
    d=[]
    for s in random.sample(sfx,min(4,len(sfx))):
        w=base+s
        if w!=correct and w not in d:d.append(w)
        if len(d)==3:break
    pad=["framework","paradigm","mechanism","principle","coefficient","derivative","variable"]
    random.shuffle(pad)
    for g in pad:
        if len(d)>=3:break
        if g!=correct:d.append(g)
    return d[:3]

def _fallback_qa_pair(chunk):
    """Returns (prompt_text, answer) drawn from one chunk, used by every
    fallback format. Falls back to a naive final-word pick if no good
    sentence is found. LAST-RESORT ONLY — see _fallback_computation_pair,
    which is tried first and produces genuine computation questions."""
    sents=_key_sentences(chunk["text"])
    for s in sents:
        r=_make_blank(s)
        if r:return r
    words=chunk["text"].split()[:25]
    ans=next((w for w in reversed(words) if len(w)>5),"concept")
    return " ".join("_____" if w==ans else w for w in words)+"?",ans

# ── Numeric-fact extraction (real computation, not word-guessing) ─────────────
# Maths textbooks are full of worked examples: "p1 = 1.5", "f(1.25) = -1.797",
# "x2 = 2.09457". These are genuine, verifiable computed values straight from
# the source material — asking a student "what is p2 in this worked example?"
# tests actual maths recall/computation, unlike blanking a random prose word.
# LIMITATION: PDF text extraction flattens superscripts (x³ becomes "x3" with
# no marker), so this occasionally mis-parses an exponent as part of a decimal
# value. This is a PDF-extraction limitation, not fixable by regex alone — an
# LLM (Gemini) reads that ambiguity from context far more reliably, which is
# why Gemini remains the recommended primary path; this fallback is the
# best-effort offline substitute when no API key is set.
_NUMERIC_FACT_RE=re.compile(r'\b([fpxngh][a-zA-Z0-9_]{0,3}(?:\([^)]{1,15}\))?)\s*=\s*(-?\d+\.\d+|-?\d+)')
_BLACKLISTED_LABELS={"n","i","j","k","e"}   # loop indices / Euler's-number ambiguity — not meaningful quiz facts

def _extract_numeric_facts(text):
    facts=[]
    for sent in re.split(r'(?<=[.!?])\s+',text):
        if len(sent.split())<4:continue
        for m in _NUMERIC_FACT_RE.finditer(sent):
            label,value=m.group(1),m.group(2)
            if label.lower() in _BLACKLISTED_LABELS:continue
            trailing=sent[m.end():m.end()+2].strip()
            # Reject if the captured number is immediately followed by an
            # operator/paren — that means it's a mid-expression fragment, not
            # a resolved final value. This is what catches PDF superscript-
            # flattening artifacts like "f(1.5) = 1.53 + 4(1.5)2 -10 = 2.375",
            # where "1.53" is really "1.5³" glued together mid-formula and
            # the TRUE result (2.375) is further along — safer to skip the
            # whole fact than risk quizzing on the wrong value.
            if trailing[:1] in "+-*/^(":
                continue
            facts.append({"label":label,"value":value,"context":sent.strip()})
    return facts

def _numeric_distractors(value_str):
    try:
        v=float(value_str)
    except ValueError:
        return [value_str+"1",value_str+"2",value_str+"3"]
    deltas=[0.1,-0.1,0.25,-0.25,0.5,-0.5,1.0,-1.0]
    random.shuffle(deltas)
    seen={value_str};out=[]
    for d in deltas:
        cand=round(v+d*max(abs(v),1),4)
        s=str(cand)
        if s not in seen:
            seen.add(s);out.append(s)
        if len(out)==3:break
    while len(out)<3:
        out.append(str(round(v+random.uniform(-2,2),4)))
    return out

def _fallback_computation_pair(chunk):
    """Preferred fallback question source: a real computed value from a
    worked example in this chunk, with the sentence it came from as context.
    Falls back to _fallback_qa_pair (word-blank) only if the chunk has no
    extractable numeric facts (e.g. a purely definitional/theorem chunk)."""
    facts=_extract_numeric_facts(chunk["text"])
    if not facts:
        return (*_fallback_qa_pair(chunk),False)
    fact=random.choice(facts)
    marker=f"{fact['label']} = {fact['value']}"
    if marker in fact["context"]:
        stem=fact["context"].replace(marker,f"{fact['label']} = _____",1)
    else:
        stem=fact["context"]+f" What is the value of {fact['label']}?"
    return stem,fact["value"],True

def generate_questions_fallback(ordered_chunks,profile,easy_n,med_n,hard_n):
    avg=profile.get("avg_difficulty_score",3);mr=profile.get("mistake_rate",0.5);hr=profile.get("hint_press_rate",0.0)
    if mr>0.60 or hr>0.70:nd=max(1,avg-1)
    elif mr<0.20 and hr<0.20:nd=min(5,avg+1)
    else:nd=avg
    nl=DLVL.get(nd,"medium")
    pool=ordered_chunks or []
    if not pool:return []
    qi=[0]
    def next_chunk():
        return pool[qi[0]%len(pool)] if pool else pool[0]
    def topic_of(chunk):
        tw=[w for w in chunk["text"].split()[:40] if len(w)>5 and w[0].isupper() and w.isalpha()]
        return tw[0] if tw else f"Section {chunk['index']+1}"

    questions=[]
    # EASY — fill_blank, but MCQ options are now numeric distractors when the
    # source is a real computed value, not vocabulary-style word swaps
    for _ in range(easy_n):
        c=next_chunk();qi[0]+=1
        qtxt,answer,is_computed=_fallback_computation_pair(c)
        dists=_numeric_distractors(answer) if is_computed else _distractors(answer,nl)
        opts=[answer]+dists;random.shuffle(opts);cidx=opts.index(answer)
        topic=topic_of(c)
        if is_computed:
            xai=(f"The correct value is {answer}, computed directly from the worked example in this section. "
                 f"The other options are plausible nearby values but don't match the actual computation shown. "
                 f"Re-work the calculation step shown in the passage to confirm {answer}. Keep practicing — accuracy comes with repetition!")
        else:
            xai=(f"The correct answer is '{answer}'. It fits because the passage specifically describes this concept. "
                 f"'{dists[0] if dists else 'Option B'}' is incorrect — related but different. "
                 f"'{dists[1] if len(dists)>1 else 'Option C'}' is incorrect — different mechanism/property. "
                 f"'{dists[2] if len(dists)>2 else 'Option D'}' is incorrect — different category. "
                 f"Memory trick: link '{answer}' to the context of this passage. Keep going!")
        questions.append({"id":f"q{len(questions)+1}","chunk_index":c["index"],"question_type":"easy","format":"fill_blank",
            "topic":topic,"topic_tags":[topic.lower(),nl],"difficulty_score":nd,"difficulty_level":nl,
            "time_allotted_seconds":TIME_ALLOTMENT["easy"],"question_text":qtxt,"blank_word":answer,
            "options":opts,"correct_index":cidx,"hint":f"Work through the computation shown for {topic.lower()} step by step.","xai_explanation":xai})
    # MEDIUM — short_answer, typed final value/term
    for _ in range(med_n):
        c=next_chunk();qi[0]+=1
        qtxt,answer,is_computed=_fallback_computation_pair(c)
        topic=topic_of(c)
        is_numeric=is_computed or answer.replace('.','',1).replace('-','',1).isdigit()
        if is_computed:
            xai=(f"The correct value is {answer}. Trace through the computation shown in the passage step by step to "
                 f"confirm this result. If your answer differs, check for a sign error or an arithmetic slip in an "
                 f"intermediate step — that's the most common cause of a mismatch here.")
            question_text=qtxt
        else:
            xai=(f"The correct answer is '{answer}'. This passage directly names it in that context. "
                 f"Re-read the sentence around the blank for the exact wording used. Memory trick: tie '{answer}' to {topic.lower()}.")
            question_text="Fill in the missing term: "+qtxt
        questions.append({"id":f"q{len(questions)+1}","chunk_index":c["index"],"question_type":"medium","format":"short_answer",
            "topic":topic,"topic_tags":[topic.lower(),nl],"difficulty_score":nd,"difficulty_level":nl,
            "time_allotted_seconds":TIME_ALLOTMENT["medium"],"question_text":question_text,
            "expected_answer":answer,"answer_tolerance":0.01 if is_numeric else None,
            "hint":f"Work through the {topic.lower()} computation shown, one step at a time.","xai_explanation":xai})
    # HARD — multi_part: prefer 4 facts from the SAME chunk sharing a label
    # prefix (e.g. p1,p2,p3,p4 from one iteration table) so the sub-parts
    # form a coherent sequence rather than 4 unrelated facts
    for _ in range(hard_n):
        c=next_chunk();qi[0]+=1
        facts=_extract_numeric_facts(c["text"])
        by_prefix={}
        for f in facts:
            prefix=re.match(r'[a-zA-Z]+',f["label"])
            key=prefix.group(0) if prefix else f["label"]
            by_prefix.setdefault(key,[]).append(f)
        sequence=max(by_prefix.values(),key=len) if by_prefix else []
        sub_parts=[]
        if len(sequence)>=4:
            chosen=sequence[:4]
            for label,f in zip(["a","b","c","d"],chosen):
                sub_parts.append({"id":label,"prompt":f"Part {label}) In this worked example, what is {f['label']}?",
                    "expected_answer":f["value"],"answer_tolerance":0.01})
            topic=topic_of(c)
        else:
            # not enough facts in one chunk for a coherent sequence — draw
            # one fact/blank per sub-part from up to 4 chunks instead
            for label in ["a","b","c","d"]:
                cc=next_chunk();qi[0]+=1
                qtxt,answer,is_computed=_fallback_computation_pair(cc)
                is_numeric=is_computed or answer.replace('.','',1).replace('-','',1).isdigit()
                prompt=f"Part {label}) {qtxt}" if is_computed else f"Part {label}) Fill in the missing term: {qtxt}"
                sub_parts.append({"id":label,"prompt":prompt,"expected_answer":answer,
                    "answer_tolerance":0.01 if is_numeric else None})
            topic=topic_of(c)
        xai=("Full solution:\n"+"\n".join(f"Part {sp['id']}) → {sp['expected_answer']}" for sp in sub_parts)+
             "\nWork through each part in order and check your intermediate values against these before moving to the next part.")
        questions.append({"id":f"q{len(questions)+1}","chunk_index":c["index"],"question_type":"hard","format":"multi_part",
            "topic":topic,"topic_tags":[topic.lower(),nl],"difficulty_score":min(5,nd+1),"difficulty_level":DLVL.get(min(5,nd+1),nl),
            "time_allotted_seconds":TIME_ALLOTMENT["hard"],"question_text":f"Multi-part problem on {topic}. Answer each part below.",
            "sub_parts":sub_parts,"hint":"Work through each part in order — later parts often build on earlier ones.","xai_explanation":xai})
    return questions

def generate_fallback_hint(q,level,current_answer):
    base=q.get("hint","Think about the key concept in this passage.")
    started=bool((current_answer or "").strip())
    if level<=3:
        return base
    elif level<=6:
        return base+(" Try applying it to what you've already written." if started
                     else " Start by identifying the key term or formula this passage is describing.")
    elif level<=9:
        return base+f" Focus specifically on the topic: {q.get('topic','this section')}. Re-read the surrounding sentence for the exact wording."
    else:
        return base+" You're very close — the answer is the specific term/value this exact passage names for that concept."

def generate_xai_fallback(q,is_correct):
    return{"xai_text":q.get("xai_explanation","Review this concept carefully."),
           "confidence_boost":0.75 if is_correct else 0.35,"review_topics":q.get("topic_tags",[])}

# ══════════════════════════════════════════════════════════════════════════════
# Grading helpers
# ══════════════════════════════════════════════════════════════════════════════
def _answers_match(given,expected,tolerance=None):
    if given is None:return False
    g=str(given).strip()
    if not g:return False
    e=str(expected).strip()
    try:
        gf=float(g.replace(",",""));ef=float(e.replace(",",""))
        tol=tolerance if tolerance is not None else max(abs(ef)*0.02,0.01)
        return abs(gf-ef)<=tol
    except ValueError:
        pass
    norm=lambda s:re.sub(r"[^a-z0-9]","",s.lower())
    return norm(g)==norm(e)

def grade_answer(q,ua):
    fmt=q.get("format","fill_blank")
    if fmt=="fill_blank":
        si=ua.get("selected_index",-1)
        ic=si==q.get("correct_index")
        opts=q.get("options",[])
        summary={"selected_index":si,"selected_text":opts[si] if 0<=si<len(opts) else None}
        return ic,summary,1.0 if ic else 0.0
    if fmt=="short_answer":
        given=ua.get("answer_text","")
        ic=_answers_match(given,q.get("expected_answer",""),q.get("answer_tolerance"))
        return ic,{"answer_text":given},1.0 if ic else 0.0
    # multi_part
    subs=ua.get("sub_answers",{}) or {}
    correct_flags={}
    for sp in q.get("sub_parts",[]):
        given=subs.get(sp["id"],"")
        correct_flags[sp["id"]]=_answers_match(given,sp.get("expected_answer",""),sp.get("tolerance"))
    n=max(len(q.get("sub_parts",[])),1)
    partial=sum(correct_flags.values())/n
    ic=partial==1.0
    return ic,{"sub_answers":subs,"sub_correct":correct_flags,"partial_score":round(partial,3)},partial

# ══════════════════════════════════════════════════════════════════════════════
# Learner profile + forgetting curve (Model 2 output → scheduling input)
# ══════════════════════════════════════════════════════════════════════════════
def derive_learner_profile(session):
    answers=session.get("answers",[]);chunks=session.get("chunks",[])
    scores=[c["difficulty"]["score"] for c in chunks]
    avg_diff=round(sum(scores)/len(scores)) if scores else 3
    base={"avg_difficulty_score":avg_diff,"session_count":session.get("session_count",1),"has_history":bool(answers)}
    if not answers:
        base.update({"hint_press_rate":0.0,"mistake_rate":0.0,"avg_time_seconds":35.0,
            "mistake_patterns":[],"preferred_pace":"medium","avg_score":1.0,
            "accuracy_by_type":{},"timeout_rate":0.0,"avg_overtime_seconds":0.0,
            "avg_hint_level":0.0,"hint_usage_rate":0.0})
        return base

    total=len(answers);correct_scores=[a.get("score",1.0 if a.get("is_correct") else 0.0) for a in answers]
    correct=sum(1 for a in answers if a.get("is_correct"))
    hint_events=[h for a in answers for h in a.get("hints_used",[])]
    times=[a.get("time_taken",35.0) for a in answers];avg_t=sum(times)/len(times) if times else 35.0
    pace="medium"
    if avg_t>55:pace="slow"
    elif avg_t<22:pace="fast"
    from collections import Counter
    missed=[]
    for a in answers:
        if not a.get("is_correct",True):missed.extend(a.get("topic_tags",[]))

    type_buckets={}
    for a in answers:
        t=a.get("question_type","easy")
        type_buckets.setdefault(t,[]).append(a.get("score",1.0 if a.get("is_correct") else 0.0))
    accuracy_by_type={k:round(sum(v)/len(v),3) for k,v in type_buckets.items() if v}

    timeouts=sum(1 for a in answers if a.get("timed_out"))
    overtimes=[a.get("overtime_seconds",0) for a in answers if a.get("overtime_seconds",0)>0]
    hint_levels=[h.get("level",1) for h in hint_events]

    base.update({
        "hint_press_rate":round(len(hint_events)/total,3) if total else 0.0,
        "mistake_rate":round(1-(sum(correct_scores)/total),3) if total else 0.0,
        "avg_time_seconds":round(avg_t,1),
        "mistake_patterns":[t for t,_ in Counter(missed).most_common(3)],
        "preferred_pace":pace,
        "avg_score":round(sum(correct_scores)/total,3) if total else 1.0,
        "accuracy_by_type":accuracy_by_type,
        "timeout_rate":round(timeouts/total,3) if total else 0.0,
        "avg_overtime_seconds":round(sum(overtimes)/len(overtimes),1) if overtimes else 0.0,
        "avg_hint_level":round(sum(hint_levels)/len(hint_levels),2) if hint_levels else 0.0,
        "hint_usage_rate":round(sum(1 for a in answers if a.get("hints_used"))/total,3) if total else 0.0,
    })
    return base

def compute_forgetting_curve(p,mode="fixed",study_days=7):
    avg=p.get("avg_score",0.5);mr=p.get("mistake_rate",0.5);hr=p.get("hint_press_rate",0.3);ns=p.get("session_count",1)
    S=1.0+(avg*3.5)-(mr*2.0)-(hr*1.5)+(ns*0.4);S=max(0.5,min(S,6.0))
    thr=0.80;gap=S*(-math.log(thr))

    # ── pace by study mode: never let gaps balloon into months, never crush
    #    "until mastery" into a single week either ──
    if mode=="until_mastery":
        gap=max(MASTERY_MIN_GAP_DAYS,min(gap,MASTERY_MAX_GAP_DAYS))
        session_cap=MASTERY_MAX_SESSIONS
    else:
        gap=max(1,min(gap,FIXED_MODE_MAX_GAP_DAYS,max(1,study_days-ns)))
        session_cap=None

    d1=max(1,round(gap*0.25));d2=max(2,round(gap*0.60));d3=max(4,round(gap));d4=max(7,round(gap*2.0))
    now=datetime.utcnow()
    sched=[{"session":i+1,"days_from_now":d,"date":(now+timedelta(days=d)).strftime("%Y-%m-%d")} for i,d in enumerate([d1,d2,d3,d4])]
    pts=[{"day":t,"retention":round(math.exp(-t/max(S,0.01)),4)} for t in range(0,d4+1)]
    mastery_reached=(avg>=0.90 and ns>=3) or (session_cap is not None and ns>=session_cap)
    return{"stability":round(S,3),"optimal_gap_days":round(gap,2),"threshold":thr,"next_sessions":sched,
        "next_review_date":sched[0]["date"],"next_review_days":d1,"mastery_reached":mastery_reached,
        "session_cap":session_cap,"curve_points":pts,"formula":f"R(t) = e^(-t / {round(S,2)})"}

def _strip(qs):
    """What the frontend receives before answering: never the correct_index,
    expected_answer/tolerance, xai_explanation, or the base 'hint' (progressive
    hints are fetched one at a time via /session/<sid>/question/<qid>/hint)."""
    hidden_top={"correct_index","expected_answer","answer_tolerance","xai_explanation","hint"}
    out=[]
    for q in qs:
        clean={k:v for k,v in q.items() if k not in hidden_top}
        if q.get("format")=="multi_part":
            clean["sub_parts"]=[{k:v for k,v in sp.items() if k not in("expected_answer","tolerance","answer_tolerance")} for sp in q.get("sub_parts",[])]
        out.append(clean)
    return out

# ══════════════════════════════════════════════════════════════════════════════
# ROUTES
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/health",methods=["GET"])
def health():
    return jsonify({"status":"ok","model1_loaded":MODEL1_RF is not None,
        "gemini_status":"working" if GEMINI_WORKS else "fallback" if GEMINI_WORKS is False else "untested",
        "model1_classes":MODEL1_RF.classes_.tolist() if MODEL1_RF else[],
        "mongo_connected":_sessions_col is not None and _materials_col is not None})

@app.route("/upload",methods=["POST"])
def upload():
    """Uploads and persists a MATERIAL under the user's profile — this only
    ever needs to happen once per document. Starting a quiz session on it
    afterwards (including a 2nd, 3rd, ... session later) is a separate call
    to POST /material/<material_id>/session/start and never requires
    re-uploading. user_id should be the Firebase uid from the frontend;
    falls back to 'anonymous' only for quick manual/curl testing."""
    if "file" not in request.files:return jsonify({"error":"No file"}),400
    user_id=request.form.get("user_id","anonymous")
    filename=request.files["file"].filename or "Untitled.pdf"
    pdf=request.files["file"].read()
    sd=int(request.form.get("study_days",7));mode=request.form.get("mode","fixed")

    ct,full_text=extract_chunks(pdf)
    if not ct:return jsonify({"error":"Cannot extract text from this PDF."}),422

    is_math,math_confidence,math_reason=is_math_document(full_text)
    if not is_math:
        log.info("[upload] rejected non-math doc: %s",math_reason)
        return jsonify({"error":"This doesn't look like a mathematics document. Nuromathix currently only supports maths study material.",
            "is_math":False,"math_confidence":math_confidence,"debug_reason":math_reason}),422

    chunks=[{"index":i,"text":t,"difficulty":predict_difficulty(t)} for i,t in enumerate(ct)]
    mid=str(uuid.uuid4())
    summary={lvl:sum(1 for c in chunks if c["difficulty"]["level"]==lvl) for lvl in["very_easy","easy","medium","hard","very_hard"]}
    summary["avg_score"]=round(sum(c["difficulty"]["score"] for c in chunks)/len(chunks),2)
    _material_save(mid,{"id":mid,"user_id":user_id,"filename":filename,"uploaded_at":datetime.utcnow().isoformat(),
        "chunks":chunks,"study_days":sd,"mode":mode,"difficulty_summary":summary,
        "chunk_coverage":{str(c["index"]):0 for c in chunks},"session_count":0})
    log.info("[upload] material_id=%s user=%s chunks=%d avg=%.1f is_math=%s conf=%.2f",
        mid,user_id,len(chunks),summary["avg_score"],is_math,math_confidence)
    return jsonify({"material_id":mid,"filename":filename,"total_chunks":len(chunks),"difficulty_summary":summary,
        "is_math":True,"math_confidence":math_confidence})

@app.route("/user/<user_id>/materials",methods=["GET"])
def list_materials(user_id):
    """Powers the dashboard: every material this user has ever uploaded,
    persisted — never needs re-uploading. Each entry includes its own
    session count, coverage, and latest session's score/status so the
    dashboard can render separate progress per material without a second
    round-trip per item."""
    materials=_materials_for_user(user_id)
    out=[]
    for m in materials:
        sessions=_sessions_for_material(m["_id"])
        coverage=m.get("chunk_coverage",{})
        covered=sum(1 for v in coverage.values() if v>0)
        coverage_percent=round(100*covered/max(len(coverage),1),1)
        latest=sessions[-1] if sessions else None
        out.append({"material_id":m["_id"],"filename":m.get("filename","Untitled.pdf"),
            "uploaded_at":m.get("uploaded_at"),"difficulty_summary":m.get("difficulty_summary",{}),
            "mode":m.get("mode","fixed"),"study_days":m.get("study_days",7),
            "material_coverage_percent":coverage_percent,"session_count":len(sessions),
            "latest_session":None if not latest else {
                "session_id":latest["_id"],"session_number":latest.get("session_number"),
                "status":latest.get("status"),"score":latest.get("score"),
                "next_review_date":(latest.get("forgetting_curve") or {}).get("next_review_date"),
                "completed_at":latest.get("completed_at")}})
    return jsonify({"materials":out,"total":len(out)})

@app.route("/material/<mid>/sessions",methods=["GET"])
def list_material_sessions(mid):
    """Every past session on one material — separate score, status, and
    forgetting-curve schedule per entry, for the per-material progress view
    (session history list + progress-over-time graph)."""
    if not _material_exists(mid):return jsonify({"error":"not found"}),404
    sessions=_sessions_for_material(mid)
    out=[{"session_id":s["_id"],"session_number":s.get("session_number"),"status":s.get("status"),
        "score":s.get("score"),"started_at":s.get("started_at"),"completed_at":s.get("completed_at"),
        "forgetting_curve":s.get("forgetting_curve"),"question_mix":s.get("question_mix")} for s in sessions]
    return jsonify({"sessions":out,"total":len(out)})

@app.route("/session/<sid>",methods=["GET"])
def get_session_detail(sid):
    """Full detail of one past (or in-progress) session — the 'separate
    result panel' per session: questions, answers, XAI, learner profile,
    forgetting curve, all as originally recorded for that specific attempt."""
    if not _session_exists(sid):return jsonify({"error":"not found"}),404
    s=_session_get(sid)
    return jsonify({"session_id":s["_id"],"material_id":s.get("material_id"),"session_number":s.get("session_number"),
        "status":s.get("status"),"score":s.get("score"),"started_at":s.get("started_at"),
        "completed_at":s.get("completed_at"),"questions":_strip(s.get("questions",[])),
        "answers":s.get("answers",[]),"learner_profile":s.get("learner_profile"),
        "forgetting_curve":s.get("forgetting_curve")})

@app.route("/material/<mid>/session/start",methods=["POST"])
def start_session(mid):
    """Starts a NEW session (quiz attempt) on an already-uploaded material.
    This is the ONLY way to get a 2nd/3rd/... session — no re-upload
    involved. The learner profile driving question difficulty/mix comes from
    the material's most recently COMPLETED session (if any), so session 2
    genuinely adapts to how session 1 went, not a blank slate."""
    if not _material_exists(mid):return jsonify({"error":"not found"}),404
    material=_material_get(mid)
    chunks=material["chunks"]

    prior_sessions=_sessions_for_material(mid)
    last_complete=next((s for s in reversed(prior_sessions) if s.get("status")=="complete"),None)
    if last_complete:
        profile=last_complete.get("learner_profile") or derive_learner_profile(last_complete)
    else:
        profile=derive_learner_profile({"answers":[],"chunks":chunks,"session_count":0})
    session_number=len(prior_sessions)+1
    profile["session_count"]=session_number

    coverage=material.get("chunk_coverage",{str(c["index"]):0 for c in chunks})
    ordered_chunks=_coverage_aware_chunk_order(chunks,coverage,profile)

    total_q=determine_question_count(len(chunks))
    easy_r,med_r,hard_r=determine_type_mix(profile)
    easy_n,med_n,hard_n=_distribute_counts(total_q,easy_r,med_r,hard_r)
    easy_n,med_n,hard_n=_cap_to_time_budget(easy_n,med_n,hard_n)
    total_q=easy_n+med_n+hard_n

    questions=None;used_gemini=False
    if GEMINI_WORKS is not False:
        try:
            prioritised=ordered_chunks[:max(total_q,len(ordered_chunks))]
            raw=call_gemini(build_model2_system_prompt(profile,easy_n,med_n,hard_n),build_question_user_prompt(prioritised))
            data=parse_json_response(raw);questions=data.get("questions",[])
            for i,q in enumerate(questions):q["id"]=f"q{i+1}"
            used_gemini=True;log.info("[start] Gemini: %d Qs (easy=%d med=%d hard=%d)",len(questions),easy_n,med_n,hard_n)
        except RuntimeError as e:
            if"403"in str(e):log.warning("[start] Gemini 403 → fallback")
            else:log.error("[start] Gemini err: %s",e)
        except Exception as e:log.error("[start] unexpected: %s",e)
    if not questions:
        questions=generate_questions_fallback(ordered_chunks,profile,easy_n,med_n,hard_n)
        log.info("[start] Fallback: %d Qs (easy=%d med=%d hard=%d)",len(questions),easy_n,med_n,hard_n)

    for q in questions:
        q.setdefault("time_allotted_seconds",TIME_ALLOTMENT.get(q.get("question_type","easy"),90))

    # ── update per-chunk coverage on the MATERIAL (not the session) so it
    #    persists across every session on this document ──
    for q in questions:
        ci=str(q.get("chunk_index",""))
        if ci in coverage:coverage[ci]=coverage.get(ci,0)+1
    covered_count=sum(1 for v in coverage.values() if v>0)
    coverage_percent=round(100*covered_count/max(len(coverage),1),1)
    _material_update(mid,{"chunk_coverage":coverage,"session_count":session_number})

    sid=str(uuid.uuid4())
    _session_save(sid,{"id":sid,"material_id":mid,"user_id":material.get("user_id"),
        "session_number":session_number,"questions":questions,"answers":[],"status":"active",
        "started_at":datetime.utcnow().isoformat(),"question_mix":{"easy":easy_n,"medium":med_n,"hard":hard_n},
        "learner_profile":profile})
    return jsonify({"session_id":sid,"material_id":mid,"session_number":session_number,
        "questions":_strip(questions),"total":len(questions),"adapted_diff":profile["avg_difficulty_score"],
        "pace":profile["preferred_pace"],"used_gemini":used_gemini,
        "question_mix":{"easy":easy_n,"medium":med_n,"hard":hard_n},
        "material_coverage_percent":coverage_percent})

@app.route("/session/<sid>/question/<qid>/hint",methods=["POST"])
def get_hint(sid,qid):
    if not _session_exists(sid):return jsonify({"error":"not found"}),404
    session=_session_get(sid)
    q=next((qq for qq in session.get("questions",[]) if qq["id"]==qid),None)
    if not q:return jsonify({"error":"question not found"}),404

    body=request.get_json() or{}
    level=int(body.get("hint_level",1))
    level=max(1,min(MAX_HINT_LEVEL,level))
    current_answer=body.get("current_answer","")

    hint_text=None
    if GEMINI_WORKS is not False:
        try:
            hint_text=call_gemini("You are a maths tutor giving one short progressive hint.",
                build_hint_prompt(q,level,current_answer),max_tokens=300).strip()
        except Exception as e:
            log.warning("[hint] Gemini failed, using fallback: %s",e)
    if not hint_text:
        hint_text=generate_fallback_hint(q,level,current_answer)

    return jsonify({"question_id":qid,"hint_level":level,"hint_text":hint_text,"hints_remaining":MAX_HINT_LEVEL-level})

@app.route("/session/<sid>/submit",methods=["POST"])
def submit_answers(sid):
    if not _session_exists(sid):return jsonify({"error":"not found"}),404
    session=_session_get(sid);qs=session.get("questions",[]);body=request.get_json() or{}
    user_ans=body.get("answers",[]);qmap={q["id"]:q for q in qs}
    results=[]
    for ua in user_ans:
        qid=ua.get("question_id");q=qmap.get(qid)
        if not q:continue
        fmt=q.get("format","fill_blank")
        tt=float(ua.get("time_taken",30.0))
        allotted=q.get("time_allotted_seconds",TIME_ALLOTMENT.get(q.get("question_type","easy"),90))
        timed_out=bool(ua.get("timed_out",False))
        overtime=float(ua.get("overtime_seconds",0.0))
        continued_after_timeout=bool(ua.get("continued_after_timeout",False))
        hints_used=ua.get("hints_used",[])

        is_correct,answer_summary,score=grade_answer(q,ua)

        xai=None
        if GEMINI_WORKS is not False:
            try:
                raw=call_gemini("You are an XAI tutor. Be precise and encouraging.",
                    build_xai_prompt_v2(q,answer_summary,is_correct,tt,allotted,hints_used),max_tokens=700)
                xai=parse_json_response(raw)
            except:pass
        if not xai:xai=generate_xai_fallback(q,is_correct)

        results.append({"question_id":qid,"question_text":q.get("question_text",""),"format":fmt,
            "question_type":q.get("question_type","easy"),"topic":q.get("topic",""),"topic_tags":q.get("topic_tags",[]),
            "difficulty_score":q.get("difficulty_score",3),"difficulty_level":q.get("difficulty_level","medium"),
            "answer":answer_summary,"is_correct":is_correct,"score":score,
            "time_taken":tt,"time_allotted_seconds":allotted,"timed_out":timed_out,
            "overtime_seconds":overtime,"continued_after_timeout":continued_after_timeout,
            "hints_used":hints_used,"xai":xai})

    session["answers"]=results
    fp=derive_learner_profile(session);fp["session_count"]=session.get("session_number",1)
    material=_material_get(session.get("material_id")) or {}
    curve=compute_forgetting_curve(fp,mode=material.get("mode","fixed"),study_days=material.get("study_days",7))
    total=len(results);correct=sum(1 for r in results if r["is_correct"])
    overall_score=(sum(r["score"] for r in results)/total) if total else 0.0

    _session_update(sid,{"answers":results,"status":"complete","completed_at":datetime.utcnow().isoformat(),
        "learner_profile":fp,"forgetting_curve":curve,"score":round(overall_score,3)})
    log.info("[submit] sid=%s score=%.0f%% timeouts=%s",sid,overall_score*100,fp.get("timeout_rate"))
    return jsonify({"session_id":sid,"material_id":session.get("material_id"),
        "session_number":session.get("session_number"),"score":round(overall_score,3),
        "correct":correct,"total":total,"results":results,
        "learner_profile":fp,"forgetting_curve":curve,"next_review_date":curve["next_review_date"],
        "next_review_days":curve["next_review_days"],"mastery_reached":curve["mastery_reached"],
        "session_cap":curve["session_cap"]})

@app.route("/session/<sid>/questions",methods=["GET"])
def get_questions(sid):
    if not _session_exists(sid):return jsonify({"error":"not found"}),404
    qs=_strip(_session_get(sid).get("questions",[]))
    return jsonify({"questions":qs,"total":len(qs)})

if __name__=="__main__":
    app.run(host="0.0.0.0",port=5000,debug=True)
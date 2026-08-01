// lib/screens/learning_session_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// LEARNING SESSION / QUIZ PAGE
// Matches Screen 6 design from your screenshot exactly:
//  - Session title + progress % top bar
//  - Numbered step indicators (1–6)
//  - Question cards: COMPLETED / TIME EXCEEDED / timer / PENDING states
//  - Multiple choice options (A/B/C/D)
//  - Hint button
//  - Submit Final Answer button
//  - Results view with XAI explanations
//  - Forgetting curve + next session schedule
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/review_schedule_service.dart';
import '../services/teacher_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class SessionQuestion {
  final String id;
  final String topic;
  final List<String> topicTags;
  final String questionType;
  final String questionText;
  final List<String> options;
  final String hint;
  final int difficultyScore;
  final String difficultyLevel;

  const SessionQuestion({
    required this.id,
    required this.topic,
    required this.topicTags,
    required this.questionType,
    required this.questionText,
    required this.options,
    required this.hint,
    required this.difficultyScore,
    required this.difficultyLevel,
  });

  factory SessionQuestion.fromJson(Map<String, dynamic> j) => SessionQuestion(
        id:              j['id'] as String? ?? 'q1',
        topic:           j['topic'] as String? ?? 'General',
        topicTags:       List<String>.from(j['topic_tags'] as List? ?? []),
        questionType:    j['question_type'] as String? ?? 'multiple_choice',
        questionText:    j['question_text'] as String? ?? '',
        options:         List<String>.from(j['options'] as List? ?? []),
        hint:            j['hint'] as String? ?? '',
        difficultyScore: j['difficulty_score'] as int? ?? 3,
        difficultyLevel: j['difficulty_level'] as String? ?? 'medium',
      );
}

class QuestionResult {
  final String questionId;
  final String questionText;
  final String topic;
  final String format;
  final List<String> options;
  final int correctIndex;
  final int selectedIndex;
  final String studentAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final double timeTaken;
  final int hintsUsed;
  final Map<String, dynamic> xai;

  const QuestionResult({
    required this.questionId,
    required this.questionText,
    required this.topic,
    required this.format,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.timeTaken,
    required this.hintsUsed,
    required this.xai,
  });

  String get displayedStudentAnswer {
    if (studentAnswer.trim().isNotEmpty) return studentAnswer;
    if (selectedIndex >= 0 && selectedIndex < options.length) {
      return options[selectedIndex];
    }
    return 'No answer submitted';
  }

  String get displayedCorrectAnswer {
    if (correctAnswer.trim().isNotEmpty) return correctAnswer;
    if (correctIndex >= 0 && correctIndex < options.length) {
      return options[correctIndex];
    }
    return 'See the explanation below';
  }

  static String _answerText(Object? value) {
    if (value == null) return '';
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }
    if (value is List) return value.join(', ');
    return value.toString();
  }

  factory QuestionResult.fromJson(Map<String, dynamic> j) {
    final xai = (j['xai'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final answer = j['answer'];
    String fallbackStudent = '';
    if (answer is Map) {
      fallbackStudent = _answerText(
        answer['selected_text'] ??
            answer['answer_text'] ??
            answer['sub_answers'],
      );
    }
    return QuestionResult(
      questionId: j['question_id']?.toString() ?? '',
      questionText: j['question_text']?.toString() ?? '',
      topic: j['topic']?.toString() ?? '',
      format: j['format']?.toString() ?? 'fill_blank',
      options: (j['options'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      correctIndex: (j['correct_index'] as num?)?.toInt() ?? -1,
      selectedIndex: (j['selected_index'] as num?)?.toInt() ?? -1,
      studentAnswer: _answerText(j['student_answer']).trim().isNotEmpty
          ? _answerText(j['student_answer'])
          : fallbackStudent,
      correctAnswer: _answerText(
        j['correct_answer'] ?? xai['correct_answer'],
      ),
      isCorrect: j['is_correct'] as bool? ?? false,
      timeTaken: (j['time_taken'] as num?)?.toDouble() ?? 0,
      hintsUsed: j['hints_used'] is List
          ? (j['hints_used'] as List).length
          : (j['hints_used'] as num?)?.toInt() ?? 0,
      xai: xai,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// API SERVICE
// ══════════════════════════════════════════════════════════════════════════════

const String _base = kApiBaseUrl;

class StartedSession {
  final String sessionId;
  final String materialId;
  final List<SessionQuestion> questions;

  const StartedSession({
    required this.sessionId,
    required this.materialId,
    required this.questions,
  });
}

Future<StartedSession> apiStartSession(String materialId) async {
  final r = await http.post(
    Uri.parse('$_base/material/$materialId/session/start'),
    headers: {'Content-Type': 'application/json'},
  ).timeout(const Duration(seconds: 90));

  final data = (jsonDecode(r.body) as Map).cast<String, dynamic>();
  if (r.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to start session');
  }
  final sessionId = data['session_id']?.toString();
  if (sessionId == null || sessionId.isEmpty) {
    throw Exception('The backend did not return a session_id.');
  }
  return StartedSession(
    sessionId: sessionId,
    materialId: data['material_id']?.toString() ?? materialId,
    questions: (data['questions'] as List? ?? const [])
        .map((q) => SessionQuestion.fromJson((q as Map).cast<String, dynamic>()))
        .toList(),
  );
}

Future<Map<String, dynamic>> apiSubmitAnswers(
    String sessionId, List<Map<String, dynamic>> answers) async {
  final r = await http.post(
    Uri.parse('$_base/session/$sessionId/submit'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'answers': answers}),
  ).timeout(const Duration(seconds: 120));

  if (r.statusCode != 200) {
    final b = jsonDecode(r.body);
    throw Exception(b['error'] ?? 'Failed to submit');
  }
  return jsonDecode(r.body) as Map<String, dynamic>;
}

// ══════════════════════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════════════════════

enum SessionPhase { loading, questioning, submitting, results, error }

class _QuestionRuntime {
  final int? selectedIndex;
  final bool hintShown;
  final int hintsUsed;
  final DateTime startedAt;
  final bool confirmed;      // answer locked in
  final bool timeExceeded;   // >120s

  const _QuestionRuntime({
    this.selectedIndex,
    this.hintShown  = false,
    this.hintsUsed  = 0,
    required this.startedAt,
    this.confirmed  = false,
    this.timeExceeded = false,
  });

  _QuestionRuntime copyWith({
    int? selectedIndex,
    bool? hintShown,
    int? hintsUsed,
    DateTime? startedAt,
    bool? confirmed,
    bool? timeExceeded,
  }) =>
      _QuestionRuntime(
        selectedIndex: selectedIndex ?? this.selectedIndex,
        hintShown:     hintShown    ?? this.hintShown,
        hintsUsed:     hintsUsed    ?? this.hintsUsed,
        startedAt:     startedAt    ?? this.startedAt,
        confirmed:     confirmed    ?? this.confirmed,
        timeExceeded:  timeExceeded ?? this.timeExceeded,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class LearningSessionScreen extends ConsumerStatefulWidget {
  final String materialId;
  final String studyMode;
  final int studyDays;
  final String fileName;
  final String? sourceReviewScheduleId;

  const LearningSessionScreen({
    super.key,
    required this.materialId,
    required this.studyMode,
    required this.studyDays,
    required this.fileName,
    this.sourceReviewScheduleId,
  });

  @override
  ConsumerState<LearningSessionScreen> createState() =>
      _LearningSessionScreenState();
}

class _LearningSessionScreenState
    extends ConsumerState<LearningSessionScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  SessionPhase           _phase    = SessionPhase.loading;
  List<SessionQuestion>  _questions = [];
  List<_QuestionRuntime> _runtimes  = [];
  Map<String, dynamic>?  _submitResult;
  String?                _error;
  String?                _activeSessionId;

  // Per-question timers (elapsed seconds)
  final Map<int, int> _elapsed = {};
  Timer? _globalTimer;

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  // ── Load questions (Model 2 via Gemini) ───────────────────────────────────
  Future<void> _loadQuestions() async {
    setState(() { _phase = SessionPhase.loading; _error = null; });
    try {
      final started = await apiStartSession(widget.materialId);
      final now = DateTime.now();
      setState(() {
        _activeSessionId = started.sessionId;
        _questions = started.questions;
        _runtimes = List.generate(
          started.questions.length,
          (_) => _QuestionRuntime(startedAt: now),
        );
        _phase = SessionPhase.questioning;
      });
      _startGlobalTimer();
    } catch (e) {
      setState(() { _phase = SessionPhase.error; _error = e.toString(); });
    }
  }

  void _startGlobalTimer() {
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase != SessionPhase.questioning) return;
      setState(() {
        for (int i = 0; i < _questions.length; i++) {
          if (!_runtimes[i].confirmed) {
            _elapsed[i] = (_elapsed[i] ?? 0) + 1;
            // Mark time exceeded after 120 seconds
            if ((_elapsed[i] ?? 0) >= 120 && !_runtimes[i].timeExceeded) {
              _runtimes[i] = _runtimes[i].copyWith(timeExceeded: true);
            }
          }
        }
      });
    });
  }

  // ── Answer interactions ───────────────────────────────────────────────────
  void _selectOption(int qIndex, int optIndex) {
    if (_runtimes[qIndex].confirmed) return;
    setState(() {
      _runtimes[qIndex] = _runtimes[qIndex].copyWith(selectedIndex: optIndex);
    });
  }

  void _confirmAnswer(int qIndex) {
    if (_runtimes[qIndex].selectedIndex == null) return;
    setState(() {
      _runtimes[qIndex] = _runtimes[qIndex].copyWith(confirmed: true);
    });
  }

  void _useHint(int qIndex) {
    if (_runtimes[qIndex].hintShown) return;
    setState(() {
      _runtimes[qIndex] = _runtimes[qIndex].copyWith(
        hintShown: true,
        hintsUsed: _runtimes[qIndex].hintsUsed + 1,
      );
    });
  }

  // ── Submit all ────────────────────────────────────────────────────────────
  Future<void> _submitAll() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      setState(() {
        _phase = SessionPhase.error;
        _error = 'No active session was created.';
      });
      return;
    }

    setState(() => _phase = SessionPhase.submitting);
    _globalTimer?.cancel();

    final answers = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final rt = _runtimes[i];
      answers.add({
        'question_id': _questions[i].id,
        'selected_index': rt.selectedIndex ?? -1,
        'time_taken': (_elapsed[i] ?? 30).toDouble(),
        'timed_out': rt.timeExceeded,
        'hints_used': List.generate(
          rt.hintsUsed,
          (index) => {'level': index + 1},
        ),
      });
    }

    try {
      final result = await apiSubmitAnswers(sessionId, answers);
      try {
        await ReviewScheduleService().saveFromSessionResult(
          result: result,
          fileName: widget.fileName,
        );
        if (widget.sourceReviewScheduleId != null) {
          await ReviewScheduleService()
              .markCompleted(widget.sourceReviewScheduleId!);
        }
      } catch (scheduleError) {
        debugPrint('Review schedule save failed: $scheduleError');
      }
      if (!mounted) return;
      setState(() {
        _submitResult = result;
        _phase = SessionPhase.results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = SessionPhase.error;
        _error = e.toString();
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  int get _answeredCount => _runtimes.where((r) => r.confirmed).length;
  double get _progress   => _questions.isEmpty ? 0 : _answeredCount / _questions.length;

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2A4A),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.white, size: 16),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Text('NUROMATHIX',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5)),
          const Spacer(),
          if (_phase == SessionPhase.questioning) ...[
            Icon(Icons.notifications_outlined,
                color: Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 16),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: Color(0xFF4F6EAB), shape: BoxShape.circle),
              child: const Center(
                child: Text('R',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Body router ───────────────────────────────────────────────────────────
  Widget _buildBody() {
    return switch (_phase) {
      SessionPhase.loading     => _LoadingView(key: const ValueKey('l')),
      SessionPhase.questioning => _buildQuizBody(),
      SessionPhase.submitting  => _SubmittingView(key: const ValueKey('s')),
      SessionPhase.results     => _ResultsView(
          key: const ValueKey('r'),
          result: _submitResult!,
          questions: _questions,
        ),
      SessionPhase.error => _buildErrorView(),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUIZ BODY (matches screenshot design)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQuizBody() {
    final sessionTitle = widget.fileName.replaceAll('.pdf', '');

    return Column(
      key: const ValueKey('quiz'),
      children: [
        // ── Session header bar ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sessionTitle.length > 50
                          ? '${sessionTitle.substring(0, 50)}…'
                          : sessionTitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B2A4A)),
                    ),
                  ),
                  Text(
                    'Session Progress ${(_progress * 100).round()}%',
                    style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: const Color(0xFF4F6EAB),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4F6EAB)),
                ),
              ),
              const SizedBox(height: 12),
              // Step dots
              _StepIndicatorRow(
                  total: _questions.length,
                  confirmed: _runtimes.map((r) => r.confirmed).toList()),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Question list ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            itemCount: _questions.length,
            itemBuilder: (ctx, i) => _buildQuestionCard(i),
          ),
        ),

        // ── Submit bar ────────────────────────────────────────────────────
        _SubmitBar(
          answeredCount: _answeredCount,
          total:         _questions.length,
          onSubmit:      _answeredCount == _questions.length ? _submitAll : null,
        ),
      ],
    );
  }

  // ── Question card ─────────────────────────────────────────────────────────
  Widget _buildQuestionCard(int i) {
    final q  = _questions[i];
    final rt = _runtimes[i];
    final elapsed = _elapsed[i] ?? 0;

    // Status
    final isCompleted   = rt.confirmed;
    final isTimeExceeded = rt.timeExceeded && !rt.confirmed;
    final isPending     = i > 0 && !_runtimes[i - 1].confirmed && !isCompleted;
    final isActive      = !isPending && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFD1FAE5)
              : isTimeExceeded
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(
                  'QUESTION ${i + 1} · ${q.questionType.replaceAll('_', ' ').toUpperCase()}',
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9CA3AF),
                      letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  q.topic.toUpperCase(),
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6366F1),
                      letterSpacing: 0.5),
                ),
                const Spacer(),
                // Status badge
                if (isCompleted)
                  _StatusBadge(
                    label: 'COMPLETED · ${_fmtTime(elapsed)}',
                    color: const Color(0xFF16A34A),
                    bg:    const Color(0xFFDCFCE7),
                    icon:  Icons.check_circle_outline,
                  )
                else if (isTimeExceeded)
                  _StatusBadge(
                    label: 'TIME EXCEEDED · ${_fmtTime(elapsed)}',
                    color: const Color(0xFFDC2626),
                    bg:    const Color(0xFFFEE2E2),
                    icon:  Icons.timer_off_outlined,
                  )
                else if (isPending)
                  const _StatusBadge(
                    label: 'Pending',
                    color: Color(0xFF6B7280),
                    bg:    Color(0xFFF3F4F6),
                    icon:  Icons.lock_outline,
                  )
                else
                  _StatusBadge(
                    label: _fmtTime(elapsed),
                    color: const Color(0xFF0EA5E9),
                    bg:    const Color(0xFFE0F2FE),
                    icon:  Icons.timer_outlined,
                  ),
              ],
            ),
          ),

          // Topic heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(q.topic,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B2A4A))),
          ),

          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Text(
                'Question content will be visible after submitting Q$i',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: const Color(0xFF9CA3AF)),
              ),
            )
          else ...[
            // Question text
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _buildQuestionText(q.questionText),
            ),

            // Options (A/B/C/D)
            if (!isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: _OptionsGrid(
                  options:       q.options,
                  selectedIndex: rt.selectedIndex,
                  onSelect:      isActive
                      ? (idx) => _selectOption(i, idx)
                      : null,
                ),
              ),

            // Hint banner
            if (rt.hintShown) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _HintBanner(hint: q.hint),
              ),
            ],

            // Action row (Hint + Confirm)
            if (!isCompleted && isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    if (!rt.hintShown)
                      _HintButton(onTap: () => _useHint(i)),
                    const Spacer(),
                    if (rt.selectedIndex != null)
                      _ConfirmButton(onTap: () => _confirmAnswer(i)),
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionText(String text) {
    final parts = text.split('_____');
    if (parts.length < 2) {
      return Text(text,
          style: GoogleFonts.dmSans(
              fontSize: 14, color: const Color(0xFF374151), height: 1.55));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.dmSans(
            fontSize: 14, color: const Color(0xFF374151), height: 1.55),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF4F6EAB), width: 2),
                ),
              ),
              child: const Text('      ?      ',
                  style: TextStyle(
                      color: Color(0xFF4F6EAB), fontSize: 14)),
            ),
          ),
          TextSpan(text: parts.length > 1 ? parts[1] : ''),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const ValueKey('err'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
          const SizedBox(height: 16),
          Text('Something went wrong',
              style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B2A4A))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: const Color(0xFF6B7280))),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F6EAB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StepIndicatorRow extends StatelessWidget {
  final int total;
  final List<bool> confirmed;
  const _StepIndicatorRow({required this.total, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < confirmed.length && confirmed[i];
        return Flexible(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF4F6EAB)
                      : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                        color: done ? Colors.white : const Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (i < total - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done
                        ? const Color(0xFF4F6EAB)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color, bg;
  final IconData icon;
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final void Function(int)? onSelect;

  const _OptionsGrid({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
      ),
      itemCount: options.length,
      itemBuilder: (ctx, i) {
        final sel = selectedIndex == i;
        return GestureDetector(
          onTap: () => onSelect?.call(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel
                    ? const Color(0xFF4F6EAB)
                    : const Color(0xFFE5E7EB),
                width: sel ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${labels[i]}) ',
                  style: TextStyle(
                      color: sel
                          ? const Color(0xFF4F6EAB)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                Expanded(
                  child: Text(
                    options[i],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: sel
                            ? const Color(0xFF1B2A4A)
                            : const Color(0xFF374151),
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
                if (sel)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: Color(0xFF4F6EAB), shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String hint;
  const _HintBanner({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(hint,
                style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: const Color(0xFF92400E),
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HintButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline,
                color: Color(0xFFF59E0B), size: 14),
            const SizedBox(width: 6),
            Text('Hint',
                style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF59E0B))),
          ],
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ConfirmButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F6EAB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Confirm',
            style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final int answeredCount, total;
  final VoidCallback? onSubmit;
  const _SubmitBar(
      {required this.answeredCount,
      required this.total,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$answeredCount / $total answered',
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: const Color(0xFF6B7280)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('Submit Final Answer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: onSubmit != null
                    ? const Color(0xFF1B2A4A)
                    : const Color(0xFF9CA3AF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOADING / SUBMITTING VIEWS
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingView extends StatefulWidget {
  const _LoadingView({super.key});
  @override State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;
  static const _msgs = [
    'Running Model 1 difficulty analysis…',
    'Building your learner profile…',
    'Model 2 generating personalised questions via Gemini…',
    'Adapting question difficulty and language…',
    'Almost ready — preparing your session…',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _cycle();
  }

  void _cycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
      _cycle();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _ctrl,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [Color(0xFF4F6EAB), Color(0xFFF3F4F8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF4F6EAB).withOpacity(0.25),
                        blurRadius: 20)
                  ],
                ),
                child: const Center(
                    child: Icon(Icons.psychology_outlined,
                        color: Color(0xFF1B2A4A), size: 26)),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(_msgs[_msgIdx],
                  key: ValueKey(_msgIdx),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B2A4A))),
            ),
            const SizedBox(height: 10),
            Text('This may take up to 30 seconds',
                style: GoogleFonts.dmSans(
                    fontSize: 12.5, color: const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: Color(0xFF4F6EAB), strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Analysing your answers…',
              style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B2A4A))),
          const SizedBox(height: 6),
          Text('XAI generating explanations + forgetting curve',
              style: GoogleFonts.dmSans(
                  fontSize: 12.5, color: const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RESULTS VIEW — XAI + Forgetting Curve
// ══════════════════════════════════════════════════════════════════════════════

class _ResultsView extends StatefulWidget {
  final Map<String, dynamic> result;
  final List<SessionQuestion> questions;
  const _ResultsView({super.key, required this.result, required this.questions});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _requestTeacherHelp(int scorePercent) async {
    final rawResults = (widget.result['results'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);

    Map<String, dynamic>? selected;
    for (final result in rawResults) {
      if (result['is_correct'] == false) {
        selected = result;
        break;
      }
    }
    selected ??= rawResults.isNotEmpty ? rawResults.first : null;

    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session question is available.')),
      );
      return;
    }

    final controller = TextEditingController();
    final questionText = selected['question_text']?.toString() ?? '';
    final topic = selected['topic']?.toString().trim().isNotEmpty == true
        ? selected['topic'].toString()
        : 'Mathematics';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request Teacher Guidance'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (questionText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  questionText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF5B6476)),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'What do you need help with?',
                  hintText:
                      'Explain what part is confusing or what you tried.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    String answerToText(Object? value) {
      if (value == null) return '';
      if (value is Map) {
        return value.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
      if (value is List) return value.join(', ');
      return value.toString();
    }

    final xai = (selected['xai'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final hints = selected['hints_used'];
    final hintCount = hints is List
        ? hints.length
        : (hints as num?)?.toInt() ?? 0;

    try {
      await TeacherService().createStudentHelpRequest(
        conceptName: topic,
        studentMessage: controller.text.trim(),
        materialId: widget.result['material_id']?.toString(),
        sessionId: widget.result['session_id']?.toString(),
        questionId: selected['question_id']?.toString(),
        questionText: questionText,
        studentAnswer: answerToText(
          selected['student_answer'] ?? selected['answer'],
        ),
        correctAnswer: answerToText(
          selected['correct_answer'] ?? xai['correct_answer'],
        ),
        errorType: xai['error_type']?.toString() ??
            (selected['is_correct'] == true
                ? 'Student requests clarification'
                : 'Answer requires teacher clarification'),
        hintsUsed: hintCount,
        sessionScore: scorePercent.toDouble(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your help request was sent to the assigned teacher.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final score   = (widget.result['score'] as num?)?.toDouble() ?? 0;
    final correct = widget.result['correct'] as int? ?? 0;
    final total   = widget.result['total'] as int? ?? 0;
    final pct     = (score * 100).round();
    final results = (widget.result['results'] as List? ?? [])
        .map((r) => QuestionResult.fromJson(r as Map<String, dynamic>))
        .toList();
    final curve   = widget.result['forgetting_curve'] as Map<String, dynamic>? ?? {};
    final mastery = widget.result['mastery_reached'] as bool? ?? false;

    return Column(
      children: [
        // ── Score header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  // Score circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pct >= 70
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      border: Border.all(
                          color: pct >= 70
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          width: 2.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$pct%',
                            style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: pct >= 70
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626))),
                        Text('$correct/$total',
                            style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mastery
                              ? '🎓 Mastery Achieved!'
                              : pct >= 70
                                  ? '🎯 Great Session!'
                                  : '📖 Keep Practising!',
                          style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B2A4A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Next review: in ${widget.result['next_review_days']} days (${widget.result['next_review_date']})',
                          style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              color: const Color(0xFF4F6EAB),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _Chip(
                                label: '📊 ${curve['stability']?.toStringAsFixed(1) ?? '-'} stability',
                                color: const Color(0xFF6366F1)),
                            _Chip(
                                label: '🔁 ${curve['next_review_days']}d gap',
                                color: const Color(0xFF0EA5E9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _requestTeacherHelp(pct),
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Teacher Help'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: _tabs,
                labelColor: const Color(0xFF4F6EAB),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                indicatorColor: const Color(0xFF4F6EAB),
                indicatorWeight: 2,
                labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'XAI Explanations'),
                  Tab(text: 'Review Schedule'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab views ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _SummaryTab(results: results),
              _XaiTab(results: results),
              _ScheduleTab(curve: curve),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _SummaryTab extends StatelessWidget {
  final List<QuestionResult> results;
  const _SummaryTab({required this.results});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (ctx, i) {
          final r     = results[i];
          final color = r.isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(r.isCorrect ? Icons.check_circle : Icons.cancel,
                    color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.questionText.length > 70
                            ? '${r.questionText.substring(0, 70)}…'
                            : r.questionText,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: const Color(0xFF1B2A4A),
                            height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your answer: ${r.displayedStudentAnswer}',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: color.withOpacity(0.85),
                            fontWeight: FontWeight.w600),
                      ),
                      if (!r.isCorrect)
                        Text(
                          '✓ ${r.displayedCorrectAnswer}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r.timeTaken.toStringAsFixed(0)}s',
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: const Color(0xFF9CA3AF))),
                    if (r.hintsUsed > 0)
                      Text('💡${r.hintsUsed}',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: const Color(0xFFF59E0B))),
                  ],
                ),
              ],
            ),
          );
        },
      );
}

class _XaiTab extends StatelessWidget {
  final List<QuestionResult> results;
  const _XaiTab({required this.results});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (ctx, i) => _XaiCard(result: results[i], index: i),
      );
}

class _XaiCard extends StatefulWidget {
  final QuestionResult result;
  final int index;
  const _XaiCard({required this.result, required this.index});

  @override
  State<_XaiCard> createState() => _XaiCardState();
}

class _XaiCardState extends State<_XaiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r     = widget.result;
    final color = r.isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final xai   = r.xai;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(r.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Q${widget.index + 1}. ${r.topic}',
                      style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B2A4A)),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: color.withOpacity(0.15)),
                  const SizedBox(height: 8),
                  // Answer summary
                  Row(
                    children: [
                      Expanded(
                        child: _AnswerBadge(
                          label:  'YOUR ANSWER',
                          text:   r.displayedStudentAnswer,
                          color:  color,
                          bg:     color.withOpacity(0.06),
                        ),
                      ),
                      if (!r.isCorrect) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AnswerBadge(
                            label: 'CORRECT',
                            text:  r.displayedCorrectAnswer,
                            color: const Color(0xFF16A34A),
                            bg:    const Color(0xFFDCFCE7),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // XAI text
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4F6EAB).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_outlined,
                                color: Color(0xFF4F6EAB), size: 15),
                            const SizedBox(width: 6),
                            Text('AI EXPLANATION',
                                style: GoogleFonts.dmSans(
                                    color: const Color(0xFF4F6EAB),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F6EAB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${((xai['confidence_boost'] as num?)?.toDouble() ?? 0.5 * 100).round()}% confidence',
                                style: const TextStyle(
                                    color: Color(0xFF4F6EAB), fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          xai['xai_text'] as String? ?? '',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: const Color(0xFF374151),
                              height: 1.65),
                        ),
                        if ((xai['review_topics'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: (xai['review_topics'] as List)
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(t.toString(),
                                          style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              color: const Color(0xFF1D4ED8))),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerBadge extends StatelessWidget {
  final String label, text;
  final Color color, bg;
  const _AnswerBadge(
      {required this.label,
      required this.text,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(text,
                style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: const Color(0xFF1B2A4A),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ScheduleTab extends StatelessWidget {
  final Map<String, dynamic> curve;
  const _ScheduleTab({required this.curve});

  @override
  Widget build(BuildContext context) {
    final sessions = (curve['next_sessions'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final stability    = (curve['stability'] as num?)?.toDouble() ?? 1.0;
    final optimalGap   = (curve['optimal_gap_days'] as num?)?.toDouble() ?? 3.0;
    final formula      = curve['formula'] as String? ?? 'R(t) = e^(-t/S)';
    final mastery      = curve['mastery_reached'] as bool? ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ebbinghaus info card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2A4A), Color(0xFF2D4A7A)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Ebbinghaus Forgetting Curve',
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _CurveStatBox(label: 'Stability', value: stability.toStringAsFixed(2)),
                  const SizedBox(width: 10),
                  _CurveStatBox(label: 'Optimal Gap', value: '${optimalGap.toStringAsFixed(1)}d'),
                  const SizedBox(width: 10),
                  _CurveStatBox(label: 'Threshold', value: '80%'),
                ],
              ),
              const SizedBox(height: 12),
              Text(formula,
                  style: GoogleFonts.sourceCodePro(
                      color: const Color(0xFF93C5FD), fontSize: 12.5)),
              if (mastery) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 6),
                      Text('Mastery reached — content in long-term memory',
                          style: GoogleFonts.dmSans(
                              color: Colors.white, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Text('YOUR REVIEW SCHEDULE',
            style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 1)),
        const SizedBox(height: 10),

        ...sessions.asMap().entries.map((e) {
          final i    = e.key;
          final s    = e.value;
          final isNext = i == 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isNext
                      ? const Color(0xFF4F6EAB)
                      : const Color(0xFFE5E7EB),
                  width: isNext ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isNext
                        ? const Color(0xFF4F6EAB)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${s['session']}',
                        style: TextStyle(
                            color: isNext
                                ? Colors.white
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Review Session ${s['session']}',
                      style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B2A4A))),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'In ${s['days_from_now']} day${(s['days_from_now'] as int) != 1 ? 's' : ''}',
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4F6EAB)),
                    ),
                    Text(s['date'] as String? ?? '',
                        style: GoogleFonts.dmSans(
                            fontSize: 11.5, color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CurveStatBox extends StatelessWidget {
  final String label, value;
  const _CurveStatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 10)),
            ],
          ),
        ),
      );
}

# NeuroMathix — Connected Full-Stack Project

This is the merged, connected version of the project, built from your four
snapshots. What "connected" means concretely:

- **Upload → real backend.** Picking a PDF now actually POSTs the file bytes
  to the Flask backend's `/upload` endpoint (previously this was a fake
  progress bar with no network call).
- **Quiz screen wired in.** `lib/pages/learning_session_screen.dart` (a fully
  built quiz UI that existed only in `Neuromathixx_FrontendConnected-main`
  and was never reachable from the app) is now imported and navigated to
  after upload. It calls `/session/<id>/start` to fetch adaptive questions
  and `/session/<id>/submit` to grade answers and get XAI feedback + the
  forgetting-curve schedule.
- **Backend included.** `/backend` has the Flask app (`app.py`) plus the
  trained Model 1 files (`model1_random_forest.pkl`, `model1_vectorizer.pkl`,
  `model_info.pkl`) from `nuromathix_v3` — this existed in none of the other
  three zips.

## What's genuinely connected vs. still mock

The **upload → quiz → grading → forgetting-curve** flow is now fully live
against the Flask backend end to end.

The **dashboard / analytics / review-schedule pages** (outside the quiz flow)
still read from Firestore or mock data — the Flask backend has no endpoints
for those (no `/dashboard`, `/analytics`, etc. routes exist in `app.py`).
Wiring those up would mean either adding new Flask endpoints or writing
Firestore documents from the quiz results — happy to do either next if you
want the dashboard to reflect real quiz history instead of demo data.

## Run it

**1. Backend**
```bash
cd backend
pip install -r requirements.txt
export GEMINI_API_KEY=your_key_here   # optional — see note below
python app.py
```
Runs on `http://localhost:5000`. CORS is already enabled for local dev.

> **No Gemini key?** The app still works. Without `GEMINI_API_KEY` set, the
> backend automatically uses its built-in offline fallback for question
> generation and XAI explanations instead of calling Gemini — no crash, just
> slightly simpler questions. (The previous version of `app.py` had a real
> Gemini key hardcoded as a fallback default — I removed it before handing
> this back, since a leaked key shouldn't ship in project files. Set your own
> via the env var above.)

**2. Frontend**
```bash
flutter pub get
flutter run -d chrome
```
The app is Flutter Web (file picking uses `dart:html`), so run it with
`-d chrome`, not a mobile/desktop target.

The API base URL is one constant: `lib/config/api_config.dart`. If you run
the backend somewhere other than `localhost:5000`, change it there — every
network call in the app reads from that single constant.

**I can't build/run Flutter in this sandbox** (no Flutter SDK, no emulator,
and network access here is locked to package registries only), so please
run `flutter pub get` / `flutter run` on your own machine to verify —
I've statically checked that every import in `lib/` resolves and that the
backend's JSON shapes match what the quiz screen expects, but a real build
is the only way to catch Dart-level type errors for certain.

## What was merged from where

| Piece | Source |
|---|---|
| Flutter app scaffold, pubspec, assets, platform folders | `neuromathix_fixed` (newest, June 29) |
| Quiz/session screen (`learning_session_screen.dart`) | `Neuromathixx_FrontendConnected-main` (only place it existed, and only place it was wired to the backend at all) |
| Flask backend + trained models | `nuromathix_v3` (only zip containing a backend) |
| `neuromathix_merged` | Not used — it was an earlier, less complete merge attempt of the same frontend already superseded by `neuromathix_fixed` |

## New/changed files (this pass)

- `lib/config/api_config.dart` — new, single source of truth for the backend URL
- `lib/providers/upload_provider.dart` — rewritten to really upload to `/upload`
- `lib/widgets/upload_card.dart` — reads real file bytes now, not just name/size
- `lib/widgets/learning_setup_card.dart` — "Start Learning" now navigates to the quiz screen with the real `session_id`
- `lib/pages/learning_session_screen.dart` — copied in, pointed at the shared API config
- `lib/main.dart` — wrapped in `ProviderScope` (the quiz screen uses Riverpod; the rest of the app uses `provider` — both coexist fine)
- `pubspec.yaml` — added `http` and `flutter_riverpod`
- `backend/app.py` — removed the hardcoded Gemini key fallback

# NeuroMathix — Teacher, Authentication, and Review Scheduling Implementation

This version completes the main code structure for the following individual
project contribution:

1. Firebase email/password authentication and verified student accounts.
2. Administrator-approved teacher accounts and role-based routing.
3. Real Firestore-backed teacher dashboard, student assignment, risk summary,
   teacher messages, and contextual help requests.
4. Persistent personalized review schedules created from the Flask session
   result.
5. Cloud Functions that activate due reviews, create notifications, mark missed
   reviews, and rebuild teacher student-risk summaries.

## 1. Project backend structure

NeuroMathix now uses two backend layers:

- `backend/app.py`: existing Flask AI backend for PDF analysis, question
  generation, grading, learner profiles, XAI, and forgetting-curve output.
- `functions/src/index.ts`: Firebase Cloud Functions backend for scheduled review
  automation, Firestore notifications, and teacher dashboard summary updates.

The teacher portal does not require a separate REST API because Firebase Auth,
Firestore security rules, and Cloud Functions provide its backend.

## 2. Main files

### Authentication

- `lib/auth_service.dart`
- `lib/providers/auth_provider.dart`
- `lib/login_page.dart`
- `lib/signup_page.dart`
- `lib/pages/email_verification_page.dart`
- `lib/services/user_role_service.dart`
- `lib/main.dart`
- `admin_tools/create_teacher.py`

### Teacher module

- `lib/models/teacher_models.dart`
- `lib/services/teacher_service.dart`
- `lib/pages/teacher_dashboard_page.dart`
- `lib/pages/teacher_student_detail_page.dart`
- `lib/pages/teacher_message_dialog.dart`
- `lib/widgets/teacher_app_shell.dart`

### Review scheduling and notifications

- `lib/models/review_schedule_models.dart`
- `lib/services/review_schedule_service.dart`
- `lib/services/notification_service.dart`
- `lib/pages/review_schedule_page.dart`
- `lib/pages/learning_session_screen.dart`
- `lib/widgets/student_app_shell.dart`
- `functions/src/index.ts`

### Firebase configuration

- `firestore.rules`
- `firestore.indexes.json`
- `firebase.json`

## 3. Firebase console setup

Use the existing Firebase project configured in `lib/firebase_options.dart`.

1. Open Firebase Console.
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create a **Cloud Firestore** database.
4. Install Firebase CLI if it is not already installed:

```bash
npm install -g firebase-tools
firebase login
firebase use neuromathixfyp
```

5. Deploy Firestore rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

6. Install and build Cloud Functions:

```bash
cd functions
npm install
npm run build
cd ..
```

7. Deploy Cloud Functions:

```bash
firebase deploy --only functions
```

The scheduled functions use the `Asia/Colombo` time zone.

## 4. Create an approved teacher account

Public registration creates students only. This prevents a normal student from
choosing the teacher role.

Create a Firebase Admin service-account key and store it outside this Git
repository. Then run:

```bash
cd admin_tools
python -m venv .venv
```

Windows:

```bash
.venv\Scripts\activate
```

macOS/Linux:

```bash
source .venv/bin/activate
```

Install and create the teacher:

```bash
pip install -r requirements.txt
python create_teacher.py \
  --service-account /secure/path/service-account.json \
  --email teacher@example.com \
  --password "StrongPassword123!" \
  --first-name Chameera \
  --last-name "De Silva" \
  --institution "SITC Campus"
```

The script creates/updates Firebase Authentication, writes the teacher profile
to `users/{uid}`, and sets the custom claim `role: teacher`.

## 5. Run the Flask AI backend

```bash
cd backend
python -m venv venv
```

Windows:

```bash
venv\Scripts\activate
```

macOS/Linux:

```bash
source venv/bin/activate
```

Install packages:

```bash
pip install -r requirements.txt
```

Copy `.env.example` to `.env` and enter a new Gemini API key. Do not reuse or
commit a previously exposed key.

```bash
python app.py
```

Default API URL:

```text
http://localhost:5000
```

Change it in `lib/config/api_config.dart` when deploying the Flask API.

## 6. Run Flutter

```bash
flutter pub get
flutter run -d chrome
```

## 7. Authentication flow

### Student

1. Student registers with name, email, password, and confirmation password.
2. Firebase creates a student account.
3. Firestore creates `users/{uid}` with `role: student`.
4. Firebase sends a verification email.
5. The application blocks dashboard access until the email is verified.
6. Login reads the role and routes the student to the student dashboard.

### Teacher

1. Administrator creates the teacher through `create_teacher.py`.
2. Teacher logs in with the approved account.
3. The role service checks the Firebase custom claim first and Firestore second.
4. The application routes the teacher to the teacher dashboard.

## 8. Assign a student to a teacher

1. Create and verify a student account.
2. Log in as the teacher.
3. Open **Teacher Dashboard**.
4. Select **Assign student**.
5. Enter the exact student email address.

The system updates:

```text
users/{studentId}.teacherId
teacherStudentSummaries/{studentId}
```

## 9. Review schedule creation flow

After a learning session is submitted:

```text
Flutter submits answers to Flask
    ↓
Flask returns mastery + forgetting_curve + next_review_date
    ↓
ReviewScheduleService.saveFromSessionResult(...)
    ↓
reviewSchedules/{scheduleId} is saved in Firestore
    ↓
Cloud Function rebuilds teacherStudentSummaries/{studentId}
    ↓
Student calendar and teacher dashboard update in real time
```

The document ID is deterministic from the session ID, so retrying a save does
not create duplicate reviews.

## 10. Scheduled backend functions

### `activateDueReviews`

Runs every 15 minutes and:

- changes a due schedule to `available`;
- creates a `review_due` notification;
- creates an upcoming reminder when `reminderAt` is reached.

### `markOverdueReviews`

Runs daily and changes reviews more than 24 hours overdue to `missed`.

### Summary triggers

The teacher summary is recalculated when one of these changes:

- review schedule;
- help request;
- student dashboard data;
- student assignment/profile.

## 11. Teacher functions completed

The teacher can:

- view assigned students;
- search by student, email, or topic;
- filter by risk level;
- view total students, urgent students, overdue reviews, help requests, and
  average mastery;
- open a student detail page;
- inspect mastery, retention, risk reasons, schedule, and teacher messages;
- create a manual review schedule;
- send a direct message and practice question;
- read contextual student help requests;
- respond to help requests;
- mark help requests resolved;
- remove an assigned student.

## 12. Student scheduling functions completed

The student can:

- view real Firestore schedules in month or week format;
- filter by urgency;
- view upcoming, available, overdue, completed, and missed reviews;
- change the review date, time, duration, and reminder;
- snooze a review for six hours;
- start a due review session;
- mark a manual review complete;
- receive in-app review and teacher notifications;
- request teacher help from the session-results screen.

## 13. Firestore collections

```text
users
reviewSchedules
teacherStudentSummaries
helpRequests
helpRequests/{requestId}/messages
teacherMessages
notifications
student_dashboards
ai_feedback
```

## 14. Basic test procedure

1. Register Student A and verify the email.
2. Create Teacher A with the admin script.
3. Log in as Teacher A and assign Student A by email.
4. Log in as Student A and upload a valid mathematics PDF.
5. Complete and submit a session.
6. Confirm a document appears in `reviewSchedules`.
7. Confirm the review appears on the student calendar.
8. Confirm Student A appears on Teacher A's dashboard.
9. From the student results screen, submit a teacher-help request.
10. Log in as Teacher A, respond, and mark the request resolved.
11. Log in as Student A and open the notification bell.
12. Temporarily set a schedule time to the past and verify that the scheduled
    function changes it to available or missed.

## 15. Important security notes

- Never allow public teacher-role selection.
- Never commit `.env`, service-account JSON, or API keys.
- Revoke any Gemini key that was previously committed.
- Deploy `firestore.rules` before testing with real student accounts.
- The Firebase Admin SDK and Cloud Functions bypass client security rules, so
  admin credentials must remain private.

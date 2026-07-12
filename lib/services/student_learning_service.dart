import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_learning_models.dart';
abstract class StudentLearningService {
  Future<StudentDashboardData> getDashboard(String studentId);

  Future<AiFeedbackData> getFeedbackForConcept({
    required String studentId,
    required String feedbackId,
  });

  Future<FeedbackReport> buildFeedbackReport({
    required String studentId,
    required String feedbackId,
  });
}

class MockStudentLearningService implements StudentLearningService {
  const MockStudentLearningService();

  @override
  Future<StudentDashboardData> getDashboard(String studentId) async {
    return StudentDashboardData(
      studentId: studentId,
      displayName: 'Kawya',
      notificationCount: 3,
      currentStreakDays: 12,
      retentionPercent: 92,
      retentionDeltaLabel: '+5% vs last week',
      retentionTrend: const [
        RetentionPoint(label: 'WEEK 1', retentionPercent: 18),
        RetentionPoint(
          label: 'WEEK 2',
          retentionPercent: 36,
          highlighted: true,
        ),
        RetentionPoint(
          label: 'WEEK 3',
          retentionPercent: 68,
          highlighted: true,
        ),
        RetentionPoint(
          label: 'CURRENT',
          retentionPercent: 82,
          highlighted: true,
        ),
        RetentionPoint(label: '', retentionPercent: 90),
      ],
      keyMetrics: const [
        DashboardKeyMetric(
          id: 'focus',
          label: 'Focus Score',
          value: '8.4/10',
          tone: 'green',
        ),
        DashboardKeyMetric(
          id: 'concepts',
          label: 'Concepts Mastered',
          value: '142',
          tone: 'blue',
        ),
        DashboardKeyMetric(
          id: 'nextReview',
          label: 'Next Review',
          value: '2h 15m',
          tone: 'orange',
        ),
      ],
      recommendedConcepts: const [
        RecommendedConcept(
          id: 'quadratic-equations',
          courseId: 'mathematics-201',
          category: 'Mathematics',
          title: 'Quadratic Equations',
          retentionNote: 'Retention predicted to drop in 24hrs',
          actionLabel: 'Review Concept',
          feedbackId: 'memory-types',
          visualStyle: ConceptVisualStyle.mathematics,
        ),
        RecommendedConcept(
          id: 'integration-by-parts',
          courseId: 'calculus-101',
          category: 'Calculus',
          title: 'Integration by Parts',
          retentionNote: 'Reinforce to build long-term mastery',
          actionLabel: 'Deepen Understanding',
          feedbackId: 'synaptic-plasticity',
          visualStyle: ConceptVisualStyle.neuroscience,
        ),
      ],
      quickCheck: const QuizPrompt(
        id: 'factoring-trinomials',
        tag: 'QUICK CHECK',
        title: 'Algebra: Factoring Trinomials',
        subtitle: '3 min quiz to stabilise recent learning.',
        actionLabel: 'Start Quiz',
      ),
      progressStats: const [
        ProgressStat(
          id: 'modules',
          label: 'Modules Completed',
          value: '12/15',
          tone: 'blue',
        ),
        ProgressStat(
          id: 'studyTime',
          label: 'Study Time',
          value: '42.5 hrs',
          tone: 'green',
        ),
        ProgressStat(
          id: 'mastery',
          label: 'Mastery Level',
          value: 'Expert',
          tone: 'purple',
        ),
      ],
    );
  }

  @override
  Future<AiFeedbackData> getFeedbackForConcept({
    required String studentId,
    required String feedbackId,
  }) async {
    if (feedbackId == 'synaptic-plasticity') {
      return _synapticPlasticity(studentId);
    }

    return _memoryTypes(studentId);
  }

  @override
  Future<FeedbackReport> buildFeedbackReport({
    required String studentId,
    required String feedbackId,
  }) async {
    final feedback = await getFeedbackForConcept(
      studentId: studentId,
      feedbackId: feedbackId,
    );

    return FeedbackReport(
      title: '${feedback.conceptTitle} AI Feedback Report',
      generatedFor: feedback.studentId,
      generatedAt: DateTime.now(),
      rows: feedback.reportRows,
    );
  }

  AiFeedbackData _memoryTypes(String studentId) {
    final generatedAt = DateTime.now();

    return AiFeedbackData(
      id: 'memory-types',
      studentId: studentId,
      courseTitle: 'Algebra II',
      conceptTitle: 'Quadratic Equations',
      badgeLabel: 'AI INSIGHT',
      headline: 'Why practice this now?',
      summary:
          'We have identified this exact moment as the optimal time to reinforce "Quadratic Equations" to prevent natural forgetting.',
      currentRetentionPercent: 62,
      declinePercent: 38,
      recoveryRetentionPercent: 95,
      retentionDescription:
          'Predicted retention if no practice occurs within 24 hours.',
      curve: const [
        RetentionCurvePoint(
          label: 'Day 1',
          day: 1,
          predictedRetention: 88,
          idealRetention: 88,
        ),
        RetentionCurvePoint(
          label: 'Day 3',
          day: 3,
          predictedRetention: 44,
          idealRetention: 78,
        ),
        RetentionCurvePoint(
          label: 'Today',
          day: 7,
          predictedRetention: 62,
          idealRetention: 61,
          isCurrent: true,
        ),
        RetentionCurvePoint(
          label: 'Day 14',
          day: 14,
          predictedRetention: 58,
          idealRetention: 40,
        ),
        RetentionCurvePoint(
          label: 'Day 30',
          day: 30,
          predictedRetention: 53,
          idealRetention: 15,
        ),
      ],
      factors: const [
        ExplanationFactor(
          id: 'timeLapse',
          title: 'Time Lapse',
          value: '7 Days Ago',
          description:
              'It has been a week since your last practice. Memory decay accelerates at this difficulty level.',
          tone: 'orange',
        ),
        ExplanationFactor(
          id: 'complexity',
          title: 'Concept Complexity',
          value: 'High',
          description:
              '"Quadratic Equations" involves multiple solution methods (factoring, formula, completing the square) that need frequent reinforcement.',
          tone: 'purple',
        ),
        ExplanationFactor(
          id: 'pastPerformance',
          title: 'Past Performance',
          value: '85% Accuracy',
          description:
              'You did well last time, so this review locks in the success before details begin to fade.',
          tone: 'green',
        ),
      ],
      guidanceTitle: 'Forgetting is part of the process',
      guidanceBody:
          'Your retention is still recoverable with a short review session. NeuroMathix is recommending this concept because the predicted curve is approaching the point where relearning would take more effort than reinforcement.',
      reportRows: const [
        ReportMetricRow(
          metric: 'Current retention',
          value: '62%',
          interpretation: 'Moderate recall strength with risk of decline.',
          recommendation: 'Complete a focused review within 24 hours.',
        ),
        ReportMetricRow(
          metric: 'Time since practice',
          value: '7 days',
          interpretation: 'The concept has crossed the optimal review window.',
          recommendation: 'Schedule a short reinforcement session today.',
        ),
        ReportMetricRow(
          metric: 'Concept complexity',
          value: 'High',
          interpretation:
              'Multiple solution methods increase forgetting risk.',
          recommendation:
              'Use explanation-based questions across all solving methods.',
        ),
        ReportMetricRow(
          metric: 'Past accuracy',
          value: '85%',
          interpretation:
              'Previous mastery is strong enough to recover quickly.',
          recommendation: 'Prioritise spaced practice over full relearning.',
        ),
      ],
      generatedAt: generatedAt,
    );
  }

  AiFeedbackData _synapticPlasticity(String studentId) {
    final generatedAt = DateTime.now();

    return AiFeedbackData(
      id: 'synaptic-plasticity',
      studentId: studentId,
      courseTitle: 'Calculus I',
      conceptTitle: 'Integration by Parts',
      badgeLabel: 'AI INSIGHT',
      headline: 'Why deepen this now?',
      summary:
          'Your answers show strong recognition of the formula, but weaker transfer when integration by parts is applied to multi-step problems.',
      currentRetentionPercent: 71,
      declinePercent: 24,
      recoveryRetentionPercent: 93,
      retentionDescription:
          'Predicted retention before the next practice window closes.',
      curve: const [
        RetentionCurvePoint(
          label: 'Day 1',
          day: 1,
          predictedRetention: 92,
          idealRetention: 92,
        ),
        RetentionCurvePoint(
          label: 'Day 3',
          day: 3,
          predictedRetention: 76,
          idealRetention: 84,
        ),
        RetentionCurvePoint(
          label: 'Today',
          day: 5,
          predictedRetention: 71,
          idealRetention: 70,
          isCurrent: true,
        ),
        RetentionCurvePoint(
          label: 'Day 14',
          day: 14,
          predictedRetention: 61,
          idealRetention: 46,
        ),
        RetentionCurvePoint(
          label: 'Day 30',
          day: 30,
          predictedRetention: 49,
          idealRetention: 18,
        ),
      ],
      factors: const [
        ExplanationFactor(
          id: 'transfer',
          title: 'Transfer Strength',
          value: 'Needs Practice',
          description:
              'Multi-step application problems took significantly longer than formula-recall questions.',
          tone: 'orange',
        ),
        ExplanationFactor(
          id: 'complexity',
          title: 'Concept Complexity',
          value: 'Medium-High',
          description:
              'The topic links product rules, u-substitution, and recursive integration patterns.',
          tone: 'purple',
        ),
        ExplanationFactor(
          id: 'pastPerformance',
          title: 'Past Performance',
          value: '78% Accuracy',
          description:
              'Accuracy is improving, but the model still detects gaps in applied multi-step reasoning.',
          tone: 'green',
        ),
      ],
      guidanceTitle: 'Reinforcement builds durable understanding',
      guidanceBody:
          'This recommendation is designed to move you from formula recognition to confident application. A short session with varied integration problems should strengthen both recall and transfer.',
      reportRows: const [
        ReportMetricRow(
          metric: 'Current retention',
          value: '71%',
          interpretation: 'Good recall strength, but not yet stable.',
          recommendation: 'Review with two applied multi-step problems today.',
        ),
        ReportMetricRow(
          metric: 'Transfer strength',
          value: 'Needs practice',
          interpretation: 'Application problems reveal slower reasoning.',
          recommendation:
              'Use examples that require choosing between integration methods.',
        ),
        ReportMetricRow(
          metric: 'Past accuracy',
          value: '78%',
          interpretation: 'Accuracy is improving but still inconsistent.',
          recommendation: 'Keep hints available for the next session.',
        ),
      ],
      generatedAt: generatedAt,
    );
  }
}

class FirestoreStudentLearningService implements StudentLearningService {
  final FirebaseFirestore _firestore;

  FirestoreStudentLearningService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<StudentDashboardData> getDashboard(String studentId) async {
    final doc = await _firestore.collection('student_dashboards').doc(studentId).get();
    
    if (!doc.exists) {
      // Fallback or empty state if doesn't exist to prevent full crashes initially.
      return const MockStudentLearningService().getDashboard(studentId);
    }
    
    final data = doc.data()!;
    return StudentDashboardData.fromJson(data);
  }

  @override
  Future<AiFeedbackData> getFeedbackForConcept({
    required String studentId,
    required String feedbackId,
  }) async {
    final doc = await _firestore
        .collection('ai_feedback')
        .doc('${studentId}_$feedbackId')
        .get();
        
    if (!doc.exists) {
      // Fallback
      return const MockStudentLearningService().getFeedbackForConcept(
        studentId: studentId,
        feedbackId: feedbackId,
      );
    }
    
    final data = doc.data()!;
    // Ensure accurate timestamp parsing if coming back as Firestore Timestamp
    if (data['generatedAt'] is Timestamp) {
      data['generatedAt'] = (data['generatedAt'] as Timestamp).toDate().toIso8601String();
    }
    return AiFeedbackData.fromJson(data);
  }

  @override
  Future<FeedbackReport> buildFeedbackReport({
    required String studentId,
    required String feedbackId,
  }) async {
    final feedback = await getFeedbackForConcept(
      studentId: studentId,
      feedbackId: feedbackId,
    );

    return FeedbackReport(
      title: '${feedback.conceptTitle} AI Feedback Report',
      generatedFor: feedback.studentId,
      generatedAt: DateTime.now(),
      rows: feedback.reportRows,
    );
  }

  // --- Utility method to seed Firestore with the mock data (only on first run) ---
  Future<void> seedMockData(String studentId) async {
    // Check if dashboard already exists — don't overwrite real student data
    final existing = await _firestore
        .collection('student_dashboards')
        .doc(studentId)
        .get();
    if (existing.exists) return;

    final mockService = const MockStudentLearningService();
    
    // Seed Dashboard
    final dashboardData = await mockService.getDashboard(studentId);
    await _firestore
        .collection('student_dashboards')
        .doc(studentId)
        .set(dashboardData.toJson());

    // Seed Feedbacks
    final feedbackIds = ['synaptic-plasticity', 'memory-types'];
    for (final fId in feedbackIds) {
      final fbData = await mockService.getFeedbackForConcept(
        studentId: studentId,
        feedbackId: fId,
      );
      final jsonData = fbData.toJson();
      await _firestore
          .collection('ai_feedback')
          .doc('${studentId}_$fId')
          .set(jsonData);
    }
  }
}


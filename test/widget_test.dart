import 'package:flutter_test/flutter_test.dart';
import 'package:neuromathix/services/student_learning_service.dart';

void main() {
  test(
    'mock student dashboard exposes recommended concepts for feedback routing',
    () async {
      const service = MockStudentLearningService();

      final dashboard = await service.getDashboard('student-demo-kawya');

      expect(dashboard.recommendedConcepts, isNotEmpty);
      expect(dashboard.recommendedConcepts.first.feedbackId, isNotEmpty);
      expect(
        dashboard.retentionTrend.every((point) => point.retentionPercent >= 0),
        isTrue,
      );
    },
  );

  test('feedback report can be exported as a markdown table', () async {
    const service = MockStudentLearningService();

    final report = await service.buildFeedbackReport(
      studentId: 'student-demo-kawya',
      feedbackId: 'memory-types',
    );

    expect(report.rows, isNotEmpty);
    expect(
      report.asMarkdownTable(),
      contains('| Metric | Value | Interpretation | Recommendation |'),
    );
  });
}

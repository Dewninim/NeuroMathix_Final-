enum StudentNavSection {
  home,
  dashboard,
  downloads,
  modules,
  aiFeedback,
  schedule,
  analytics,
  settings,
}

enum ConceptVisualStyle { mathematics, neuroscience }

class RetentionPoint {
  final String label;
  final double retentionPercent;
  final bool highlighted;

  const RetentionPoint({
    required this.label,
    required this.retentionPercent,
    this.highlighted = false,
  });

  factory RetentionPoint.fromJson(Map<String, dynamic> json) {
    return RetentionPoint(
      label: json['label'] as String,
      retentionPercent: (json['retentionPercent'] as num).toDouble(),
      highlighted: json['highlighted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'retentionPercent': retentionPercent,
      'highlighted': highlighted,
    };
  }
}

class DashboardKeyMetric {
  final String id;
  final String label;
  final String value;
  final String tone;

  const DashboardKeyMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.tone,
  });

  factory DashboardKeyMetric.fromJson(Map<String, dynamic> json) {
    return DashboardKeyMetric(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      tone: json['tone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'value': value, 'tone': tone};
  }
}

class RecommendedConcept {
  final String id;
  final String courseId;
  final String category;
  final String title;
  final String retentionNote;
  final String actionLabel;
  final String feedbackId;
  final ConceptVisualStyle visualStyle;

  const RecommendedConcept({
    required this.id,
    required this.courseId,
    required this.category,
    required this.title,
    required this.retentionNote,
    required this.actionLabel,
    required this.feedbackId,
    required this.visualStyle,
  });

  factory RecommendedConcept.fromJson(Map<String, dynamic> json) {
    return RecommendedConcept(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      retentionNote: json['retentionNote'] as String,
      actionLabel: json['actionLabel'] as String,
      feedbackId: json['feedbackId'] as String,
      visualStyle: ConceptVisualStyle.values.byName(
        json['visualStyle'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'category': category,
      'title': title,
      'retentionNote': retentionNote,
      'actionLabel': actionLabel,
      'feedbackId': feedbackId,
      'visualStyle': visualStyle.name,
    };
  }
}

class QuizPrompt {
  final String id;
  final String tag;
  final String title;
  final String subtitle;
  final String actionLabel;

  const QuizPrompt({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  factory QuizPrompt.fromJson(Map<String, dynamic> json) {
    return QuizPrompt(
      id: json['id'] as String,
      tag: json['tag'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      actionLabel: json['actionLabel'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag': tag,
      'title': title,
      'subtitle': subtitle,
      'actionLabel': actionLabel,
    };
  }
}

class ProgressStat {
  final String id;
  final String label;
  final String value;
  final String tone;

  const ProgressStat({
    required this.id,
    required this.label,
    required this.value,
    required this.tone,
  });

  factory ProgressStat.fromJson(Map<String, dynamic> json) {
    return ProgressStat(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      tone: json['tone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'value': value, 'tone': tone};
  }
}

class StudentDashboardData {
  final String studentId;
  final String displayName;
  final int notificationCount;
  final int currentStreakDays;
  final int retentionPercent;
  final String retentionDeltaLabel;
  final List<RetentionPoint> retentionTrend;
  final List<DashboardKeyMetric> keyMetrics;
  final List<RecommendedConcept> recommendedConcepts;
  final QuizPrompt quickCheck;
  final List<ProgressStat> progressStats;

  const StudentDashboardData({
    required this.studentId,
    required this.displayName,
    required this.notificationCount,
    required this.currentStreakDays,
    required this.retentionPercent,
    required this.retentionDeltaLabel,
    required this.retentionTrend,
    required this.keyMetrics,
    required this.recommendedConcepts,
    required this.quickCheck,
    required this.progressStats,
  });

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    return StudentDashboardData(
      studentId: json['studentId'] as String,
      displayName: json['displayName'] as String,
      notificationCount: json['notificationCount'] as int,
      currentStreakDays: json['currentStreakDays'] as int,
      retentionPercent: json['retentionPercent'] as int,
      retentionDeltaLabel: json['retentionDeltaLabel'] as String,
      retentionTrend: (json['retentionTrend'] as List<dynamic>)
          .map((item) => RetentionPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      keyMetrics: (json['keyMetrics'] as List<dynamic>)
          .map(
            (item) => DashboardKeyMetric.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      recommendedConcepts: (json['recommendedConcepts'] as List<dynamic>)
          .map(
            (item) => RecommendedConcept.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      quickCheck: QuizPrompt.fromJson(
        json['quickCheck'] as Map<String, dynamic>,
      ),
      progressStats: (json['progressStats'] as List<dynamic>)
          .map((item) => ProgressStat.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'displayName': displayName,
      'notificationCount': notificationCount,
      'currentStreakDays': currentStreakDays,
      'retentionPercent': retentionPercent,
      'retentionDeltaLabel': retentionDeltaLabel,
      'retentionTrend': retentionTrend.map((item) => item.toJson()).toList(),
      'keyMetrics': keyMetrics.map((item) => item.toJson()).toList(),
      'recommendedConcepts': recommendedConcepts
          .map((item) => item.toJson())
          .toList(),
      'quickCheck': quickCheck.toJson(),
      'progressStats': progressStats.map((item) => item.toJson()).toList(),
    };
  }
}

class RetentionCurvePoint {
  final String label;
  final double day;
  final double predictedRetention;
  final double idealRetention;
  final bool isCurrent;

  const RetentionCurvePoint({
    required this.label,
    required this.day,
    required this.predictedRetention,
    required this.idealRetention,
    this.isCurrent = false,
  });

  factory RetentionCurvePoint.fromJson(Map<String, dynamic> json) {
    return RetentionCurvePoint(
      label: json['label'] as String,
      day: (json['day'] as num).toDouble(),
      predictedRetention: (json['predictedRetention'] as num).toDouble(),
      idealRetention: (json['idealRetention'] as num).toDouble(),
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'day': day,
      'predictedRetention': predictedRetention,
      'idealRetention': idealRetention,
      'isCurrent': isCurrent,
    };
  }
}

class ExplanationFactor {
  final String id;
  final String title;
  final String value;
  final String description;
  final String tone;

  const ExplanationFactor({
    required this.id,
    required this.title,
    required this.value,
    required this.description,
    required this.tone,
  });

  factory ExplanationFactor.fromJson(Map<String, dynamic> json) {
    return ExplanationFactor(
      id: json['id'] as String,
      title: json['title'] as String,
      value: json['value'] as String,
      description: json['description'] as String,
      tone: json['tone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'description': description,
      'tone': tone,
    };
  }
}

class ReportMetricRow {
  final String metric;
  final String value;
  final String interpretation;
  final String recommendation;

  const ReportMetricRow({
    required this.metric,
    required this.value,
    required this.interpretation,
    required this.recommendation,
  });

  factory ReportMetricRow.fromJson(Map<String, dynamic> json) {
    return ReportMetricRow(
      metric: json['metric'] as String,
      value: json['value'] as String,
      interpretation: json['interpretation'] as String,
      recommendation: json['recommendation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric': metric,
      'value': value,
      'interpretation': interpretation,
      'recommendation': recommendation,
    };
  }
}

class AiFeedbackData {
  final String id;
  final String studentId;
  final String courseTitle;
  final String conceptTitle;
  final String badgeLabel;
  final String headline;
  final String summary;
  final int currentRetentionPercent;
  final int declinePercent;
  final int recoveryRetentionPercent;
  final String retentionDescription;
  final List<RetentionCurvePoint> curve;
  final List<ExplanationFactor> factors;
  final String guidanceTitle;
  final String guidanceBody;
  final List<ReportMetricRow> reportRows;
  final DateTime generatedAt;

  const AiFeedbackData({
    required this.id,
    required this.studentId,
    required this.courseTitle,
    required this.conceptTitle,
    required this.badgeLabel,
    required this.headline,
    required this.summary,
    required this.currentRetentionPercent,
    required this.declinePercent,
    required this.recoveryRetentionPercent,
    required this.retentionDescription,
    required this.curve,
    required this.factors,
    required this.guidanceTitle,
    required this.guidanceBody,
    required this.reportRows,
    required this.generatedAt,
  });

  RetentionCurvePoint get currentPoint {
    return curve.firstWhere(
      (point) => point.isCurrent,
      orElse: () => curve[curve.length ~/ 2],
    );
  }

  factory AiFeedbackData.fromJson(Map<String, dynamic> json) {
    return AiFeedbackData(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      courseTitle: json['courseTitle'] as String,
      conceptTitle: json['conceptTitle'] as String,
      badgeLabel: json['badgeLabel'] as String,
      headline: json['headline'] as String,
      summary: json['summary'] as String,
      currentRetentionPercent: json['currentRetentionPercent'] as int,
      declinePercent: json['declinePercent'] as int,
      recoveryRetentionPercent: json['recoveryRetentionPercent'] as int,
      retentionDescription: json['retentionDescription'] as String,
      curve: (json['curve'] as List<dynamic>)
          .map(
            (item) =>
                RetentionCurvePoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      factors: (json['factors'] as List<dynamic>)
          .map(
            (item) => ExplanationFactor.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      guidanceTitle: json['guidanceTitle'] as String,
      guidanceBody: json['guidanceBody'] as String,
      reportRows: (json['reportRows'] as List<dynamic>)
          .map((item) => ReportMetricRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'courseTitle': courseTitle,
      'conceptTitle': conceptTitle,
      'badgeLabel': badgeLabel,
      'headline': headline,
      'summary': summary,
      'currentRetentionPercent': currentRetentionPercent,
      'declinePercent': declinePercent,
      'recoveryRetentionPercent': recoveryRetentionPercent,
      'retentionDescription': retentionDescription,
      'curve': curve.map((item) => item.toJson()).toList(),
      'factors': factors.map((item) => item.toJson()).toList(),
      'guidanceTitle': guidanceTitle,
      'guidanceBody': guidanceBody,
      'reportRows': reportRows.map((item) => item.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class FeedbackReport {
  final String title;
  final String generatedFor;
  final DateTime generatedAt;
  final List<ReportMetricRow> rows;

  const FeedbackReport({
    required this.title,
    required this.generatedFor,
    required this.generatedAt,
    required this.rows,
  });

  String asMarkdownTable() {
    final buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln('Student: $generatedFor')
      ..writeln('Generated: ${generatedAt.toIso8601String()}')
      ..writeln()
      ..writeln('| Metric | Value | Interpretation | Recommendation |')
      ..writeln('| --- | --- | --- | --- |');

    for (final row in rows) {
      buffer.writeln(
        '| ${_escape(row.metric)} | ${_escape(row.value)} | ${_escape(row.interpretation)} | ${_escape(row.recommendation)} |',
      );
    }

    return buffer.toString();
  }

  static String _escape(String value) {
    return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
  }
}

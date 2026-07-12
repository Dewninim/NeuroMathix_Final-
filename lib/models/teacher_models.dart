import 'package:flutter/material.dart';

enum TeacherNavSection { dashboard, settings }

enum StudentRiskLevel { urgent, reviewSoon, safe }




extension StudentRiskLevelLabel on StudentRiskLevel {
  String get label {
    switch (this) {
      case StudentRiskLevel.urgent:
        return 'Urgent';
      case StudentRiskLevel.reviewSoon:
        return 'Review Soon';
      case StudentRiskLevel.safe:
        return 'Safe';
    }
  }

  Color get chipColor {
    switch (this) {
      case StudentRiskLevel.urgent:
        return const Color(0xFFFF6B6B);
      case StudentRiskLevel.reviewSoon:
        return const Color(0xFFFFD166);
      case StudentRiskLevel.safe:
        return const Color(0xFF7AE582);
    }
  }
}

class TeacherStudentRow {
  final String id;
  final String name;
  final String lastActiveLabel;
  final String focusTitle;
  final StudentRiskLevel riskLevel;

  const TeacherStudentRow({
    required this.id,
    required this.name,
    required this.lastActiveLabel,
    required this.focusTitle,
    required this.riskLevel,
  });
}
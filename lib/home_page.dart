import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/student_learning_models.dart';
import 'pages/explainable_ai_feedback_page.dart';
import 'pages/student_dashboard_page.dart';
import 'providers/auth_provider.dart';
import 'review_schedule.dart';
import 'widgets/student_app_shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentAppShell(
      activeSection: StudentNavSection.home,
      userName: 'Kawya',
      notificationCount: 3,
      onSectionSelected: (section) => _openSection(context, section),
      child: const SectionPlaceholder(
        title: 'Role-based dashboard pending',
        message:
            'Once student and teacher roles are connected, this landing area can redirect to the correct dashboard. For now, use the sidebar dashboard icon to open the student dashboard prototype.',
      ),
    );
  }

  static void _openSection(BuildContext context, StudentNavSection section) {
    if (section == StudentNavSection.dashboard) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
      );
      return;
    }

    if (section == StudentNavSection.aiFeedback) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExplainableAiFeedbackPage()),
      );
      return;
    }

    if (section == StudentNavSection.schedule) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReviewSchedulePage()),
      );
      return;
    }

    if (section == StudentNavSection.settings) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await auth.logout();
            },
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This section is not wired yet.')),
    );
  }
}

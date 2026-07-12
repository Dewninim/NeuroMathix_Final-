import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../widgets/overlay_dropdown.dart';
import '../widgets/teacher_app_shell.dart';
import 'teacher_message_dialog.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  TeacherNavSection _active = TeacherNavSection.dashboard;

  String _query = '';
  StudentRiskLevel? _riskFilter;

  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName?.split(' ').first ??
        user?.email?.split('@').first ??
        'Teacher';
  }

  final List<TeacherStudentRow> _students = const [
    TeacherStudentRow(
      id: 's1',
      name: 'Harry',
      lastActiveLabel: '2 days ago',
      focusTitle: 'Matrix Theory',
      riskLevel: StudentRiskLevel.urgent,
    ),
    TeacherStudentRow(
      id: 's2',
      name: 'Velma',
      lastActiveLabel: '5 days ago',
      focusTitle: 'Calculus',
      riskLevel: StudentRiskLevel.safe,
    ),
    TeacherStudentRow(
      id: 's3',
      name: 'Defni',
      lastActiveLabel: '8 days ago',
      focusTitle: 'Calculus',
      riskLevel: StudentRiskLevel.reviewSoon,
    ),
    TeacherStudentRow(
      id: 's4',
      name: 'Ron',
      lastActiveLabel: '2 days ago',
      focusTitle: 'Calculus',
      riskLevel: StudentRiskLevel.reviewSoon,
    ),
    TeacherStudentRow(
      id: 's5',
      name: 'Emma',
      lastActiveLabel: '2 days ago',
      focusTitle: 'Matrix Theory',
      riskLevel: StudentRiskLevel.safe,
    ),
    TeacherStudentRow(
      id: 's6',
      name: 'Jack',
      lastActiveLabel: '9 days ago',
      focusTitle: 'Linear Algebra',
      riskLevel: StudentRiskLevel.urgent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TeacherAppShell(
      activeSection: _active,
      userName: _displayName,
      notificationCount: 0,
      onSectionSelected: (section) => setState(() => _active = section),
      child: _active == TeacherNavSection.settings
          ? const _SettingsPlaceholder()
          : _dashboardBody(),
    );
  }

  Widget _dashboardBody() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isMobile = w < 760;

        final filtered = _students.where((s) {
          final q = _query.trim().toLowerCase();

          if (q.isNotEmpty &&
              !s.name.toLowerCase().contains(q) &&
              !s.id.toLowerCase().contains(q)) {
            return false;
          }

          if (_riskFilter != null && s.riskLevel != _riskFilter) {
            return false;
          }

          return true;
        }).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 14 : 28,
            isMobile ? 16 : 24,
            isMobile ? 14 : 28,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Teacher Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: neuromathixText,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _metricCards(maxWidth: w),

                  const SizedBox(height: 16),

                  _WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Students',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: neuromathixText,
                          ),
                        ),

                        const SizedBox(height: 12),

                        _filtersRow(maxWidth: w),

                        const SizedBox(height: 12),

                        for (final s in filtered) ...[
                          _StudentRow(
                            student: s,
                            onMessage: () => _openMessageDialog(s),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /* ---------------- METRICS (CLEAN + BALANCED) ---------------- */

Widget _metricCards({required double maxWidth}) {
  final isMobile = maxWidth < 760;

  final urgent = _students
      .where((s) => s.riskLevel == StudentRiskLevel.urgent)
      .length;

  final cards = [
    _MetricCard(
      icon: Icons.warning_amber_rounded,
      value: '$urgent',
      label: 'Urgent Risk',
      accentColor: Colors.redAccent,
    ),
    _MetricCard(
      icon: Icons.groups_rounded,
      value: '${_students.length}',
      label: 'Total Students',
      accentColor: neuromathixBlue,
    ),
  ];

  if (isMobile) {
    return Column(
      children: cards
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(width: double.infinity, child: c),
              ))
          .toList(),
    );
  }

  return Row(
    children: [
      Expanded(child: cards[0]),
      const SizedBox(width: 12),
      Expanded(child: cards[1]),
    ],
  );
}

  /* ---------------- FILTER ROW (ONLY SEARCH + RISK) ---------------- */

 Widget _filtersRow({required double maxWidth}) {
  final isMobile = maxWidth < 900;

  final search = _PillTextField(
    hintText: 'Search student...',
    value: _query,
    onChanged: (v) => setState(() => _query = v),
  );

  final risk = _LabeledControl(
    label: 'Risk Level',
    child: OverlayDropdown<StudentRiskLevel?>(
      items: const [null, ...StudentRiskLevel.values],
      selected: _riskFilter,
      label: (v) => v == null ? 'All' : v.label,
      onChanged: (v) => setState(() => _riskFilter = v),
      child: _PillSelect(
        label: _riskFilter == null ? 'All' : _riskFilter!.label,
      ),
    ),
  );

  if (isMobile) {
    return Column(
      children: [
        search,
        const SizedBox(height: 10),
        risk,
      ],
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        flex: 2,
        child: search,
      ),
      const SizedBox(width: 14),
      SizedBox(
        width: 260,
        child: risk,
      ),
    ],
  );
}

  Future<void> _openMessageDialog(TeacherStudentRow s) async {
    await showDialog(
      context: context,
      builder: (_) => TeacherMessageDialog(studentName: s.name),
    );
  }
}

/* ================= METRIC CARD ================= */
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 72, // instead of fixed height
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: accentColor),
          const SizedBox(width: 10),

          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor.withOpacity(0.9),
                    height: 1.1,
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


/* ================= STUDENT ROW ================= */

class _StudentRow extends StatelessWidget {
  final TeacherStudentRow student;
  final VoidCallback onMessage;

  const _StudentRow({
    required this.student,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neuromathixBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  student.lastActiveLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: neuromathixMuted,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Text(
              student.focusTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          _RiskChip(level: student.riskLevel),

          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            onPressed: onMessage,
          ),
        ],
      ),
    );
  }
}

/* ================= RISK CHIP ================= */

class _RiskChip extends StatelessWidget {
  final StudentRiskLevel level;

  const _RiskChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: level.chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: level.chipColor),
      ),
      child: Text(
        level.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ================= SHARED ================= */

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neuromathixBorder),
      ),
      child: child,
    );
  }
}

/* ================= PLACEHOLDER ================= */

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings (not implemented yet)'));
  }
}

/* ================= CONTROLS ================= */

class _LabeledControl extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledControl({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: neuromathixText,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PillTextField extends StatelessWidget {
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;

  const _PillTextField({
    required this.hintText,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 11,
            color: neuromathixMuted,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: neuromathixBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: neuromathixBlue, width: 2),
          ),
        ),
      ),
    );
  }
}

class _PillSelect extends StatelessWidget {
  final String label;

  const _PillSelect({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: neuromathixBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: neuromathixText,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: neuromathixBlue),
        ],
      ),
    );
  }
}

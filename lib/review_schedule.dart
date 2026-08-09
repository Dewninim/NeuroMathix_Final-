import 'package:flutter/material.dart';
import 'models/student_learning_models.dart';
import 'pages/explainable_ai_feedback_page.dart';
import 'pages/student_dashboard_page.dart';
import 'widgets/student_app_shell.dart';

class ReviewSchedulePage extends StatefulWidget {
  const ReviewSchedulePage({super.key});

  @override
  State<ReviewSchedulePage> createState() => _ReviewSchedulePageState();
}

class _ReviewSchedulePageState extends State<ReviewSchedulePage> {
  DateTime visibleMonth = DateTime(2026, 2, 1);
  DateTime selectedDay = DateTime(2026, 2, 11);

  bool isMonthView = true;

  // Fake sample data to match the UI
  final int urgentModules = 2;
  final int thisWeekCount = 6;
  final Duration plannedTime = const Duration(minutes: 45);
  final int streakDays = 7;

  final List<_Topic> topics = const [
    _Topic(name: 'Matrix Theory', duration: Duration(minutes: 45), priority: _Priority.urgent),
    _Topic(name: 'Calculus', duration: Duration(minutes: 35), priority: _Priority.reviewSoon),
    _Topic(name: 'Linear Algebra', duration: Duration(minutes: 40), priority: _Priority.safe),
  ];

  _PriorityFilter filter = _PriorityFilter.all;

  @override
  Widget build(BuildContext context) {
    return StudentAppShell(
      activeSection: StudentNavSection.schedule,
      userName: 'Kawya',
      notificationCount: 3,
      onSectionSelected: (section) {
        if (section == StudentNavSection.dashboard) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardPage()));
        } else if (section == StudentNavSection.aiFeedback) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExplainableAiFeedbackPage()));
        } else if (section == StudentNavSection.schedule) {
          // Do nothing
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Section not wired yet.')),
          );
        }
      },
      child: Container(
        color: const Color(0xFFF5F6FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeader(),
              const SizedBox(height: 12),
              _StatsRow(
                urgentModules: urgentModules,
                thisWeekCount: thisWeekCount,
                plannedTime: plannedTime,
                streakDays: streakDays,
              ),
              const SizedBox(height: 14),
              _CalendarCard(
                visibleMonth: visibleMonth,
                selectedDay: selectedDay,
                isMonthView: isMonthView,
                onToggleView: (v) => setState(() => isMonthView = v),
                onPrevMonth: () => setState(() {
                  visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1, 1);
                }),
                onNextMonth: () => setState(() {
                  visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 1);
                }),
                onSelectDay: (d) => setState(() => selectedDay = d),
                markedDays: const {
                  11,
                },
                onBackToToday: () => setState(() {
                  visibleMonth = DateTime.now();
                  selectedDay = DateTime.now();
                }),
              ),
              const SizedBox(height: 14),
              _SelectedDaySummaryCard(
                sessions: 3,
                planned: const Duration(hours: 2, minutes: 35),
                mainFocus: 'Matrix Theory',
                completion: 0.33,
              ),
              const SizedBox(height: 14),
              _TopicsCard(
                topics: topics.where((t) => _matchesFilter(t.priority, filter)).toList(),
                filter: filter,
                onFilterChanged: (f) => setState(() => filter = f),
              ),
              const SizedBox(height: 14),
              _ScheduleTableCard(
                rows: const [
                  _ScheduleRow(
                    subject: 'Matrix Theory',
                    startTime: TimeOfDay(hour: 18, minute: 0),
                    endTimeLabel: 'Ends 18:45',
                  ),
                  _ScheduleRow(
                    subject: 'Calculus',
                    startTime: TimeOfDay(hour: 19, minute: 0),
                    endTimeLabel: 'Ends 19:35',
                  ),
                  _ScheduleRow(
                    subject: 'Linear Algebra',
                    startTime: TimeOfDay(hour: 20, minute: 0),
                    endTimeLabel: 'Ends 20:40',
                  ),
                ],
                onAutoArrange: () {},
                onSave: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _matchesFilter(_Priority p, _PriorityFilter f) {
  switch (f) {
    case _PriorityFilter.all:
      return true;
    case _PriorityFilter.urgent:
      return p == _Priority.urgent;
    case _PriorityFilter.reviewSoon:
      return p == _Priority.reviewSoon;
    case _PriorityFilter.safe:
      return p == _Priority.safe;
  }
}

/* --------------------------- UI building blocks -------------------------- */



class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 2),
        Text(
          'View your review schedule with subjects, dates, and time blocks',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int urgentModules;
  final int thisWeekCount;
  final Duration plannedTime;
  final int streakDays;

  const _StatsRow({
    required this.urgentModules,
    required this.thisWeekCount,
    required this.plannedTime,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 900;
        final children = [
          _StatCard(
            icon: Icons.assignment_late_outlined,
            title: '$urgentModules',
            subtitle: 'Urgent modules',
          ),
          _StatCard(
            icon: Icons.calendar_today_outlined,
            title: '$thisWeekCount',
            subtitle: 'This week',
          ),
          _StatCard(
            icon: Icons.timer_outlined,
            title: '${plannedTime.inMinutes}m',
            subtitle: 'Planned time',
          ),
          _StatCard(
            icon: Icons.bolt_outlined,
            title: '$streakDays days',
            subtitle: 'Streak',
          ),
        ];

        if (!isNarrow) {
          return Row(
            children: children
                .map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: w)))
                .toList()
              ..removeLast(),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children.map((w) => SizedBox(width: (c.maxWidth - 10) / 2, child: w)).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final bool isMonthView;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<DateTime> onSelectDay;
  final Set<int> markedDays;
  final VoidCallback onBackToToday;

  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDay,
    required this.isMonthView,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToggleView,
    required this.onSelectDay,
    required this.markedDays,
    required this.onBackToToday,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Calendar',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Month view', style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(width: 10),
          _Segmented(
            left: 'Month',
            right: 'Week',
            isLeftSelected: isMonthView,
            onChanged: (isLeft) => onToggleView(isLeft),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onPrevMonth, icon: const Icon(Icons.chevron_left_rounded)),
              Text(
                _formatMonthYear(visibleMonth),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(onPressed: onNextMonth, icon: const Icon(Icons.chevron_right_rounded)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          _CalendarGrid(
            month: visibleMonth,
            selected: selectedDay,
            markedDays: markedDays,
            onSelect: onSelectDay,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _LegendDot(label: 'Revisions Scheduled Dates'),
              const Spacer(),
              ElevatedButton(
                onPressed: onBackToToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF153E7C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Back to Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          )
        ],
      ),
    );
  }

  static String _formatMonthYear(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final Set<int> markedDays;
  final ValueChanged<DateTime> onSelect;

  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.markedDays,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Make Sunday=0 like the UI labels
    final startOffset = first.weekday % 7;

    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        Row(
          children: labels
              .map((t) => Expanded(
                    child: Center(
                      child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final dayNum = index - startOffset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(month.year, month.month, dayNum);
            final isSelected = _sameDay(date, selected);

            return InkWell(
              onTap: () => onSelect(date),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF153E7C) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6E9F2)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (markedDays.contains(dayNum))
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        )
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LegendDot extends StatelessWidget {
  final String label;
  const _LegendDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }
}

class _SelectedDaySummaryCard extends StatelessWidget {
  final int sessions;
  final Duration planned;
  final String mainFocus;
  final double completion;

  const _SelectedDaySummaryCard({
    required this.sessions,
    required this.planned,
    required this.mainFocus,
    required this.completion,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Selected Day Summary',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  bg: const Color(0xFFCFFFD1),
                  title: 'Sessions',
                  value: '$sessions Sessions',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  bg: const Color(0xFFDFF5FF),
                  title: 'Planned time',
                  value: '${planned.inHours}h ${planned.inMinutes.remainder(60)}m',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  bg: const Color(0xFFFFD8D8),
                  title: 'Main focus',
                  value: mainFocus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Completion', style: TextStyle(fontSize: 11, color: Colors.black54)),
              const Spacer(),
              Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 6,
              backgroundColor: const Color(0xFFE9EDF6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF153E7C)),
            ),
          )
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final Color bg;
  final String title;
  final String value;

  const _InfoPill({required this.bg, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TopicsCard extends StatelessWidget {
  final List<_Topic> topics;
  final _PriorityFilter filter;
  final ValueChanged<_PriorityFilter> onFilterChanged;

  const _TopicsCard({
    required this.topics,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Topics for Selected Day',
      subtitle: 'Filter topics by priority',
      trailing: Text(
        'Showing ${topics.length} topics • 2h/2h  •  All',
        style: const TextStyle(fontSize: 10.5, color: Colors.black45),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter == _PriorityFilter.all,
                onTap: () => onFilterChanged(_PriorityFilter.all),
                color: const Color(0xFF153E7C),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Urgent',
                selected: filter == _PriorityFilter.urgent,
                onTap: () => onFilterChanged(_PriorityFilter.urgent),
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Review soon',
                selected: filter == _PriorityFilter.reviewSoon,
                onTap: () => onFilterChanged(_PriorityFilter.reviewSoon),
                color: const Color(0xFFFFD166),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Safe',
                selected: filter == _PriorityFilter.safe,
                onTap: () => onFilterChanged(_PriorityFilter.safe),
                color: const Color(0xFF7AE582),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...topics.map((t) => _TopicRow(topic: t)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF153E7C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFF153E7C) : const Color(0xFFE6E9F2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final _Topic topic;
  const _TopicRow({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9F2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          Text(
            '${topic.duration.inMinutes}m',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 11),
          )
        ],
      ),
    );
  }
}

class _ScheduleTableCard extends StatelessWidget {
  final List<_ScheduleRow> rows;
  final VoidCallback onAutoArrange;
  final VoidCallback onSave;

  const _ScheduleTableCard({
    required this.rows,
    required this.onAutoArrange,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Schedule time per subject',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              children: [
                Text('Tip:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Set your hardest module for your best focus time. Consistency beats intensity.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the start time for each subject. End time is calculated automatically. Use the bell to set a reminder',
            style: TextStyle(fontSize: 10.5, color: Colors.black45),
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => _ScheduleRowWidget(row: r)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: onAutoArrange,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: const BorderSide(color: Color(0xFFE6E9F2)),
                ),
                child: const Text('Auto Arrange', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF153E7C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Save Time Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '• Auto Arrange gives no overlap time  • After all save time plan',
              style: TextStyle(fontSize: 10, color: Colors.black45),
            ),
          )
        ],
      ),
    );
  }
}

class _ScheduleRowWidget extends StatelessWidget {
  final _ScheduleRow row;
  const _ScheduleRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final startLabel = '${two(row.startTime.hour)} : ${two(row.startTime.minute)}';

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9F2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(row.subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Text('Start time', style: TextStyle(fontSize: 10.5, color: Colors.black45)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E9F2)),
                  ),
                  child: Text(startLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.access_time_rounded, size: 18, color: Colors.black54),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(row.endTimeLabel, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _CardShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ),
                ],
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeftSelected;
  final ValueChanged<bool> onChanged;

  const _Segmented({
    required this.left,
    required this.right,
    required this.isLeftSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E9F2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(true),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isLeftSelected ? const Color(0xFF153E7C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  left,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isLeftSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(false),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isLeftSelected ? const Color(0xFF153E7C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: !isLeftSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------- Models -------------------------------- */

enum _Priority { urgent, reviewSoon, safe }

enum _PriorityFilter { all, urgent, reviewSoon, safe }

class _Topic {
  final String name;
  final Duration duration;
  final _Priority priority;
  const _Topic({required this.name, required this.duration, required this.priority});
}

class _ScheduleRow {
  final String subject;
  final TimeOfDay startTime;
  final String endTimeLabel;

  const _ScheduleRow({
    required this.subject,
    required this.startTime,
    required this.endTimeLabel,
  });
}
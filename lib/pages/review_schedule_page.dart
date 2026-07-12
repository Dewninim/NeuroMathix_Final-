import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ReviewSchedulePage extends StatefulWidget {
  const ReviewSchedulePage({super.key});

  @override
  State<ReviewSchedulePage> createState() => _ReviewSchedulePageState();
}

class _ReviewSchedulePageState extends State<ReviewSchedulePage> {
  // Figma shows Feb 2026 examples; keep initial like design.
  DateTime _focusedDay = DateTime(2026, 2, 1);
  DateTime _selectedDay = DateTime(2026, 2, 11);
  CalendarFormat _format = CalendarFormat.month;

  // Sample dashboard stats (top cards)
  final int urgentModules = 2;
  final int thisWeekCount = 6;
  final Duration plannedTimeWeek = const Duration(minutes: 45);
  final int streakDays = 7;

  // Day -> topics
  late final Map<DateTime, List<_Topic>> _topicsByDay = {
    _d(2026, 2, 11): const [
      _Topic(name: 'Linear Algebra', duration: Duration(minutes: 30), priority: _Priority.safe),
      _Topic(name: 'Integration', duration: Duration(minutes: 35), priority: _Priority.urgent),
    ],
    _d(2026, 2, 7): const [
      _Topic(name: 'Matrix Theory', duration: Duration(minutes: 45), priority: _Priority.urgent),
      _Topic(name: 'Calculus', duration: Duration(minutes: 35), priority: _Priority.reviewSoon),
      _Topic(name: 'Linear Algebra', duration: Duration(minutes: 40), priority: _Priority.safe),
    ],
  };

  // Markers (red dot) for revision days
  late final Map<DateTime, List<String>> _events = {
    _d(2026, 2, 7): const ['Revision'],
    _d(2026, 2, 11): const ['Revision'],
  };

  _PriorityFilter _filter = _PriorityFilter.all;

  // Schedule rows for selected day (in real app: load per day)
  late List<_ScheduleRowState> _scheduleRows = [
    _ScheduleRowState(
      subject: 'Linear Algebra',
      startTime: const TimeOfDay(hour: 18, minute: 0),
      duration: const Duration(minutes: 30),
      reminder: _Reminder.off,
    ),
    _ScheduleRowState(
      subject: 'Integration',
      startTime: const TimeOfDay(hour: 19, minute: 0),
      duration: const Duration(minutes: 35),
      reminder: _Reminder.off,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageHeader(),
            const SizedBox(height: 12),
            _StatsRow(
              urgentModules: urgentModules,
              thisWeekCount: thisWeekCount,
              plannedTime: plannedTimeWeek,
              streakDays: streakDays,
            ),
            const SizedBox(height: 14),
            _calendarCard(),
            const SizedBox(height: 14),
            _selectedDaySummaryCard(),
            const SizedBox(height: 14),
            _topicsCard(),
            const SizedBox(height: 14),
            _scheduleTableCard(),
          ],
        ),
      ),
    );
  }

  /* ------------------------------ Calendar card ------------------------------ */

  Widget _calendarCard() {
    List<String> getEvents(DateTime d) => _events[_dateOnly(d)] ?? const [];

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
            isLeftSelected: _format == CalendarFormat.month,
            onChanged: (isMonth) {
              setState(() => _format = isMonth ? CalendarFormat.month : CalendarFormat.week);
            },
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  });
                },
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E9F2)),
                ),
                child: Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              _CircleIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  });
                },
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar<String>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            headerVisible: false,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: getEvents,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = _dateOnly(selected);
                _focusedDay = focused;
                _filter = _PriorityFilter.all;

                // (Demo) if day has different topics, swap schedule rows too
                _loadScheduleForSelectedDay();
              });
            },
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
            },
            daysOfWeekHeight: 24,
            rowHeight: 46,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              defaultDecoration: BoxDecoration(color: Colors.transparent),
              weekendDecoration: BoxDecoration(color: Colors.transparent),
              todayDecoration: BoxDecoration(color: Colors.transparent),
              selectedDecoration: BoxDecoration(color: Colors.transparent),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                return _DayCell(day: day, isSelected: false, hasMarker: getEvents(day).isNotEmpty);
              },
              selectedBuilder: (context, day, _) {
                return _DayCell(day: day, isSelected: true, hasMarker: getEvents(day).isNotEmpty);
              },
              todayBuilder: (context, day, _) {
                return _DayCell(
                  day: day,
                  isSelected: isSameDay(_selectedDay, day),
                  hasMarker: getEvents(day).isNotEmpty,
                );
              },
              markerBuilder: (context, day, events) => null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _LegendDot(label: 'Revisions Scheduled Dates'),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _focusedDay = _dateOnly(DateTime.now());
                    _selectedDay = _dateOnly(DateTime.now());
                    _filter = _PriorityFilter.all;
                    _loadScheduleForSelectedDay();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF153E7C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Back to Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _loadScheduleForSelectedDay() {
    // Demo-only: change schedule rows based on selected day like your screenshots.
    final d = _dateOnly(_selectedDay);

    if (d == _d(2026, 2, 7)) {
      _scheduleRows = [
        _ScheduleRowState(
          subject: 'Matrix Theory',
          startTime: const TimeOfDay(hour: 18, minute: 0),
          duration: const Duration(minutes: 45),
          reminder: _Reminder.off,
        ),
        _ScheduleRowState(
          subject: 'Calculus',
          startTime: const TimeOfDay(hour: 19, minute: 0),
          duration: const Duration(minutes: 35),
          reminder: _Reminder.off,
        ),
        _ScheduleRowState(
          subject: 'Linear Algebra',
          startTime: const TimeOfDay(hour: 20, minute: 0),
          duration: const Duration(minutes: 40),
          reminder: _Reminder.off,
        ),
      ];
    } else {
      _scheduleRows = [
        _ScheduleRowState(
          subject: 'Linear Algebra',
          startTime: const TimeOfDay(hour: 18, minute: 0),
          duration: const Duration(minutes: 30),
          reminder: _Reminder.off,
        ),
        _ScheduleRowState(
          subject: 'Integration',
          startTime: const TimeOfDay(hour: 19, minute: 0),
          duration: const Duration(minutes: 35),
          reminder: _Reminder.off,
        ),
      ];
    }
  }

  /* -------------------------- Selected Day Summary -------------------------- */

  Widget _selectedDaySummaryCard() {
    final topicsForDay = _topicsByDay[_dateOnly(_selectedDay)] ?? const <_Topic>[];
    final sessions = topicsForDay.length;
    final planned = topicsForDay.fold<Duration>(Duration.zero, (sum, t) => sum + t.duration);
    final mainFocus = topicsForDay.isEmpty ? '-' : topicsForDay.last.name; // demo
    final completion = 0.0; // screenshots show 0% sometimes

    return _CardShell(
      title: 'Selected Day Summary',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _InfoPill(bg: const Color(0xFFCFFFD1), title: 'Sessions', value: '$sessions Sessions')),
              const SizedBox(width: 10),
              Expanded(child: _InfoPill(bg: const Color(0xFFDFF5FF), title: 'Planned time', value: _fmtDuration(planned))),
              const SizedBox(width: 10),
              Expanded(child: _InfoPill(bg: const Color(0xFFFFD8D8), title: 'Main focus', value: mainFocus)),
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
          ),
        ],
      ),
    );
  }

  /* -------------------------------- Topics -------------------------------- */

  Widget _topicsCard() {
    final all = _topicsByDay[_dateOnly(_selectedDay)] ?? const <_Topic>[];
    final filtered = all.where((t) => _matchesFilter(t.priority, _filter)).toList();

    final filteredSum = filtered.fold<Duration>(Duration.zero, (sum, t) => sum + t.duration);
    final allSum = all.fold<Duration>(Duration.zero, (sum, t) => sum + t.duration);

    return _CardShell(
      title: 'Topics for Selected Day',
      subtitle: 'Filter topics by priority',
      trailing: Text(
        'Showing ${filtered.length}/${all.length} topics • ${_fmtMinutes(filteredSum)} / ${_fmtDuration(allSum)} • ${_filterLabel(_filter)}',
        style: const TextStyle(fontSize: 10.5, color: Colors.black45),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _FilterChip(label: 'All', selected: _filter == _PriorityFilter.all, onTap: () => setState(() => _filter = _PriorityFilter.all)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Urgent', selected: _filter == _PriorityFilter.urgent, onTap: () => setState(() => _filter = _PriorityFilter.urgent)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Review soon', selected: _filter == _PriorityFilter.reviewSoon, onTap: () => setState(() => _filter = _PriorityFilter.reviewSoon)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Safe', selected: _filter == _PriorityFilter.safe, onTap: () => setState(() => _filter = _PriorityFilter.safe)),
            ],
          ),
          const SizedBox(height: 10),
          for (final t in filtered) _TopicRow(topic: t),
        ],
      ),
    );
  }

  /* ----------------------------- Schedule table ----------------------------- */

  Widget _scheduleTableCard() {
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
          for (int i = 0; i < _scheduleRows.length; i++)
            _ScheduleRowWidget(
              row: _scheduleRows[i],
              onChangeTime: (t) => setState(() => _scheduleRows[i] = _scheduleRows[i].copyWith(startTime: t)),
              onChangeReminder: (r) => setState(() => _scheduleRows[i] = _scheduleRows[i].copyWith(reminder: r)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: _autoArrange,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: const BorderSide(color: Color(0xFFE6E9F2)),
                ),
                child: const Text('Auto Arrange', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {},
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
              '• Auto Arrange gives  non overlap time  • After all save time plan',
              style: TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  void _autoArrange() {
    // Demo: keep first start time, then stack sequentially by duration.
    if (_scheduleRows.isEmpty) return;

    final sorted = [..._scheduleRows];
    sorted.sort((a, b) => a.startTime.hour != b.startTime.hour
        ? a.startTime.hour.compareTo(b.startTime.hour)
        : a.startTime.minute.compareTo(b.startTime.minute));

    final first = sorted.first.startTime;
    var cursor = _toDateTime(_selectedDay, first);

    final arranged = <_ScheduleRowState>[];
    for (final row in sorted) {
      final start = TimeOfDay(hour: cursor.hour, minute: cursor.minute);
      arranged.add(row.copyWith(startTime: start));
      cursor = cursor.add(row.duration);
    }

    setState(() => _scheduleRows = arranged);
  }

  /* ------------------------------- Helpers -------------------------------- */

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _d(int y, int m, int day) => DateTime(y, m, day);

  static DateTime _toDateTime(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  static bool _matchesFilter(_Priority p, _PriorityFilter f) {
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

  static String _filterLabel(_PriorityFilter f) {
    switch (f) {
      case _PriorityFilter.all:
        return 'All';
      case _PriorityFilter.urgent:
        return 'Urgent';
      case _PriorityFilter.reviewSoon:
        return 'Review soon';
      case _PriorityFilter.safe:
        return 'Safe';
    }
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0) return '${d.inMinutes}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
    // Figma shows "1h 5m"
  }

  static String _fmtMinutes(Duration d) => '${d.inMinutes}min';
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
          _StatCard(icon: Icons.assignment_late_outlined, title: '$urgentModules', subtitle: 'Urgent modules'),
          _StatCard(icon: Icons.calendar_today_outlined, title: '$thisWeekCount', subtitle: 'This week'),
          _StatCard(icon: Icons.timer_outlined, title: '${plannedTime.inMinutes}m', subtitle: 'Planned time'),
          _StatCard(icon: Icons.bolt_outlined, title: '$streakDays days', subtitle: 'Streak'),
        ];

        if (!isNarrow) {
          return Row(
            children: children
                .asMap()
                .entries
                .map((e) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: e.key == children.length - 1 ? 0 : 10),
                        child: e.value,
                      ),
                    ))
                .toList(),
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

  const _StatCard({required this.icon, required this.title, required this.subtitle});

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
              if (trailing != null) trailing!,
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6E9F2)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool hasMarker;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.hasMarker,
  });

  @override
  Widget build(BuildContext context) {
    // Selected in Figma looks dark-blue filled; unselected is white with border.
    final bg = isSelected ? const Color(0xFF153E7C) : Colors.white;
    final border = const Color(0xFFE6E9F2);
    final textColor = isSelected ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: textColor),
            ),
          ),
          if (hasMarker)
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
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  const _LegendDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black87),
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
          Expanded(child: Text(topic.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
          Text('${topic.duration.inMinutes}m', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}

/* ---------------------- Schedule row: time + reminder --------------------- */

class _ScheduleRowWidget extends StatelessWidget {
  final _ScheduleRowState row;
  final ValueChanged<TimeOfDay> onChangeTime;
  final ValueChanged<_Reminder> onChangeReminder;

  const _ScheduleRowWidget({
    required this.row,
    required this.onChangeTime,
    required this.onChangeReminder,
  });

  @override
  Widget build(BuildContext context) {
    final end = _addDuration(row.startTime, row.duration);
    final endLabel = 'Ends ${_fmtTime(end)}';

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
                _TimeDropdownButton(
                  value: row.startTime,
                  onChanged: onChangeTime,
                ),
                const SizedBox(width: 10),
                const Icon(Icons.access_time_rounded, size: 18, color: Colors.black54),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(endLabel, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
          _ReminderMenuButton(
            value: row.reminder,
            onChanged: onChangeReminder,
          ),
        ],
      ),
    );
  }

  static TimeOfDay _addDuration(TimeOfDay start, Duration d) {
    final dt = DateTime(2026, 1, 1, start.hour, start.minute).add(d);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  static String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimeDropdownButton extends StatelessWidget {
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimeDropdownButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = '${value.hour.toString().padLeft(2, '0')} : ${value.minute.toString().padLeft(2, '0')}';

    return PopupMenuButton<TimeOfDay>(
      tooltip: 'Select start time',
      offset: const Offset(0, 38),
      onSelected: onChanged,
      itemBuilder: (context) {
        // Figma shows hour+minute picker; simulate with prebuilt times.
        final items = <PopupMenuEntry<TimeOfDay>>[];
        for (int h = 18; h <= 23; h++) {
          for (final m in const [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]) {
            final t = TimeOfDay(hour: h % 24, minute: m);
            items.add(
              PopupMenuItem(
                value: t,
                child: Text('${t.hour.toString().padLeft(2, '0')} : ${t.minute.toString().padLeft(2, '0')}'),
              ),
            );
          }
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6E9F2)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
      ),
    );
  }
}

class _ReminderMenuButton extends StatelessWidget {
  final _Reminder value;
  final ValueChanged<_Reminder> onChanged;

  const _ReminderMenuButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Reminder>(
      tooltip: 'Reminder',
      offset: const Offset(0, 38),
      onSelected: onChanged,
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _Reminder.off,
            child: _ReminderMenuRow(title: 'Off', subtitle: 'No reminder', selected: true),
          ),
          PopupMenuItem(
            value: _Reminder.min30,
            child: _ReminderMenuRow(title: '30 minutes', subtitle: 'Before start'),
          ),
          PopupMenuItem(
            value: _Reminder.hour1,
            child: _ReminderMenuRow(title: '1 hour', subtitle: 'Before start'),
          ),
        ];
      },
      child: const Icon(Icons.notifications_none_rounded),
    );
  }
}

class _ReminderMenuRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;

  const _ReminderMenuRow({
    required this.title,
    required this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }
}

/* -------------------------------- Models -------------------------------- */

enum _Priority { urgent, reviewSoon, safe }
enum _PriorityFilter { all, urgent, reviewSoon, safe }

class _Topic {
  final String name;
  final Duration duration;
  final _Priority priority;
  const _Topic({required this.name, required this.duration, required this.priority});
}

enum _Reminder { off, min30, hour1 }

class _ScheduleRowState {
  final String subject;
  final TimeOfDay startTime;
  final Duration duration;
  final _Reminder reminder;

  const _ScheduleRowState({
    required this.subject,
    required this.startTime,
    required this.duration,
    required this.reminder,
  });

  _ScheduleRowState copyWith({
    TimeOfDay? startTime,
    Duration? duration,
    _Reminder? reminder,
  }) {
    return _ScheduleRowState(
      subject: subject,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      reminder: reminder ?? this.reminder,
    );
  }
}
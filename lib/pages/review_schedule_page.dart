import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/review_schedule_models.dart';
import '../services/review_schedule_service.dart';
import 'learning_session_screen.dart';

class ReviewSchedulePage extends StatefulWidget {
  const ReviewSchedulePage({super.key});

  @override
  State<ReviewSchedulePage> createState() => _ReviewSchedulePageState();
}

class _ReviewSchedulePageState extends State<ReviewSchedulePage> {
  final ReviewScheduleService _service = ReviewScheduleService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;
  ReviewPriority? _priorityFilter;

  String get _studentId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_studentId.isEmpty) {
      return const Center(child: Text('Please sign in to view your review schedule.'));
    }

    return StreamBuilder<List<ReviewSchedule>>(
      stream: _service.watchStudentSchedules(_studentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data!;
        final selected = schedules.where((item) {
          return isSameDay(item.scheduledAt, _selectedDay) &&
              (_priorityFilter == null || item.priority == _priorityFilter);
        }).toList();

        return Container(
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Schedule',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Personalized review dates generated from your learning sessions and forgetting curve.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    _buildStats(schedules),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 900;
                        final calendar = _CalendarCard(
                          schedules: schedules,
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          format: _format,
                          onFormatChanged: (value) => setState(() => _format = value),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (day) => setState(() => _focusedDay = day),
                        );
                        final list = _SelectedDayCard(
                          selectedDay: _selectedDay,
                          schedules: selected,
                          filter: _priorityFilter,
                          onFilterChanged: (value) =>
                              setState(() => _priorityFilter = value),
                          onEdit: _editSchedule,
                          onStart: _startReview,
                          onComplete: _markCompleted,
                          onSnooze: _snooze,
                        );

                        if (narrow) {
                          return Column(
                            children: [calendar, const SizedBox(height: 16), list],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: calendar),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: list),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _UpcomingReviewsCard(
                      schedules: schedules,
                      onEdit: _editSchedule,
                      onStart: _startReview,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats(List<ReviewSchedule> schedules) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final urgent = schedules.where((item) {
      return item.priority == ReviewPriority.urgent &&
          item.status != ReviewStatus.completed &&
          item.status != ReviewStatus.cancelled;
    }).length;
    final dueWeek = schedules.where((item) {
      return item.scheduledAt.isAfter(now.subtract(const Duration(minutes: 1))) &&
          item.scheduledAt.isBefore(weekEnd) &&
          item.status != ReviewStatus.completed &&
          item.status != ReviewStatus.cancelled;
    }).length;
    final minutes = schedules
        .where((item) =>
            item.scheduledAt.isAfter(now) &&
            item.scheduledAt.isBefore(weekEnd) &&
            item.status != ReviewStatus.cancelled)
        .fold<int>(0, (sum, item) => sum + item.durationMinutes);
    final completed = schedules
        .where((item) => item.status == ReviewStatus.completed)
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.warning_amber_rounded,
          value: '$urgent',
          label: 'Urgent reviews',
          color: const Color(0xFFDC2626),
        ),
        _StatCard(
          icon: Icons.calendar_month_rounded,
          value: '$dueWeek',
          label: 'Next 7 days',
          color: const Color(0xFF2563EB),
        ),
        _StatCard(
          icon: Icons.timer_outlined,
          value: '${minutes}m',
          label: 'Planned time',
          color: const Color(0xFF7C3AED),
        ),
        _StatCard(
          icon: Icons.task_alt_rounded,
          value: '$completed',
          label: 'Completed',
          color: const Color(0xFF059669),
        ),
      ],
    );
  }

  Future<void> _editSchedule(ReviewSchedule schedule) async {
    final result = await showDialog<_ScheduleEditResult>(
      context: context,
      builder: (_) => _ScheduleEditDialog(schedule: schedule),
    );
    if (result == null) return;

    try {
      await _service.saveTimePlan(
        scheduleId: schedule.id,
        scheduledAt: result.scheduledAt,
        durationMinutes: result.durationMinutes,
        reminderAt: result.reminderAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review time plan saved.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _startReview(ReviewSchedule schedule) async {
    if (!schedule.canStart) {
      final difference = schedule.timeUntilReview;
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This review becomes available in ${hours}h ${minutes}m.'),
        ),
      );
      return;
    }
    if (schedule.materialId == null || schedule.materialId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This manual review has no uploaded material attached.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningSessionScreen(
          materialId: schedule.materialId!,
          studyMode: 'review',
          studyDays: 7,
          fileName: schedule.conceptName,
          sourceReviewScheduleId: schedule.id,
        ),
      ),
    );
  }

  Future<void> _markCompleted(ReviewSchedule schedule) async {
    try {
      await _service.markCompleted(schedule.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _snooze(ReviewSchedule schedule) async {
    try {
      await _service.snooze(schedule.id, const Duration(hours: 6));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review moved forward by 6 hours.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final List<ReviewSchedule> schedules;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat format;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const _CalendarCard({
    required this.schedules,
    required this.focusedDay,
    required this.selectedDay,
    required this.format,
    required this.onFormatChanged,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  List<ReviewSchedule> _eventsFor(DateTime day) {
    return schedules.where((item) => isSameDay(item.scheduledAt, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Calendar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              SegmentedButton<CalendarFormat>(
                segments: const [
                  ButtonSegment(value: CalendarFormat.month, label: Text('Month')),
                  ButtonSegment(value: CalendarFormat.week, label: Text('Week')),
                ],
                selected: {format},
                onSelectionChanged: (value) => onFormatChanged(value.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar<ReviewSchedule>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focusedDay,
            calendarFormat: format,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            eventLoader: _eventsFor,
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF153E7C),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  final DateTime selectedDay;
  final List<ReviewSchedule> schedules;
  final ReviewPriority? filter;
  final ValueChanged<ReviewPriority?> onFilterChanged;
  final ValueChanged<ReviewSchedule> onEdit;
  final ValueChanged<ReviewSchedule> onStart;
  final ValueChanged<ReviewSchedule> onComplete;
  final ValueChanged<ReviewSchedule> onSnooze;

  const _SelectedDayCard({
    required this.selectedDay,
    required this.schedules,
    required this.filter,
    required this.onFilterChanged,
    required this.onEdit,
    required this.onStart,
    required this.onComplete,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(selectedDay),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: filter == null,
                onSelected: (_) => onFilterChanged(null),
              ),
              for (final priority in ReviewPriority.values)
                ChoiceChip(
                  label: Text(priority.label),
                  selected: filter == priority,
                  onSelected: (_) => onFilterChanged(priority),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (schedules.isEmpty)
            const _EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No reviews for this day',
              subtitle: 'Select another date or complete a learning session.',
            )
          else
            for (final schedule in schedules) ...[
              _ReviewTile(
                schedule: schedule,
                onEdit: () => onEdit(schedule),
                onStart: () => onStart(schedule),
                onComplete: () => onComplete(schedule),
                onSnooze: () => onSnooze(schedule),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _UpcomingReviewsCard extends StatelessWidget {
  final List<ReviewSchedule> schedules;
  final ValueChanged<ReviewSchedule> onEdit;
  final ValueChanged<ReviewSchedule> onStart;

  const _UpcomingReviewsCard({
    required this.schedules,
    required this.onEdit,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final active = schedules.where((item) {
      return item.status != ReviewStatus.completed &&
          item.status != ReviewStatus.cancelled;
    }).take(8).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming and overdue reviews',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            const _EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No active reviews',
              subtitle: 'Your next schedule will appear after a session.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Topic')),
                  DataColumn(label: Text('Date and time')),
                  DataColumn(label: Text('Mastery')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: active.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.conceptName)),
                      DataCell(Text(DateFormat('dd MMM, h:mm a').format(item.scheduledAt))),
                      DataCell(Text('${item.masteryScore.round()}%')),
                      DataCell(_PriorityBadge(priority: item.priority)),
                      DataCell(Text(item.isOverdue ? 'Overdue' : item.status.label)),
                      DataCell(
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => onEdit(item),
                              child: const Text('Edit'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => onStart(item),
                              child: const Text('Start'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  const _ReviewTile({
    required this.schedule,
    required this.onEdit,
    required this.onStart,
    required this.onComplete,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schedule.conceptName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _PriorityBadge(priority: schedule.priority),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${DateFormat('h:mm a').format(schedule.scheduledAt)} • ${schedule.durationMinutes} minutes • Mastery ${schedule.masteryScore.round()}%',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          if (schedule.reason.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              schedule.reason,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('Change time'),
              ),
              if (schedule.canStart)
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start review'),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_clock_rounded, size: 18),
                  label: const Text('Not available yet'),
                ),
              if (schedule.isOverdue)
                TextButton(
                  onPressed: onSnooze,
                  child: const Text('Remind in 6 hours'),
                ),
              if (schedule.status != ReviewStatus.completed)
                TextButton(
                  onPressed: onComplete,
                  child: const Text('Mark completed'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditDialog extends StatefulWidget {
  final ReviewSchedule schedule;
  const _ScheduleEditDialog({required this.schedule});

  @override
  State<_ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<_ScheduleEditDialog> {
  late DateTime _date = widget.schedule.scheduledAt;
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.schedule.scheduledAt);
  late int _duration = widget.schedule.durationMinutes;
  int _reminderMinutes = 120;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Schedule ${widget.schedule.conceptName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Review date'),
              subtitle: Text(DateFormat('dd MMMM yyyy').format(_date)),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Start time'),
              subtitle: Text(_time.format(context)),
              onTap: _pickTime,
            ),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: const [20, 30, 45, 60]
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value minutes'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _duration = value ?? 30),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutes,
              decoration: const InputDecoration(labelText: 'Reminder'),
              items: const [30, 60, 120, 360, 1440]
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_reminderLabel(value)),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _reminderMinutes = value ?? 120),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final scheduledAt = DateTime(
              _date.year,
              _date.month,
              _date.day,
              _time.hour,
              _time.minute,
            );
            Navigator.pop(
              context,
              _ScheduleEditResult(
                scheduledAt: scheduledAt,
                durationMinutes: _duration,
                reminderAt:
                    scheduledAt.subtract(Duration(minutes: _reminderMinutes)),
              ),
            );
          },
          child: const Text('Save time plan'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  static String _reminderLabel(int minutes) {
    if (minutes == 1440) return '1 day before';
    if (minutes >= 60) return '${minutes ~/ 60} hours before';
    return '$minutes minutes before';
  }
}

class _ScheduleEditResult {
  final DateTime scheduledAt;
  final int durationMinutes;
  final DateTime reminderAt;

  const _ScheduleEditResult({
    required this.scheduledAt,
    required this.durationMinutes,
    required this.reminderAt,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: _Card(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final ReviewPriority priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      ReviewPriority.urgent => const Color(0xFFDC2626),
      ReviewPriority.reviewSoon => const Color(0xFFD97706),
      ReviewPriority.safe => const Color(0xFF059669),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load review schedules.\n$message'),
      ),
    );
  }
}

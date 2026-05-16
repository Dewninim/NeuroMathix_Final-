import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_learning_models.dart';
import '../review_schedule.dart';
import '../services/student_learning_service.dart';
import '../widgets/student_app_shell.dart';
import 'explainable_ai_feedback_page.dart';

class StudentDashboardPage extends StatefulWidget {
  final String studentId;
  final StudentLearningService? service;

  const StudentDashboardPage({
    super.key,
    this.studentId = 'student-demo-kawya',
    this.service,
  });

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  late final StudentLearningService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FirestoreStudentLearningService();
    // Temporarily seeding data right at startup to make sure collections exist
    if (widget.service == null) {
      final firestoreService = _service as FirestoreStudentLearningService;
      firestoreService.seedMockData(widget.studentId).catchError((e) => debugPrint("Seed error: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentDashboardData>(
      future: _service.getDashboard(widget.studentId),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return StudentAppShell(
          activeSection: StudentNavSection.dashboard,
          userName: data?.displayName ?? 'Kawya',
          notificationCount: data?.notificationCount ?? 0,
          onSectionSelected: (section) =>
              _openSection(context, section, _service),
          child: data == null
              ? const Center(child: CircularProgressIndicator())
              : _DashboardContent(data: data, service: _service),
        );
      },
    );
  }

  static void _openSection(
    BuildContext context,
    StudentNavSection section,
    StudentLearningService service,
  ) {
    if (section == StudentNavSection.dashboard) {
      return;
    }

    if (section == StudentNavSection.aiFeedback) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExplainableAiFeedbackPage(service: service),
        ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_sectionLabel(section)} is not wired yet.')),
    );
  }

  static String _sectionLabel(StudentNavSection section) {
    switch (section) {
      case StudentNavSection.home:
        return 'Home';
      case StudentNavSection.dashboard:
        return 'Dashboard';
      case StudentNavSection.downloads:
        return 'Downloads';
      case StudentNavSection.modules:
        return 'Modules';
      case StudentNavSection.aiFeedback:
        return 'AI Feedback';
      case StudentNavSection.schedule:
        return 'Schedule';
      case StudentNavSection.analytics:
        return 'Analytics';
      case StudentNavSection.settings:
        return 'Settings';
    }
  }
}

class _DashboardContent extends StatelessWidget {
  final StudentDashboardData data;
  final StudentLearningService service;

  const _DashboardContent({required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(streakDays: data.currentStreakDays),
              const SizedBox(height: 26),
              _RetentionOverview(data: data),
              const SizedBox(height: 30),
              const Text(
                'Recommended Now',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: neuromathixText,
                ),
              ),
              const SizedBox(height: 16),
              _RecommendedConceptGrid(
                concepts: data.recommendedConcepts,
                onConceptSelected: (concept) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExplainableAiFeedbackPage(
                        service: service,
                        studentId: data.studentId,
                        feedbackId: concept.feedbackId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              _QuickCheckCard(prompt: data.quickCheck),
              const SizedBox(height: 26),
              _ProgressStats(stats: data.progressStats),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final int streakDays;

  const _DashboardHeader({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;

        return Flex(
          direction: isNarrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isNarrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (isNarrow)
              const _HeaderCopy()
            else
              const Expanded(child: _HeaderCopy()),
            if (isNarrow) const SizedBox(height: 18),
            Column(
              crossAxisAlignment: isNarrow
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(
                    color: neuromathixMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streakDays Days',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: neuromathixText,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: neuromathixText,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Get a glimpse of your learning journey',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: neuromathixText,
          ),
        ),
      ],
    );
  }
}

class _RetentionOverview extends StatelessWidget {
  final StudentDashboardData data;

  const _RetentionOverview({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;

        return _WhiteCard(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RetentionTitle(data: data),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 310,
                      child: _RetentionTrendChart(points: data.retentionTrend),
                    ),
                    const SizedBox(height: 22),
                    _MetricRail(metrics: data.keyMetrics),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RetentionTitle(data: data),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 450,
                            child: _RetentionTrendChart(
                              points: data.retentionTrend,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Container(width: 1, height: 280, color: neuromathixBorder),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 190,
                      child: _MetricRail(metrics: data.keyMetrics),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _RetentionTitle extends StatelessWidget {
  final StudentDashboardData data;

  const _RetentionTitle({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory Retention Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: neuromathixText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Real-time synaptic strength visualization',
                style: TextStyle(
                  fontSize: 15,
                  color: neuromathixMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${data.retentionPercent}%',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: neuromathixText,
              ),
            ),
            Text(
              data.retentionDeltaLabel,
              style: const TextStyle(
                color: Color(0xFF54A86F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricRail extends StatelessWidget {
  final List<DashboardKeyMetric> metrics;

  const _MetricRail({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KEY METRICS',
          style: TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 28),
        for (final metric in metrics) ...[
          _MetricItem(metric: metric),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  final DashboardKeyMetric metric;

  const _MetricItem({required this.metric});

  @override
  Widget build(BuildContext context) {
    final icon = switch (metric.id) {
      'focus' => Icons.psychology_outlined,
      'concepts' => Icons.school_outlined,
      'nextReview' => Icons.schedule_outlined,
      _ => Icons.insights_outlined,
    };
    final color = _toneColor(metric.tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: const TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              metric.value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: neuromathixText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RetentionTrendChart extends StatelessWidget {
  final List<RetentionPoint> points;

  const _RetentionTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RetentionTrendPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _RetentionTrendPainter extends CustomPainter {
  final List<RetentionPoint> points;

  _RetentionTrendPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const labelHeight = 46.0;
    final chartRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - labelHeight,
    );
    final leftPadding = 12.0;
    final rightPadding = 12.0;
    final usableWidth = chartRect.width - leftPadding - rightPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFEFF2F6)
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final y = chartRect.top + chartRect.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointFor(int index) {
      final x = leftPadding + usableWidth * index / (points.length - 1);
      final normalized =
          points[index].retentionPercent.clamp(0, 100).toDouble() / 100;
      final y = chartRect.bottom - (chartRect.height * normalized);
      return Offset(x, y);
    }

    final linePath = Path()..moveTo(pointFor(0).dx, pointFor(0).dy);
    for (var i = 1; i < points.length; i++) {
      final previous = pointFor(i - 1);
      final current = pointFor(i);
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final areaPath = Path.from(linePath)
      ..lineTo(pointFor(points.length - 1).dx, chartRect.bottom)
      ..lineTo(pointFor(0).dx, chartRect.bottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          neuromathixBlue.withValues(alpha: 0.18),
          neuromathixBlue.withValues(alpha: 0.02),
        ],
      ).createShader(chartRect);
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = neuromathixBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = pointFor(i);
      if (points[i].highlighted) {
        final fill = i == points.length - 2 ? neuromathixBlue : Colors.white;
        canvas.drawCircle(point, 18, Paint()..color = fill);
        canvas.drawCircle(
          point,
          18,
          Paint()
            ..color = neuromathixBlue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (var i = 0; i < points.length; i++) {
      if (points[i].label.isEmpty) continue;
      textPainter.text = TextSpan(
        text: points[i].label,
        style: const TextStyle(
          color: neuromathixMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      );
      textPainter.layout();
      final point = pointFor(i);
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, chartRect.bottom + 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RetentionTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RecommendedConceptGrid extends StatelessWidget {
  final List<RecommendedConcept> concepts;
  final ValueChanged<RecommendedConcept> onConceptSelected;

  const _RecommendedConceptGrid({
    required this.concepts,
    required this.onConceptSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 900;

        return Wrap(
          spacing: 26,
          runSpacing: 22,
          children: concepts
              .map(
                (concept) => SizedBox(
                  width: isSingleColumn
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 26) / 2,
                  child: _RecommendedConceptCard(
                    concept: concept,
                    onTap: () => onConceptSelected(concept),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RecommendedConceptCard extends StatelessWidget {
  final RecommendedConcept concept;
  final VoidCallback onTap;

  const _RecommendedConceptCard({required this.concept, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 182,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: _ConceptVisual(
                  style: concept.visualStyle,
                  label: concept.category,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    concept.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: neuromathixText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        concept.visualStyle == ConceptVisualStyle.mathematics
                            ? Icons.history_toggle_off_rounded
                            : Icons.lightbulb_outline_rounded,
                        color:
                            concept.visualStyle ==
                                ConceptVisualStyle.mathematics
                            ? const Color(0xFFFF8A2A)
                            : const Color(0xFF48A96B),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          concept.retentionNote,
                          style: const TextStyle(
                            color: neuromathixMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F2F5),
                        foregroundColor: neuromathixText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: Text(
                        concept.actionLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptVisual extends StatelessWidget {
  final ConceptVisualStyle style;
  final String label;

  const _ConceptVisual({required this.style, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = style == ConceptVisualStyle.mathematics
        ? const [Color(0xFF0D9DC4), Color(0xFF05364F)]
        : const [Color(0xFF9EB68D), Color(0xFF35462F)];

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _ConceptVisualPainter(style)),
        ),
        Positioned(
          left: 22,
          bottom: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConceptVisualPainter extends CustomPainter {
  final ConceptVisualStyle style;

  _ConceptVisualPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: style == ConceptVisualStyle.mathematics ? 0.16 : 0.26,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (style == ConceptVisualStyle.mathematics) {
      for (var i = 0; i < 4; i++) {
        final x = size.width * (0.18 + i * 0.18);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.width * 0.18, size.height),
          paint,
        );
      }
      canvas.drawLine(
        Offset(0, size.height * 0.18),
        Offset(size.width, size.height * 0.18),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.52),
        paint,
      );
      return;
    }

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.65)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.2,
        size.width * 0.42,
        size.height * 0.3,
        size.width * 0.55,
        size.height * 0.1,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.46,
        size.width * 0.88,
        size.height * 0.12,
        size.width * 0.98,
        size.height * 0.32,
      );
    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.2, size.height * 0.1)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.5,
        size.width * 0.58,
        size.height * 0.22,
        size.width * 0.9,
        size.height * 0.78,
      );
    canvas.drawPath(path2, paint);

    for (final point in [
      Offset(size.width * 0.3, size.height * 0.44),
      Offset(size.width * 0.55, size.height * 0.24),
      Offset(size.width * 0.74, size.height * 0.48),
    ]) {
      canvas.drawCircle(
        point,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConceptVisualPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}

class _QuickCheckCard extends StatelessWidget {
  final QuizPrompt prompt;

  const _QuickCheckCard({required this.prompt});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prompt.tag,
                style: const TextStyle(
                  color: neuromathixBlue,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                prompt.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                prompt.subtitle,
                style: const TextStyle(color: neuromathixMuted, fontSize: 15),
              ),
            ],
          );

          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              if (isNarrow) copy else Expanded(child: copy),
              if (isNarrow)
                const SizedBox(height: 18)
              else
                const SizedBox(width: 24),
              SizedBox(
                width: isNarrow ? double.infinity : 190,
                height: 64,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF1FF),
                    foregroundColor: neuromathixBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    prompt.actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressStats extends StatelessWidget {
  final List<ProgressStat> stats;

  const _ProgressStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 760;

        return Wrap(
          spacing: 26,
          runSpacing: 18,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: isSingleColumn
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 52) / 3,
                  child: _ProgressStatCard(stat: stat),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProgressStatCard extends StatelessWidget {
  final ProgressStat stat;

  const _ProgressStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(stat.tone);
    final icon = switch (stat.id) {
      'modules' => Icons.article_outlined,
      'studyTime' => Icons.timer_outlined,
      'mastery' => Icons.star_border_rounded,
      _ => Icons.insights_outlined,
    };

    return _WhiteCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.label,
                style: const TextStyle(
                  color: neuromathixMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                stat.value,
                style: const TextStyle(
                  color: neuromathixText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: neuromathixBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _toneColor(String tone) {
  switch (tone) {
    case 'green':
      return const Color(0xFF4DA86C);
    case 'orange':
      return const Color(0xFFFF8126);
    case 'purple':
      return const Color(0xFF9A42F2);
    case 'blue':
    default:
      return neuromathixBlue;
  }
}

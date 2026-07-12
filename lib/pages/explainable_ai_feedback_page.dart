import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/student_learning_models.dart';
import '../services/student_learning_service.dart';
import '../widgets/student_app_shell.dart';

class ExplainableAiFeedbackPage extends StatelessWidget {
  final String? studentId;
  final String feedbackId;
  final StudentLearningService? service;

  const ExplainableAiFeedbackPage({
    super.key,
    this.studentId,
    this.feedbackId = 'memory-types',
    this.service,
  });

  StudentLearningService get _service =>
      service ?? FirestoreStudentLearningService();

  String get _studentId =>
      studentId ?? FirebaseAuth.instance.currentUser?.uid ?? 'student-demo';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AiFeedbackData>(
      future: _service.getFeedbackForConcept(
        studentId: _studentId,
        feedbackId: feedbackId,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return StudentAppShell(
          activeSection: StudentNavSection.aiFeedback,
          userName: currentAuthUserName(),
          notificationCount: 0,
          onSectionSelected: (section) => _openSection(context, section),
          child: data == null
              ? const Center(child: CircularProgressIndicator())
              : _FeedbackContent(data: data, service: _service),
        );
      },
    );
  }

  static void _openSection(
    BuildContext context,
    StudentNavSection section,
  ) {
    if (section == StudentNavSection.aiFeedback) {
      return;
    }

    Navigator.pushNamed(context, _routeForSection(section));
  }

  static String _routeForSection(StudentNavSection section) {
    switch (section) {
      case StudentNavSection.dashboard:
        return '/student-dashboard';
      case StudentNavSection.uploadMaterial:
        return '/upload';
      case StudentNavSection.aiFeedback:
        return '/ai-feedback';
      case StudentNavSection.reviewSchedule:
        return '/review';
      case StudentNavSection.analytics:
        return '/analytics';
      case StudentNavSection.settings:
        return '/profile';
    }
  }
}

class _FeedbackContent extends StatelessWidget {
  final AiFeedbackData data;
  final StudentLearningService service;

  const _FeedbackContent({required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Breadcrumbs(data: data),
              const SizedBox(height: 24),
              _FeedbackHeader(
                data: data,
                onExport: () => _showReport(context, data),
              ),
              const SizedBox(height: 24),
              _RetentionExplanationCard(data: data),
              const SizedBox(height: 34),
              const Text(
                'Key Factors Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: neuromathixText,
                ),
              ),
              const SizedBox(height: 18),
              _FactorGrid(factors: data.factors),
              const SizedBox(height: 28),
              _GuidanceCard(data: data),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReport(BuildContext context, AiFeedbackData data) async {
    final report = await service.buildFeedbackReport(
      studentId: data.studentId,
      feedbackId: data.id,
    );

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => _ReportDialog(report: report),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  final AiFeedbackData data;

  const _Breadcrumbs({required this.data});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        const Text(
          'Home',
          style: TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '/',
          style: TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          data.courseTitle,
          style: const TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '/',
          style: TextStyle(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          data.conceptTitle,
          style: const TextStyle(
            color: neuromathixText,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FeedbackHeader extends StatelessWidget {
  final AiFeedbackData data;
  final VoidCallback onExport;

  const _FeedbackHeader({required this.data, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;

        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE4EEFF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data.badgeLabel,
                style: const TextStyle(
                  color: neuromathixBlue,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.headline,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: neuromathixText,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                data.summary,
                style: const TextStyle(
                  fontSize: 17,
                  color: neuromathixMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

        return Flex(
          direction: isNarrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isNarrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (isNarrow) copy else Expanded(child: copy),
            if (isNarrow)
              const SizedBox(height: 18)
            else
              const SizedBox(width: 24),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.file_download_outlined, size: 20),
              label: const Text('Export Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: neuromathixText,
                side: const BorderSide(color: neuromathixBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RetentionExplanationCard extends StatelessWidget {
  final AiFeedbackData data;

  const _RetentionExplanationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 960;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _RetentionSummary(data: data),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 360,
                  width: double.infinity,
                  child: _ForgettingCurveChart(data: data),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 470, child: _RetentionSummary(data: data)),
              const SizedBox(width: 30),
              Expanded(
                child: SizedBox(
                  height: 430,
                  child: _ForgettingCurveChart(data: data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RetentionSummary extends StatelessWidget {
  final AiFeedbackData data;

  const _RetentionSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CURRENT RETENTION',
          style: TextStyle(
            color: neuromathixMuted,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              '${data.currentRetentionPercent}%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: neuromathixText,
              ),
            ),
            Text(
              '↓${data.declinePercent}% decline',
              style: const TextStyle(
                color: Color(0xFFFF414D),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          data.retentionDescription,
          style: const TextStyle(
            color: neuromathixMuted,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 210),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD7E4FF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: neuromathixBlue,
                size: 25,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Optimal Review Window',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: neuromathixText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: neuromathixMuted,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Reviewing now will boost your retention back to ',
                          ),
                          TextSpan(
                            text: '${data.recoveryRetentionPercent}%',
                            style: const TextStyle(
                              color: neuromathixBlue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(
                            text: ' with less effort than relearning later.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForgettingCurveChart extends StatelessWidget {
  final AiFeedbackData data;

  const _ForgettingCurveChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ForgettingCurvePainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _ForgettingCurvePainter extends CustomPainter {
  final AiFeedbackData data;

  _ForgettingCurvePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.curve.length < 2) return;

    const bottomLabelHeight = 44.0;
    final chart = Rect.fromLTWH(
      0,
      18,
      size.width,
      size.height - bottomLabelHeight - 18,
    );
    final minDay = data.curve.first.day;
    final maxDay = data.curve.last.day;
    final leftPadding = 16.0;
    final rightPadding = 16.0;
    final usableWidth = chart.width - leftPadding - rightPadding;

    Offset pointFor(RetentionCurvePoint point, double value) {
      final x =
          leftPadding +
          usableWidth * ((point.day - minDay) / (maxDay - minDay));
      final normalized = value.clamp(0, 100).toDouble() / 100;
      final y = chart.bottom - chart.height * normalized;
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFEFF2F6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final idealPath = Path()
      ..moveTo(
        pointFor(data.curve.first, data.curve.first.idealRetention).dx,
        pointFor(data.curve.first, data.curve.first.idealRetention).dy,
      );
    for (var i = 1; i < data.curve.length; i++) {
      final p = pointFor(data.curve[i], data.curve[i].idealRetention);
      idealPath.lineTo(p.dx, p.dy);
    }
    final idealArea = Path.from(idealPath)
      ..lineTo(
        pointFor(data.curve.last, data.curve.last.idealRetention).dx,
        chart.bottom,
      )
      ..lineTo(
        pointFor(data.curve.first, data.curve.first.idealRetention).dx,
        chart.bottom,
      )
      ..close();
    canvas.drawPath(
      idealArea,
      Paint()..color = neuromathixBlue.withValues(alpha: 0.11),
    );

    final predictedPath = Path();
    final first = pointFor(
      data.curve.first,
      data.curve.first.predictedRetention,
    );
    predictedPath.moveTo(first.dx, first.dy);
    for (var i = 1; i < data.curve.length; i++) {
      final previous = pointFor(
        data.curve[i - 1],
        data.curve[i - 1].predictedRetention,
      );
      final current = pointFor(data.curve[i], data.curve[i].predictedRetention);
      final controlX = (previous.dx + current.dx) / 2;
      predictedPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final linePaint = Paint()
      ..color = neuromathixBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(predictedPath, linePaint);

    final currentPoint = data.currentPoint;
    final currentOffset = pointFor(
      currentPoint,
      currentPoint.predictedRetention,
    );
    final dashPaint = Paint()
      ..color = neuromathixBlue.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    _drawDashedLine(
      canvas,
      Offset(currentOffset.dx, chart.top),
      Offset(currentOffset.dx, chart.bottom),
      dashPaint,
    );

    canvas.drawCircle(currentOffset, 18, Paint()..color = Colors.white);
    canvas.drawCircle(
      currentOffset,
      18,
      Paint()
        ..color = neuromathixBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    _drawCallout(canvas, currentOffset, size);
    _drawLegend(canvas, size);
    _drawLabels(canvas, size, chart, pointFor);
  }

  void _drawCallout(Canvas canvas, Offset anchor, Size size) {
    const width = 156.0;
    const height = 58.0;
    final left = (anchor.dx - width / 2)
        .clamp(0, size.width - width)
        .toDouble();
    final top = (anchor.dy - 108)
        .clamp(18, size.height - height - 50)
        .toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = neuromathixBlue);

    final triangle = Path()
      ..moveTo(anchor.dx - 13, top + height)
      ..lineTo(anchor.dx + 13, top + height)
      ..lineTo(anchor.dx, top + height + 17)
      ..close();
    canvas.drawPath(triangle, Paint()..color = neuromathixBlue);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU ARE HERE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(left + (width - textPainter.width) / 2, top + 20),
    );
  }

  void _drawLegend(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final y = 2.0;
    final right = size.width - 8;

    textPainter.text = const TextSpan(
      text: 'Ideal',
      style: TextStyle(
        color: neuromathixMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(right - textPainter.width, y));
    canvas.drawCircle(
      Offset(right - textPainter.width - 10, y + 7),
      4,
      Paint()..color = const Color(0xFFD2D7E0),
    );

    final idealStart = right - textPainter.width - 56;
    textPainter.text = const TextSpan(
      text: 'Predicted',
      style: TextStyle(
        color: neuromathixMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(idealStart - textPainter.width, y));
    canvas.drawCircle(
      Offset(idealStart - textPainter.width - 10, y + 7),
      4,
      Paint()..color = neuromathixBlue,
    );
  }

  void _drawLabels(
    Canvas canvas,
    Size size,
    Rect chart,
    Offset Function(RetentionCurvePoint point, double value) pointFor,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final point in data.curve) {
      final offset = pointFor(point, 0);
      textPainter.text = TextSpan(
        text: point.label,
        style: TextStyle(
          color: point.isCurrent ? neuromathixBlue : neuromathixMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout(maxWidth: 90);
      textPainter.paint(
        canvas,
        Offset(offset.dx - textPainter.width / 2, chart.bottom + 16),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashHeight = 8.0;
    const dashSpace = 8.0;
    var y = start.dy;
    while (y < end.dy) {
      canvas.drawLine(
        Offset(start.dx, y),
        Offset(start.dx, (y + dashHeight).clamp(start.dy, end.dy).toDouble()),
        paint,
      );
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ForgettingCurvePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _FactorGrid extends StatelessWidget {
  final List<ExplanationFactor> factors;

  const _FactorGrid({required this.factors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 780 ? 1 : 3;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 32) / 3;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: factors
              .map(
                (factor) => SizedBox(
                  width: width,
                  child: _FactorCard(factor: factor),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FactorCard extends StatelessWidget {
  final ExplanationFactor factor;

  const _FactorCard({required this.factor});

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(factor.tone);
    final icon = switch (factor.id) {
      'timeLapse' => Icons.schedule_rounded,
      'complexity' => Icons.account_tree_outlined,
      'pastPerformance' => Icons.history_rounded,
      'transfer' => Icons.compare_arrows_rounded,
      _ => Icons.insights_outlined,
    };

    return _WhitePanel(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 22),
            Text(
              factor.title,
              style: const TextStyle(
                color: neuromathixMuted,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              factor.value,
              style: const TextStyle(
                color: neuromathixText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              factor.description,
              style: const TextStyle(
                color: neuromathixMuted,
                fontSize: 15,
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  final AiFeedbackData data;

  const _GuidanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.sentiment_satisfied_alt_rounded,
              color: neuromathixBlue,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.guidanceTitle,
                  style: const TextStyle(
                    color: neuromathixText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  data.guidanceBody,
                  style: const TextStyle(
                    color: neuromathixMuted,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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

class _ReportDialog extends StatelessWidget {
  final FeedbackReport report;

  const _ReportDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(report.title),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generated for ${report.generatedFor}',
                style: const TextStyle(
                  color: neuromathixMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: neuromathixText,
                  ),
                  dataTextStyle: const TextStyle(
                    color: neuromathixMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  columns: const [
                    DataColumn(label: Text('Metric')),
                    DataColumn(label: Text('Value')),
                    DataColumn(label: Text('Interpretation')),
                    DataColumn(label: Text('Recommendation')),
                  ],
                  rows: report.rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row.metric)),
                            DataCell(Text(row.value)),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(row.interpretation),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(row.recommendation),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: neuromathixSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: neuromathixBorder),
                ),
                child: SelectableText(
                  report.asMarkdownTable(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: report.asMarkdownTable()),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report copied to clipboard.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy Report'),
        ),
      ],
    );
  }
}

class _WhitePanel extends StatelessWidget {
  final Widget child;

  const _WhitePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
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
      return const Color(0xFF45B86B);
    case 'orange':
      return const Color(0xFFFF7B22);
    case 'purple':
      return const Color(0xFF9A42F2);
    case 'blue':
    default:
      return neuromathixBlue;
  }
}

// Analytics Page - Tharuka Karunarathne
import 'package:flutter/material.dart';
import '../models/student_learning_models.dart';
import '../widgets/student_app_shell.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentAppShell(
      activeSection: StudentNavSection.analytics,
      userName: currentAuthUserName(),
      notificationCount: 0,
      onSectionSelected: (section) => _openSection(context, section),
      child: const _AnalyticsContent(),
    );
  }

  static void _openSection(BuildContext context, StudentNavSection section) {
    if (section == StudentNavSection.analytics) return;
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

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Progress & Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Track your learning journey and identify areas for improvement',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          const SizedBox(height: 28),

          // ── Stat cards row ──
          Row(
            children: [
              _statCard(Icons.trending_up_rounded, '73%', 'Overall Mastery'),
              const SizedBox(width: 16),
              _statCard(Icons.adjust_rounded, '156', 'Problems Solved'),
              const SizedBox(width: 16),
              _statCard(Icons.access_time_rounded, '23h', 'Study Time'),
              const SizedBox(width: 16),
              _statCard(Icons.calendar_today_rounded, '7', 'Day Streak'),
            ],
          ),
          const SizedBox(height: 24),

          // ── Charts row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line chart card
              Expanded(
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Mastery Progress Over Time',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: CustomPaint(
                          painter: _LineChartPainter(),
                          size: Size.infinite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // X-axis labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(8, (i) {
                          return Text(
                            'Week ${i + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 2,
                            color: const Color(0xFF1F4E95),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Mastery Progress Over Time',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Horizontal bar chart card
              Expanded(
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.adjust_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Topic Mastery Breakdown',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // X-axis labels at top
                      Padding(
                        padding: const EdgeInsets.only(left: 90),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['0', '20', '40', '60', '80', '100']
                              .map(
                                (l) => Text(
                                  l,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                        ('Linear Algebra', 85, const Color(0xFF1a2f5e)),
                        ('Calculus', 72, const Color(0xFF1F4E95)),
                        ('Differential Eq.', 68, const Color(0xFF2E86AB)),
                        ('Statistics', 55, const Color(0xFF3A9BBF)),
                        ('Integration', 45, const Color(0xFF4DB8D4)),
                        ('Matrix Theory', 38, const Color(0xFF6DD4E8)),
                      ].map(
                        (data) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  data.$1,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: data.$2 / 100,
                                      child: Container(
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: data.$3,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${data.$2}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: const Color(0xFF1F4E95),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Topic Mastery Breakdown',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── AI Insights section (mislabeled as "Mastery Progress" in design) ──
          const Text(
            'Mastery Progress Over Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Linear Algebra Improving
              Expanded(
                child: _insightCard(
                  color: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFF86EFAC),
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Linear Algebra Improving',
                  body:
                      'Your mastery increased by 15% this week. Keep practicing eigenvalue problems!',
                ),
              ),
              const SizedBox(width: 16),
              // Matrix Theory Needs Attention
              Expanded(
                child: _insightCard(
                  color: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFFDBA74),
                  icon: Icons.adjust_rounded,
                  iconColor: const Color(0xFFEA580C),
                  title: 'Matrix Theory Needs Attention',
                  body:
                      'Performance declining over the last 3 sessions. Recommend focused review.',
                ),
              ),
              const SizedBox(width: 16),
              // Streak Achievement
              Expanded(
                child: _insightCard(
                  color: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFF86EFAC),
                  icon: Icons.emoji_events_outlined,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Streak Achievement',
                  body:
                      "You've maintained a 7-day study streak! Consistency is key to retention.",
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Detailed Topic Analysis ──
          const Text(
            'Detailed Topic Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ...[
            (
              'Linear Algebra',
              85,
              'Improving',
              const Color(0xFF16A34A),
              const Color(0xFFDCFCE7),
            ),
            (
              'Calculus',
              72,
              'Improving',
              const Color(0xFF16A34A),
              const Color(0xFFDCFCE7),
            ),
            (
              'Differential Eq.',
              68,
              'Stable',
              const Color(0xFF374151),
              const Color(0xFFF3F4F6),
            ),
            (
              'Statistics',
              55,
              'Declining',
              const Color(0xFFDC2626),
              const Color(0xFFFEE2E2),
            ),
            (
              'Integration',
              45,
              'Improving',
              const Color(0xFF16A34A),
              const Color(0xFFDCFCE7),
            ),
            (
              'Matrix Theory',
              38,
              'Declining',
              const Color(0xFFDC2626),
              const Color(0xFFFEE2E2),
            ),
          ].map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: d.$2 / 100,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F4E95),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${d.$2}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: d.$5,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          d.$3,
                          style: TextStyle(
                            color: d.$4,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF6B7280)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _insightCard({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Simple line chart painter ──
class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final data = [35.0, 40.0, 38.0, 48.0, 52.0, 58.0, 65.0, 72.0];
    final maxVal = 100.0;
    final minVal = 0.0;
    final range = maxVal - minVal;

    // Y-axis grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height - (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // Y labels
      final tp = TextPainter(
        text: TextSpan(
          text: '${(i * 25).toInt()}',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-32, y - 6));
    }

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1F4E95).withValues(alpha: 0.25),
            const Color(0xFF1F4E95).withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFF1F4E95)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    for (final p in points) {
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = const Color(0xFF1F4E95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

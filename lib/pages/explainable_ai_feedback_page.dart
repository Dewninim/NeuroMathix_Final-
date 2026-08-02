import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/student_learning_models.dart';
import '../services/student_learning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_app_shell.dart';
import 'learning_session_screen.dart' show QuestionResult, buildRealAiFeedbackData;

class ExplainableAiFeedbackPage extends StatelessWidget {
  final String? studentId;
  final String feedbackId;
  final StudentLearningService? service;
  // When provided (e.g. navigated to from a just-submitted session), this
  // is used directly instead of fetching from the mock
  // FirestoreStudentLearningService — same page, same layout, real content
  // built from that session's actual backend response.
  final AiFeedbackData? initialData;
  // When true (the default when reached from normal navigation, not from
  // a just-submitted session), shows a picker over this student's REAL
  // past sessions instead of jumping straight to one mock concept.
  final bool browseSessions;

  const ExplainableAiFeedbackPage({
    super.key,
    this.studentId,
    this.feedbackId = 'memory-types',
    this.service,
    this.initialData,
    this.browseSessions = true,
  });

  StudentLearningService get _service =>
      service ?? FirestoreStudentLearningService();

  String get _studentId =>
      studentId ?? FirebaseAuth.instance.currentUser?.uid ?? 'student-demo';

  @override
  Widget build(BuildContext context) {
    if (initialData != null) {
      return StudentAppShell(
        activeSection: StudentNavSection.aiFeedback,
        userName: currentAuthUserName(),
        notificationCount: 0,
        onSectionSelected: (section) => _openSection(context, section),
        child: _FeedbackContent(data: initialData!, service: _service),
      );
    }
    if (browseSessions) {
      return StudentAppShell(
        activeSection: StudentNavSection.aiFeedback,
        userName: currentAuthUserName(),
        notificationCount: 0,
        onSectionSelected: (section) => _openSection(context, section),
        child: _SessionHistoryBrowser(studentId: _studentId, service: _service, feedbackId: feedbackId),
      );
    }
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

/// Lists this student's REAL past sessions (from GET /user/<uid>/sessions)
/// and lets them pick one to see its real, session-specific feedback —
/// this is what makes the AI Feedback page update "according to sessions"
/// instead of always showing one static mock concept. Falls back to the
/// mock single-concept view only if the student genuinely has no session
/// history yet (so the page still shows *something* on a first visit).
class _SessionHistoryBrowser extends StatefulWidget {
  final String studentId;
  final StudentLearningService service;
  final String feedbackId;
  const _SessionHistoryBrowser({required this.studentId, required this.service, required this.feedbackId});

  @override
  State<_SessionHistoryBrowser> createState() => _SessionHistoryBrowserState();
}

class _SessionHistoryBrowserState extends State<_SessionHistoryBrowser> {
  late Future<List<Map<String, dynamic>>> _historyFuture;
  String? _selectedSessionId;
  Future<AiFeedbackData>? _selectedFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final r = await http
        .get(Uri.parse('$kApiBaseUrl/user/${widget.studentId}/sessions'))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Could not load session history (${r.statusCode})');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['sessions'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  // Fetches one session's full detail and normalizes it into the same
  // shape buildRealAiFeedbackData already expects (the /submit response
  // shape) — GET /session/<sid> uses slightly different key names
  // ('answers' vs 'results', no top-level correct/total), so this bridges
  // the two instead of duplicating the whole builder function.
  Future<AiFeedbackData> _loadSession(String sessionId) async {
    final r = await http
        .get(Uri.parse('$kApiBaseUrl/session/$sessionId'))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Could not load session (${r.statusCode})');
    final detail = jsonDecode(r.body) as Map<String, dynamic>;
    final answersRaw = (detail['answers'] as List? ?? []).cast<Map<String, dynamic>>();
    final results = answersRaw.map((a) => QuestionResult.fromJson(a)).toList();
    final curve = detail['forgetting_curve'] as Map<String, dynamic>? ?? {};
    final total = results.length;
    final correct = results.where((r) => r.isCorrect).length;
    final normalized = <String, dynamic>{
      'session_id': detail['session_id'],
      'score': detail['score'],
      'correct': correct,
      'total': total,
      'results': answersRaw,
      'forgetting_curve': curve,
      'next_review_days': curve['next_review_days'],
      'next_review_date': curve['next_review_date'],
    };
    return buildRealAiFeedbackData(normalized, results);
  }

  void _select(String sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
      _selectedFuture = _loadSession(sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSessionId != null) {
      return FutureBuilder<AiFeedbackData>(
        future: _selectedFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return _errorState('Could not load that session\'s feedback.', () => setState(() => _selectedSessionId = null));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedSessionId = null),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text('All sessions', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: neuromathixText),
                ),
              ),
              Expanded(child: _FeedbackContent(data: snap.data!, service: widget.service)),
            ],
          );
        },
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snap.data ?? [];
        if (snap.hasError || sessions.isEmpty) {
          // No real history yet — fall back to the mock single-concept view
          // so the page still shows something meaningful on a first visit.
          return FutureBuilder<AiFeedbackData>(
            future: widget.service.getFeedbackForConcept(studentId: widget.studentId, feedbackId: widget.feedbackId),
            builder: (context, mockSnap) {
              if (mockSnap.data == null) return const Center(child: CircularProgressIndicator());
              return _FeedbackContent(data: mockSnap.data!, service: widget.service);
            },
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Your Session Feedback', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w900, color: neuromathixText)),
            const SizedBox(height: 4),
            Text('Pick a past session to see its real, detailed AI feedback.',
                style: GoogleFonts.dmSans(fontSize: 14, color: neuromathixMuted)),
            const SizedBox(height: 20),
            ...sessions.map((s) => _SessionHistoryCard(session: s, onTap: () => _select(s['session_id'] as String))),
          ],
        );
      },
    );
  }

  Widget _errorState(String message, VoidCallback onBack) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: GoogleFonts.dmSans(color: neuromathixMuted)),
          const SizedBox(height: 12),
          TextButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  const _SessionHistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = ((session['score'] as num? ?? 0) * 100).round();
    final filename = ((session['material_filename'] as String? ?? 'Untitled.pdf')).replaceAll('.pdf', '');
    final completedAt = session['completed_at'] as String?;
    String dateLabel = '';
    if (completedAt != null) {
      try {
        final dt = DateTime.parse(completedAt);
        dateLabel = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    final topics = (session['topics'] as List? ?? []).cast<String>();
    final mastered = session['mastery_reached'] as bool? ?? false;
    final scoreColor = score >= 70 ? const Color(0xFF45B86B) : const Color(0xFFFF7B22);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: neuromathixBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Text('$score%', style: GoogleFonts.dmSans(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(filename, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: neuromathixText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (mastered) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.workspace_premium, size: 14, color: Color(0xFFF59E0B)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Session ${session['session_number']} · $dateLabel${topics.isNotEmpty ? ' · ${topics.join(', ')}' : ''}',
                    style: GoogleFonts.dmSans(fontSize: 12, color: neuromathixMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: neuromathixMuted),
          ],
        ),
      ),
    );
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
              Text(
                'Key Factors Analysis',
                style: GoogleFonts.dmSans(
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
        Text(
          'Home',
          style: GoogleFonts.dmSans(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '/',
          style: GoogleFonts.dmSans(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          data.courseTitle,
          style: GoogleFonts.dmSans(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '/',
          style: GoogleFonts.dmSans(
            color: neuromathixMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          data.conceptTitle,
          style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
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
                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
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
        Text(
          'CURRENT RETENTION',
          style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmSans(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: neuromathixText,
              ),
            ),
            Text(
              '↓${data.declinePercent}% decline',
              style: GoogleFonts.dmSans(
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
          style: GoogleFonts.dmSans(
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
                    Text(
                      'Optimal Review Window',
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: neuromathixText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.dmSans(
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
                            style: GoogleFonts.dmSans(
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
      text: TextSpan(
        text: 'YOU ARE HERE',
        style: GoogleFonts.dmSans(
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

    textPainter.text = TextSpan(
      text: 'Ideal',
      style: GoogleFonts.dmSans(
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
    textPainter.text = TextSpan(
      text: 'Predicted',
      style: GoogleFonts.dmSans(
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
        style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmSans(
                color: neuromathixMuted,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              factor.value,
              style: GoogleFonts.dmSans(
                color: neuromathixText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              factor.description,
              style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
                    color: neuromathixText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  data.guidanceBody,
                  style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
                  color: neuromathixMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w900,
                    color: neuromathixText,
                  ),
                  dataTextStyle: GoogleFonts.dmSans(
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
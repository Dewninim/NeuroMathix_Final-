import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/upload_provider.dart';
import '../widgets/upload_card.dart';
import '../widgets/learning_setup_card.dart';
import '../widgets/upload_feature_cards.dart';

const Color _accentBlue  = Color(0xFF1B63E8);
const Color _bgHover     = Color(0xFFDBEAFE);
const Color _borderLight = Color(0xFFBFDBFE);
const Color _textPrimary = Color(0xFF0F172A);
const Color _textSub     = Color(0xFF64748B);
const Color _textMuted   = Color(0xFF94A3B8);

class UploadMaterialPage extends StatelessWidget {
  const UploadMaterialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UploadProvider(),
      child: const _UploadMaterialView(),
    );
  }
}

class _UploadMaterialView extends StatelessWidget {
  const _UploadMaterialView();

  @override
  Widget build(BuildContext context) {
    final isSuccess = context.select<UploadProvider, bool>(
        (p) => p.state.status == UploadStatus.success);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Hero ─────────────────────────────────────────────
                const _HeroBadge(),
                const SizedBox(height: 18),
                const _HeroHeading(),
                const SizedBox(height: 14),
                const _HeroSubtext(),
                const SizedBox(height: 36),

                // ── Upload card / Setup card ──────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOut,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.97, end: 1.0)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: isSuccess
                      ? const LearningSetupCard(
                          key: ValueKey('setup'))
                      : const UploadCard(key: ValueKey('upload')),
                ),

                // ── Feature cards (hide after upload) ────────────────
                if (!isSuccess) ...[
                  const SizedBox(height: 40),
                  const UploadFeatureCards(),
                  const SizedBox(height: 28),
                  Text(
                    '© 2026 NeuroMathix AI Learning. All rights reserved.',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: _textMuted),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: _bgHover.withOpacity(0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _borderLight),
      ),
      child: Text(
        'INTELLIGENCE MEETS EDUCATION',
        style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _accentBlue,
            letterSpacing: 0.8),
      ),
    );
  }
}

class _HeroHeading extends StatelessWidget {
  const _HeroHeading();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.dmSans(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            height: 1.15),
        children: const [
          TextSpan(text: 'Level Up Your '),
          TextSpan(
              text: 'Math\nLearning',
              style: TextStyle(color: _accentBlue)),
        ],
      ),
    );
  }
}

class _HeroSubtext extends StatelessWidget {
  const _HeroSubtext();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Upload your study material and watch AI transform it into a\npersonalized learning experience tailored for your grade.',
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(
          fontSize: 14.5, color: _textSub, height: 1.65),
    );
  }
}

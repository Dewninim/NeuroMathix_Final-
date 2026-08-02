// lib/theme/app_theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// SINGLE SOURCE OF TRUTH for colours and typography across the whole app.
//
// Why this file exists: colours and font sizes were previously defined
// ad-hoc, inline, per-screen — e.g. the nav shell used plain system-font
// TextStyle with navy #10345E / blue #1B63E8, while the learning session
// screen used GoogleFonts.dmSans with a DIFFERENT navy #1B2A4A / blue
// #4F6EAB. Two different brand palettes and two different fonts for the
// same app. AppColors below keeps the ORIGINAL brand values (they were
// already used across 6 files: both nav shells, both dashboards, the XAI
// feedback page, and the overlay dropdown — that's the real, established
// palette) and every other screen should converge onto these, not invent
// new hex values.
//
// Usage:
//   Text('Hello', style: AppText.h2)
//   Container(color: AppColors.primary)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Brand (canonical — matches student_app_shell.dart / teacher_app_shell.dart) ──
  static const Color primary      = Color(0xFF10345E); // "neuromathixNavy"
  static const Color accent       = Color(0xFF1B63E8); // "neuromathixBlue"
  static const Color textDark     = Color(0xFF11131B); // "neuromathixText"
  static const Color textMuted    = Color(0xFF687694); // "neuromathixMuted"
  static const Color border       = Color(0xFFE4E8F0); // "neuromathixBorder"
  static const Color surface      = Color(0xFFF8FAFD); // "neuromathixSurface"

  // ── Semantic (new — previously every screen picked its own shade) ──
  static const Color success      = Color(0xFF16A34A);
  static const Color successBg    = Color(0xFFDCFCE7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningBg    = Color(0xFFFFFBEB);
  static const Color info         = Color(0xFF0EA5E9);
  static const Color infoBg       = Color(0xFFE0F2FE);

  // ── Neutrals ──
  static const Color textFaint    = Color(0xFF9CA3AF);
  static const Color bgPage       = Color(0xFFF3F4F8);
  static const Color bgCard       = Colors.white;
}

/// Named type scale — every screen should reach for one of these instead of
/// writing `GoogleFonts.dmSans(fontSize: 13.5, ...)` inline with a number
/// picked ad-hoc. Two labels that are supposed to look the same size (e.g.
/// two different screens' section headers) now both just say `AppText.h3`.
class AppText {
  AppText._();

  static TextStyle get display => GoogleFonts.dmSans(
      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.2);

  static TextStyle get h1 => GoogleFonts.dmSans(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.25);

  static TextStyle get h2 => GoogleFonts.dmSans(
      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.3);

  static TextStyle get h3 => GoogleFonts.dmSans(
      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.35);

  /// Section eyebrow labels ("QUESTION REVIEW", "YOUR REVIEW SCHEDULE")
  static TextStyle get eyebrow => GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textFaint, letterSpacing: 1);

  static TextStyle get body => GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textDark, height: 1.55);

  static TextStyle get bodyMedium => GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.5);

  static TextStyle get bodySmall => GoogleFonts.dmSans(
      fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.textMuted, height: 1.5);

  static TextStyle get caption => GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textFaint);

  static TextStyle get label => GoogleFonts.dmSans(
      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textFaint, letterSpacing: 0.6);

  static TextStyle get button => GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700);
}

/// Builds the app-wide ThemeData. main.dart should use `AppTheme.light()`
/// instead of its own inline ThemeData(...), so every Material widget that
/// doesn't set an explicit style (buttons, app bars, dialogs, etc.) still
/// inherits the same font family and colour scheme by default.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgPage,
    );
    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        titleTextStyle: AppText.h2,
      ),
    );
  }
}
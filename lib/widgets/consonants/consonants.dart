import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The SafeRide design system.
///
/// Two brand hues carry every primary action; everything else is a neutral.
/// Depth comes from the gradient, never from a third accent hue.
///
/// The legacy names at the bottom are kept deliberately: every screen already
/// imports [Consonants], so re-pointing those aliases at the new palette
/// re-skins the whole app at once instead of leaving half of it on the old
/// cyan while screens are migrated one by one.
class Consonants {
  Consonants._();

  // ── Brand ────────────────────────────────────────────────────────
  /// Gradient start, icon strokes, active nav, outline buttons.
  static const Color indigo = Color(0xFF3E2B8D);

  /// Gradient end, focus ring, active field border, filled dots.
  static const Color violet = Color(0xFFA044FF);

  /// Midpoint of the 3-stop surface gradient only.
  static const Color indigoMid = Color(0xFF5B3BB8);

  /// Illustration halos, tinted icon circles.
  static const Color indigoWash = Color(0xFFECEAFA);

  // ── Neutrals ─────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color chipBg = Color(0xFFE4E6F0);
  static const Color border = Color(0xFFD9D9E3);
  static const Color divider = Color(0xFFEDEDED);
  static const Color textMuted = Color(0xFF757575);
  static const Color headingInk = Color(0xFF1E2157);
  static const Color bodyInk = Color(0xFF1A1A1A);

  /// Icon stroke colour on light surfaces.
  static const Color iconInk = Color(0xFF2B2260);

  // ── Semantic ─────────────────────────────────────────────────────
  /// Money in. Nothing else on a screen may be green.
  static const Color credit = Color(0xFF1DBF73);

  /// Money out, destructive actions.
  static const Color danger = Color(0xFFD23B3B);
  static const Color scrim = Color(0x731A1437);

  /// Washes behind semantic icons — tints, never fills.
  static const Color creditWash = Color(0xFFE6F8F0);
  static const Color dangerWash = Color(0xFFFCECEC);

  // ── Gradients ────────────────────────────────────────────────────
  /// Primary buttons, CTA pills, primary icon tiles.
  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment(-0.98, -0.17), // ≈100deg
    end: Alignment(0.98, 0.17),
    colors: [indigo, violet],
  );

  /// Balance containers, hero panels. One per screen — two competing
  /// gradients on one screen is a bug.
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment(-0.82, -0.57), // ≈125deg
    end: Alignment(0.82, 0.57),
    colors: [indigo, indigoMid, violet],
    stops: [0.0, 0.45, 1.0],
  );

  /// Stacked over [surfaceGradient] to give the panel its sheen.
  static const LinearGradient sheenOverlay = LinearGradient(
    begin: Alignment(-0.9, -0.42), // ≈115deg
    end: Alignment(0.9, 0.42),
    colors: [Color(0x29FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.38, 0.60],
  );

  // ── Elevation ────────────────────────────────────────────────────
  /// White cards on the canvas are separated by this violet-tinted lift,
  /// never by a border.
  static const List<BoxShadow> cardLift = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1FA044FF), blurRadius: 30, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> sheetLift = [
    BoxShadow(color: Color(0x402B2260), blurRadius: 40, offset: Offset(0, -12)),
  ];

  // ── Radii ────────────────────────────────────────────────────────
  static const double rButton = 22;
  static const double rSheet = 22;
  static const double rHero = 20;
  static const double rCard = 16;
  static const double rInput = 16;
  static const double rPill = 1000;

  // ── Spacing ──────────────────────────────────────────────────────
  /// Horizontal gutter on every in-app screen (onboarding uses 28).
  static const double gutter = 24;
  static const double gutterOnboarding = 28;

  /// Bottom padding so the floating nav never covers scrolled content.
  static const double navClearance = 96;

  static const double gapButtons = 16;
  static const double gapFields = 18;
  static const double gapTiles = 14;
  static const double rowVertical = 15;

  // ── Legacy aliases ───────────────────────────────────────────────
  // Screens still reference these; they now resolve to the new system so
  // nothing is left on the old cyan palette mid-migration.
  static const Color primaryColor = indigo;
  static const Color scaffoldBackgroundColor = canvas;
  static const Color boldTextColor = headingInk;
  static const Color whiteColor = surface;
  static const Color greyColor = textMuted;
  static const Color lightGreyColor = divider;
  static const Color primaryGreenColor = creditWash;
  static const Color lightBlueColor = indigoWash;

  static const String fontFamily = 'Inter';
}

/// The type scale.
///
/// Fraunces (700) is reserved for onboarding and identity moments — before
/// the user is signed in. Everything inside the app is Inter.
class AppText {
  AppText._();

  // ── Fraunces · display only, never below 28 ──────────────────────
  static TextStyle display({Color color = Consonants.headingInk}) =>
      GoogleFonts.fraunces(
        fontSize: 42,
        height: 1.12,
        letterSpacing: -0.42,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle displayS({Color color = Consonants.headingInk}) =>
      GoogleFonts.fraunces(
        fontSize: 38,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle displayXs({Color color = Consonants.headingInk}) =>
      GoogleFonts.fraunces(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: color,
      );

  // ── Inter · everything in-app ────────────────────────────────────
  static TextStyle screenTitle({Color color = Consonants.headingInk}) =>
      GoogleFonts.inter(
        fontSize: 28,
        letterSpacing: -0.56,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Money is the largest thing on the screen it belongs to.
  static TextStyle figure({Color color = Consonants.headingInk}) =>
      GoogleFonts.inter(
        fontSize: 38,
        height: 1.1,
        letterSpacing: -0.76,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle sectionHeading({Color color = Consonants.headingInk}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle amount({Color color = Consonants.bodyInk}) =>
      GoogleFonts.inter(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle rowLabel({Color color = Consonants.bodyInk}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle paragraph({Color color = Consonants.textMuted}) =>
      GoogleFonts.inter(
        fontSize: 16.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle caption({Color color = Consonants.textMuted}) =>
      GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle navLabel({Color color = Consonants.textMuted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle button({Color color = Consonants.surface}) =>
      GoogleFonts.inter(
        fontSize: 17.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

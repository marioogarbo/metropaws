import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brand-fixed colours (never change between modes) ──────────────────────
class AppColors {
  static const navy = Color(0xFF263258);
  static const gold = Color(0xFFB89A3E);
  static const white = Color(0xFFFFFFFF);

  // Light mode semantic
  static const surface = Color(0xFFF8F7F4);
  static const text = Color(0xFF1A1E32);
  static const navyLight = Color(0xFFEEF0F8);
  static const goldLight = Color(0xFFFBF6E9);
  static const grey = Color(0xFF8B8FA8);
  static const greyText = Color(0xFF5C6080);
  static const greyLight = Color(0xFFE8EAF2);

  // Semantic status tokens
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFEF2F2);
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFF0FDF4);

  // Extended tokens (not in colorScheme — use directly)
  static const goldDark = Color(
    0xFF7A6020,
  ); // small text on gold surfaces (5.5:1 on goldLight)
  static const successDark = Color(
    0xFF14532D,
  ); // small text on light green/gold (8.5:1 on goldLight)

  // ── On-navy ramp ─────────────────────────────────────────────────────────
  // Navy is a real SURFACE now (app bar, Home header, nav capsule), not just a
  // fill behind white text, so it needs its own text ramp. `grey` was the
  // reflex pick for muted-on-navy and it only reaches 3.96:1 — fine for a
  // 25px icon, a fail for the 10sp nav label sitting under it.
  static const onNavyMuted = Color(0xFFBFC5DC); // 4.6:1 on navy — muted LABELS
  static const onNavyDivider = Color(0x1FFFFFFF); // hairlines inside navy

  // CORRECTION (measured): `gold` on `navy` is 4.60:1, not the 2.9:1 this note
  // used to claim — it clears AA for normal text. The figure that IS a fail is
  // `gold` on WHITE (2.72:1) and on `surface` (2.54:1), which is where small
  // gold text actually breaks; use `goldDark` (6.0:1 on white) there.
  //
  // Gold staying off navy is now a HIERARCHY decision, not a contrast one: gold
  // belongs to the Premium tier card (see [tierStyleFor]), so navy surfaces use
  // white for emphasis, `onNavyMuted` (4.6:1) for muted labels, and a solid
  // gold fill with `text` on top (6.1:1) when something must be gold.
}

// ── Dark mode palette ──────────────────────────────────────────────────────
class AppDarkColors {
  static const bg = Color(0xFF0D1220);
  static const surface = Color(0xFF161C2E);
  static const elevated = Color(0xFF1F2740);
  static const border = Color(0xFF2C3452);
  static const text = Color(0xFFEEF0FB);
  static const subtext = Color(0xFF8890B4);
  static const goldBg = Color(0xFF261E08);
  static const errorBg = Color(0xFF2D0808);
  static const successBg = Color(0xFF052E16);
}

// ── Membership tier visual tokens ──────────────────────────────────────────
// Three tiers, three MATERIALS — not three text colours on one card.
//
// Before this, De Luxe and Premium shared a single surface (0xFF111219) and
// differed only in ink hue, so the two top tiers measured 1.00:1 apart and were
// indistinguishable while swiping the Home carousel. PRODUCT.md principle 4
// ("Never flatten tiers to the same visual treatment") exists to stop exactly
// that. The prestige order was inverted too: Premium (₱9,999, the top tier per
// scripts/seed.py) wore cool silver while De Luxe (₱5,999) got the brand gold,
// so the brand's most valuable colour marked the second-best plan.
//
// The ramp now follows the physical membership kit AND the convention every
// member already reads off their own wallet — light card → metal card → black
// card:
//
//   rank 1  Standard  linen         white → warm wash        matte gold accent
//   rank 2  De Luxe   brushed navy  brand navy gradient      pale steel / white
//   rank 3  Premium   obsidian      near-black, navy-tinted  gold foil
//
// SURFACE carries the hierarchy; the accent is the second, quieter signal, and
// the tier NAME on the badge is the third — a non-chromatic cue, so tier never
// rests on colour alone (principle 7).
//
// Every pair below is measured, and measured against BOTH gradient ends:
// checking only the lit top passes pairs that fail at the foot of the card.
// Comment ratios are WCAG 2.1 contrast.
//
// Gold is Premium's alone now. Spending a gold fill on all three tiers made the
// top tier's own signal ordinary, and left De Luxe with a gold CTA fighting a
// gold balance figure two rows above it.
class TierStyle {
  /// Gradient start (card top). Also the flat fill for consumers that paint no
  /// gradient.
  final Color cardSurface;

  /// Gradient end (card foot) — the material: one card, lit from above.
  final Color cardSurfaceEnd;

  /// Primary ink.
  final Color primaryText;

  /// Secondary ink — pool labels, breed line, "left of ₱X".
  ///
  /// A real colour, not `white.withValues(alpha: 0.55)`. An alpha ink over a
  /// gradient drifts in contrast down the card, and the old 0.55 white measured
  /// 5.5:1 at the top of 0xFF111219 and less at its foot.
  final Color mutedText;

  /// The one colour on this card that means "this is yours" — the wallet
  /// balance, and nothing else. At most two accent elements per card.
  final Color accent;

  final Color borderColor;
  final Color dividerColor;

  /// The unfilled part of a wallet meter.
  final Color meterTrack;

  /// Contrast-safe error ink for THIS surface. Plain `error` (#DC2626) is
  /// 2.6:1 on the navy De Luxe card, so the dark tiers take a lighter red.
  final Color warning;

  /// Primary CTA ("Show Digital Pawprint") — a tier signal in its own right.
  final Color ctaFill;
  final Color ctaLabel;

  final Color badgeBg;
  final Color badgeText;
  final Color badgeBorder;

  /// Contact + ambient shadow. Replaces the old single spread-2 glow, which
  /// ringed the dark cards in a coloured halo and gave the white Standard card
  /// no shadow at all — against the 0xFFF8F7F4 scaffold that is 1.07:1 of
  /// separation, i.e. none, so the entry tier's card had no edge to it.
  final List<BoxShadow> shadow;

  /// 1..3 — the tier's rung on the ladder, for anything that needs to convey
  /// rank without relying on colour.
  final int rank;

  const TierStyle({
    required this.cardSurface,
    required this.cardSurfaceEnd,
    required this.primaryText,
    required this.mutedText,
    required this.accent,
    required this.borderColor,
    required this.dividerColor,
    required this.meterTrack,
    required this.warning,
    required this.ctaFill,
    required this.ctaLabel,
    required this.badgeBg,
    required this.badgeText,
    required this.badgeBorder,
    required this.shadow,
    required this.rank,
  });

  /// The card's surface as a top-to-bottom gradient, so the two ends stay
  /// defined in one place.
  LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardSurface, cardSurfaceEnd],
  );

  /// True when this tier paints ink on a dark surface.
  bool get isDarkSurface => rank > 1;
}

// ── Tier shadows ───────────────────────────────────────────────────────────
// Two layers, always: a tight contact shadow that sits the card ON the page,
// and a wide ambient one that gives it height. One blurred shadow alone reads
// as a glow; one tight shadow alone reads as a second border.
const _standardShadow = [
  BoxShadow(color: Color(0x0F1A1E32), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x141A1E32), blurRadius: 16, offset: Offset(0, 6)),
];
const _deluxeShadow = [
  BoxShadow(color: Color(0x261A1E32), blurRadius: 3, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x33141A2E), blurRadius: 20, offset: Offset(0, 8)),
];
const _premiumShadow = [
  BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x40080A14), blurRadius: 24, offset: Offset(0, 10)),
];

/// Returns tier visual tokens for [planType].
/// Pass [isDark] = `Theme.of(context).brightness == Brightness.dark`.
///
/// Only Standard has a light/dark split: the two upper tiers are dark cards in
/// both modes, because a black card is the entire point of them.
TierStyle tierStyleFor(String planType, {required bool isDark}) {
  switch (planType.toLowerCase().trim()) {
    // ── Premium — obsidian + gold foil. The black card. ─────────────────
    case 'premium':
      return const TierStyle(
        cardSurface: Color(0xFF171B2B), // lit top
        cardSurfaceEnd: Color(0xFF0B0E1A), // deepest foot
        primaryText: Color(0xFFF2F4FC), // 15.6:1 top / 17.5:1 foot
        mutedText: Color(0xFF9AA2C4), // 6.8:1 / 7.6:1
        accent: AppColors.gold, // 6.3:1 / 7.1:1 — foil, and only here
        borderColor: Color(0x8CB89A3E), // gold 55%
        dividerColor: Color(0x1FFFFFFF),
        meterTrack: Color(0x29FFFFFF),
        warning: Color(0xFFF87171), // 6.2:1; `error` is 2.6:1 here
        ctaFill: AppColors.gold,
        ctaLabel: AppColors.text, // 6.1:1 on gold
        badgeBg: Color(0xFF3E3210),
        badgeText: Color(0xFFC9AC4E), // 5.7:1 on the badge fill
        badgeBorder: Color(0x66B89A3E),
        shadow: _premiumShadow,
        rank: 3,
      );

    // ── De Luxe — brushed brand navy. The metal card. ───────────────────
    case 'de luxe':
    case 'deluxe':
      return const TierStyle(
        cardSurface: Color(0xFF32406F),
        cardSurfaceEnd: Color(0xFF202B4D),
        // Ink is pale steel and the accent is pure white, so the balance
        // figure catches MORE light than the text around it — the way an
        // embossed number behaves on a metal card. Gold text would in fact
        // pass here (4.6:1 on navy, measured) but it belongs to Premium.
        primaryText: Color(0xFFE6ECFB), // 8.5:1 / 11.7:1
        mutedText: Color(0xFFB6C0DC), // 5.5:1 / 7.6:1
        accent: AppColors.white, // 10.0:1 / 13.9:1
        borderColor: Color(0x8C8FA0CC), // steel blue 55%
        dividerColor: AppColors.onNavyDivider,
        meterTrack: Color(0x2EFFFFFF),
        warning: Color(0xFFFCA5A5), // 5.3:1
        ctaFill: Color(0xFFE8EDFA), // brushed-metal fill
        ctaLabel: AppColors.navy, // 10.7:1
        badgeBg: Color(0xFF48588C),
        badgeText: Color(0xFFEDF1FC), // 6.1:1
        badgeBorder: Color(0x598FA0CC),
        shadow: _deluxeShadow,
        rank: 2,
      );

    // ── Standard — linen. The entry card. ───────────────────────────────
    default:
      if (isDark) {
        return const TierStyle(
          cardSurface: AppDarkColors.elevated,
          cardSurfaceEnd: AppDarkColors.surface,
          primaryText: AppDarkColors.text,
          mutedText: AppDarkColors.subtext,
          accent: AppColors.gold,
          borderColor: AppDarkColors.border,
          dividerColor: AppDarkColors.border,
          meterTrack: Color(0x1FFFFFFF),
          warning: Color(0xFFF87171),
          ctaFill: AppColors.navy,
          ctaLabel: AppColors.white,
          badgeBg: AppDarkColors.goldBg,
          badgeText: AppColors.gold,
          badgeBorder: Color(0x00000000),
          shadow: _deluxeShadow,
          rank: 1,
        );
      }
      return const TierStyle(
        cardSurface: AppColors.white,
        // A warm linen wash at the foot — the cream interior of the gift box.
        // Barely there on purpose: this tier's job is clean, not decorated.
        cardSurfaceEnd: Color(0xFFFBFAF6),
        primaryText: AppColors.text, // 16.5:1
        mutedText: AppColors.greyText, // 6.1:1
        // Matte/antique gold, not foil gold: `gold` itself is 2.7:1 on white
        // and cannot be text here at any size.
        accent: AppColors.goldDark, // 6.0:1
        borderColor: Color(0x2E263258), // navy 18% — a crisp edge on cream
        dividerColor: AppColors.greyLight,
        meterTrack: Color(0x1F263258),
        warning: AppColors.error, // 4.8:1
        // Navy fill, per PRODUCT.md's gold-CTA rule: gold marks premium
        // moments, navy carries ordinary primary actions.
        ctaFill: AppColors.navy,
        ctaLabel: AppColors.white, // 12.5:1
        // Deeper than navyLight, which measured 1.14:1 on white — an
        // invisible chip.
        badgeBg: Color(0xFFE4E8F5),
        badgeText: AppColors.navy, // 10.2:1
        badgeBorder: Color(0x00000000),
        shadow: _standardShadow,
        rank: 1,
      );
  }
}

bool _isPremiumTier(String planType) {
  final n = planType.toLowerCase().trim();
  return n == 'premium' || n == 'de luxe' || n == 'deluxe';
}

/// True for tiers that always use a dark card surface.
bool isDarkCardTier(String planType) => _isPremiumTier(planType);

// ── Shared text theme builder ──────────────────────────────────────────────
TextTheme _buildTextTheme(Color primary, Color muted) {
  return GoogleFonts.montserratTextTheme().copyWith(
    displayLarge: GoogleFonts.montserrat(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    displayMedium: GoogleFonts.montserrat(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    displaySmall: GoogleFonts.montserrat(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    headlineMedium: GoogleFonts.montserrat(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    headlineSmall: GoogleFonts.montserrat(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    titleLarge: GoogleFonts.montserrat(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    titleMedium: GoogleFonts.montserrat(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    titleSmall: GoogleFonts.montserrat(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    bodyLarge: GoogleFonts.montserrat(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: GoogleFonts.montserrat(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    labelLarge: GoogleFonts.montserrat(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    labelSmall: GoogleFonts.montserrat(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: muted,
    ),
    bodySmall: GoogleFonts.montserrat(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: muted,
    ),
  );
}

// ── Shared tooltip theme ─────────────────────────────────────────────────────
// Unthemed, Tooltip fell back to Flutter's generic gray bubble — a stray,
// unbranded element next to the navy/gold system everywhere else (visible on
// e.g. the back-button and edit-icon hover/long-press tooltips). Navy is
// brand-fixed and reads as an intentional "black card" chip in both modes,
// so one definition covers light and dark.
TooltipThemeData _tooltipTheme() {
  return TooltipThemeData(
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
    ),
    textStyle: GoogleFonts.montserrat(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.white,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  );
}

// ── Light theme ────────────────────────────────────────────────────────────
ThemeData buildLightTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.navy,
    onPrimary: AppColors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.text,
    surface: AppColors.white,
    onSurface: AppColors.text,
    outline: AppColors.greyLight,
    surfaceContainerHighest: AppColors.navyLight,
    secondaryContainer: AppColors.goldLight,
    onSurfaceVariant: AppColors.greyText,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: _buildTextTheme(AppColors.text, AppColors.greyText),
    tooltipTheme: _tooltipTheme(),
    // The app chrome is navy and the content field is cream — the navy gift
    // box with the cream linen interior, which is the brand's own reference
    // object. It is also what carries the 30% band of the 60/30/10 split:
    // before this the whole screen was cream + white with navy appearing once,
    // so gold had drifted into doing navy's job.
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      // systemOverlayStyle is deliberately NOT set. Flutter derives the status
      // bar style per AppBar from its own background brightness, so navy bars
      // get light icons and the few screens that paint their own light bar
      // (subscription) still get dark ones. Pinning `light` here would break
      // exactly those.
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.greyLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.greyLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
      hintStyle: GoogleFonts.montserrat(fontSize: 14, color: AppColors.grey),
      // Material truncates a validation message to ONE line by default, which
      // turned "Insufficient Emergency Benefit balance — ₱900.00 left" into
      // "…balance — ₱90…" and hid the figure the member needed. A clipped
      // error is worse than a long one.
      errorMaxLines: 3,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.greyLight),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.greyLight,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navy,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.onNavyMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final sel = states.contains(WidgetState.selected);
        return GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? AppColors.white : AppColors.onNavyMuted,
        );
      }),
    ),
  );
}

// ── Dark theme ─────────────────────────────────────────────────────────────
ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.navy,
    onPrimary: AppColors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.text,
    surface: AppDarkColors.surface,
    onSurface: AppDarkColors.text,
    outline: AppDarkColors.border,
    surfaceContainerHighest: AppDarkColors.elevated,
    secondaryContainer: AppDarkColors.goldBg,
    onSurfaceVariant: AppDarkColors.subtext,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppDarkColors.bg,
    textTheme: _buildTextTheme(AppDarkColors.text, AppDarkColors.subtext),
    tooltipTheme: _tooltipTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppDarkColors.bg,
      foregroundColor: AppDarkColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppDarkColors.text,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.gold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppDarkColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // See the light theme: Material clips a validation message to one line.
      errorMaxLines: 3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppDarkColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppDarkColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      labelStyle: GoogleFonts.montserrat(
        fontSize: 14,
        color: AppDarkColors.subtext,
      ),
      floatingLabelStyle: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      ),
      hintStyle: GoogleFonts.montserrat(
        fontSize: 14,
        color: AppDarkColors.subtext,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppDarkColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppDarkColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppDarkColors.border,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppDarkColors.surface,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppDarkColors.subtext,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final sel = states.contains(WidgetState.selected);
        return GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? AppColors.gold : AppDarkColors.subtext,
        );
      }),
    ),
  );
}

// ── Responsive breakpoints ─────────────────────────────────────────────────
// Widths are logical pixels (dp), which is what MediaQuery reports.
//
// The floor we support properly is 320dp. That is not an exotic device: it is
// what an ordinary 360dp handset becomes at Samsung's largest "Screen zoom"
// setting, which raises density and shrinks the effective dp width for every
// app. Samsung is now rolling the same control out per-app, so this is getting
// more common, not less.
//
// The Galaxy Z Fold cover displays sit just above that floor — roughly 329dp
// (Fold 3/4/5), 344dp (Fold 6) and 360dp (Fold 7) — which is why `narrow` is
// set at 360 rather than 340: a Fold 7 cover screen is exactly 360dp and
// should still get the tightened layout, and so should a 360dp phone whose
// owner has scaled text up.
//
// The Z Flip's CLOSED cover screen (~260dp) is deliberately out of scope.
class Breakpoints {
  /// At or below this width, rows reflow and chrome tightens.
  static const double narrow = 360.0;

  /// Material's compact/medium window boundary. Nothing uses it yet; it is
  /// here so a future tablet layout has a named number instead of a literal.
  static const double medium = 600.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isNarrow => screenWidth <= Breakpoints.narrow;

  /// True when the layout is squeezed EITHER by a narrow screen or by scaled-up
  /// text. Both close the same gap, and a row that has to reflow for one has to
  /// reflow for the other — branching on width alone leaves a 411dp phone at
  /// 1.5x font scale broken. 14sp is the body size; past ~17 it stops fitting
  /// beside a peso figure on one line.
  bool get isTight => isNarrow || MediaQuery.textScalerOf(this).scale(14) > 17;
}

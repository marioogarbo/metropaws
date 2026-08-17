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
  static const goldDark = Color(0xFF7A6020);    // small text on gold surfaces (5.5:1 on goldLight)
  static const successDark = Color(0xFF14532D); // small text on light green/gold (8.5:1 on goldLight)

  // ── On-navy ramp ─────────────────────────────────────────────────────────
  // Navy is a real SURFACE now (app bar, Home header, nav capsule), not just a
  // fill behind white text, so it needs its own text ramp. `grey` was the
  // reflex pick for muted-on-navy and it only reaches 3.96:1 — fine for a
  // 25px icon, a fail for the 10sp nav label sitting under it.
  static const onNavyMuted = Color(0xFFBFC5DC);  // 4.6:1 on navy — muted LABELS
  static const onNavyDivider = Color(0x1FFFFFFF); // hairlines inside navy

  // NOTE: `gold` on `navy` is only 2.9:1 — it fails even the 3:1 UI-component
  // floor. Gold reads on the near-black tier cards (0xFF111219), NOT on navy.
  // On a navy surface use white for emphasis and a SOLID gold fill (with
  // `text` on top, 6.1:1) when something must be gold.
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
class TierStyle {
  final Color cardSurface;
  final Color primaryText;
  final Color borderColor;
  final Color badgeBg;
  final Color badgeText;
  final Color? glowColor;

  const TierStyle({
    required this.cardSurface,
    required this.primaryText,
    required this.borderColor,
    required this.badgeBg,
    required this.badgeText,
    this.glowColor,
  });
}

/// Returns tier visual tokens for [planType].
/// Pass [isDark] = `Theme.of(context).brightness == Brightness.dark`.
TierStyle tierStyleFor(String planType, {required bool isDark}) {
  switch (planType.toLowerCase().trim()) {
    case 'premium': // Platinum — cool metallic silver, top tier
      return const TierStyle(
        cardSurface: Color(0xFF111219), // lifted off the dark scaffold (0xFF0D1220)
        primaryText: Color(0xFFD7DCEC),
        borderColor: Color(0x73C7CCDD), // silver 45% — edge survives without the glow
        badgeBg: Color(0xFF1A1F35),
        badgeText: Color(0xFFD7DCEC),
        glowColor: Color(0x1FC7CCDD), // silver 12%
      );
    case 'de luxe':
    case 'deluxe': // Gold — the "most popular" mid tier
      return TierStyle(
        cardSurface: const Color(0xFF111219),
        primaryText: AppColors.gold,
        borderColor: const Color(0x73B89A3E), // gold 45%
        badgeBg: const Color(0xFF261E08),
        badgeText: AppColors.gold,
        glowColor: const Color(0x1FB89A3E), // gold 12%
      );
    default: // Standard — warm tan/bronze, entry tier
      if (isDark) {
        return const TierStyle(
          cardSurface: AppDarkColors.surface,
          primaryText: AppDarkColors.text,
          borderColor: AppDarkColors.border,
          badgeBg: AppDarkColors.goldBg,
          badgeText: AppColors.gold,
        );
      }
      return const TierStyle(
        cardSurface: AppColors.white,
        primaryText: AppColors.text,
        borderColor: Color(0x33B89A3E),
        badgeBg: AppColors.goldLight,
        badgeText: AppColors.goldDark,
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

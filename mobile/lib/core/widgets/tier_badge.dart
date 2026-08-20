import 'package:flutter/material.dart';
import '../../theme.dart';

/// The membership tier chip — "Standard" / "Deluxe" / "Premium".
///
/// It is the card's non-chromatic tier cue: the tier is spelled out in words, so
/// a member who cannot separate the navy card from the obsidian one still reads
/// which plan they hold. Colours come from [TierStyle] rather than being derived
/// here, so the chip can never drift from the card it sits on.
class TierBadge extends StatelessWidget {
  final String planType;
  final bool small;

  const TierBadge({super.key, required this.planType, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tier = tierStyleFor(planType, isDark: isDark);
    // Every tier carries the hairline now, not just Premium. Without it the
    // Standard chip was a 1.14:1 fill on a white card — a word floating in
    // space rather than a stamped chip.
    final border = tier.badgeBorder.a > 0
        ? tier.badgeBorder
        : tier.badgeText.withValues(alpha: 0.22);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: tier.badgeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        planType,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tier.badgeText,
          fontWeight: FontWeight.w700,
          fontSize: small ? 10 : 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

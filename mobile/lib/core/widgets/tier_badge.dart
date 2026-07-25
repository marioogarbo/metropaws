import 'package:flutter/material.dart';
import '../../theme.dart';

class TierBadge extends StatelessWidget {
  final String planType;
  final bool small;

  const TierBadge({super.key, required this.planType, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tier = tierStyleFor(planType, isDark: isDark);
    final isPremium = planType.toLowerCase().trim() == 'premium';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: tier.badgeBg,
        borderRadius: BorderRadius.circular(20),
        border: isPremium
            ? Border.all(
                color: tier.badgeText.withValues(alpha: 0.35),
                width: 1,
              )
            : null,
      ),
      child: Text(
        planType,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tier.badgeText,
              fontWeight: FontWeight.w600,
              fontSize: small ? 10 : 11,
            ),
      ),
    );
  }
}

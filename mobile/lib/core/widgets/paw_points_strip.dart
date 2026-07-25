import 'package:flutter/material.dart';

import '../../theme.dart';
import '../models/paw_points.dart';
import 'paw_coin.dart';
import 'scale_button.dart';

/// The navy "PawPoints" chip strip — balance at a glance, tap to view history
/// and rewards. Shared between the Home tab and the Benefits hub so the two
/// never drift in size, copy, or color.
class PawPointsStrip extends StatelessWidget {
  final PawPointsBalance? balance;
  final VoidCallback onTap;

  const PawPointsStrip({super.key, required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pointsText = balance != null ? '${balance!.currentBalance} pts' : '—';

    return Semantics(
      button: true,
      label: balance != null
          ? 'PawPoints balance: ${balance!.currentBalance} points. '
              'Double tap to view history and rewards.'
          : 'PawPoints. Double tap to view history and rewards.',
      excludeSemantics: true,
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const PawCoin(size: 22),
              const SizedBox(width: 12),
              // Expanded so the balance owns the leading space and pushes the
              // trailing affordance right; both texts ellipsize rather than
              // overflow when the font scale / a long balance would exceed
              // the strip on a narrow screen.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAWPOINTS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      pointsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Flexible so the label shrinks/ellipsizes before it can force a
              // RenderFlex overflow at large text scales.
              Flexible(
                child: Text(
                  'History & Rewards',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.white.withValues(alpha: 0.65),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

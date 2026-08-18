import 'package:flutter/material.dart';

import '../../theme.dart';
import '../models/paw_points.dart';
import 'paw_coin.dart';
import 'scale_button.dart';

/// The navy "PawPoints" chip strip — balance at a glance, tap to view history
/// and rewards. Shared between the Home tab and the Benefits hub so the two
/// never drift in size, copy, or color.
String _grouped(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class PawPointsStrip extends StatelessWidget {
  final PawPointsBalance? balance;
  final VoidCallback onTap;

  /// True when the strip is already sitting ON a navy surface (the Home
  /// header). It then drops its own navy fill and renders as a plain row: a
  /// navy pill inside a navy block is an invisible container, and nesting one
  /// card in another is exactly the hierarchy noise the fill was meant to
  /// create. Same coin, same number, same copy either way — the fill is the
  /// only difference, which is what stops the two placements drifting.
  final bool _onNavy;

  const PawPointsStrip({super.key, required this.balance, required this.onTap})
    : _onNavy = false;

  const PawPointsStrip.onNavy({
    super.key,
    required this.balance,
    required this.onTap,
  }) : _onNavy = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Grouped, because a four-digit balance reading "1800" undersells itself
    // next to "1,800".
    final pointsText = balance != null ? _grouped(balance!.currentBalance) : '—';

    // Measured on a 329dp Fold cover screen: the balance and "pts" leave the
    // trailing label ~92dp, and "History & Rewards" needs ~107dp, so it
    // ellipsised to "History & Rewa…" — a label that has stopped saying
    // anything. The short form still names where the tap goes.
    final actionLabel = context.isTight ? 'Rewards' : 'History & Rewards';

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
          decoration: _onNavy
              ? null
              : BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
          padding: _onNavy
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const PawCoin(size: 26),
              const SizedBox(width: 12),
              // The coin IS the PawPoints mark, so the "PAWPOINTS" wordmark
              // above the number was naming what the icon already said. Dropping
              // it lets the balance take the space and read at a glance, which
              // is the one thing this strip exists to answer.
              //
              // Expanded so the balance owns the leading space and pushes the
              // trailing affordance right; both texts ellipsize rather than
              // overflow at large font scales.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        pointsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Not gold: gold on navy is 2.9:1 and fails at label size.
                    // The gold coin to the left already carries the brand cue.
                    Text(
                      'pts',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.onNavyMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // NOT Flexible. Expanded (the balance) and Flexible (this label)
              // both default to flex: 1, so Row split the free space 50/50
              // regardless of need — and inside the Benefits hub's pill, whose
              // 16dp padding costs another 32dp, the balance's half was too
              // small and "1,800" rendered as "1,8…". Truncating the member's
              // points balance is the worst possible thing this widget can do.
              // Natural width here hands every spare pixel to the number, and
              // the label is ours and short (isTight already swaps in the
              // compact wording, and isTight fires on large font scales too).
              Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                // white@65% composites to 3.9:1 on navy — under the 4.5:1
                // floor for a 12sp label. onNavyMuted is the same read at
                // 4.6:1.
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onNavyMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onNavyMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

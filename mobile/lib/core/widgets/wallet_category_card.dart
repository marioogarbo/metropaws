import 'package:flutter/material.dart';

import '../../theme.dart';
import '../models/reimbursement.dart';
import 'tier_badge.dart';

/// One pet's Benefit Wallet card — TWO pools stacked: Preventive Wellness (all
/// non-emergency claims) and Emergency ("Emergency"-category claims). Each pool
/// shows remaining balance, progress toward the plan's annual pool, and
/// (optionally) the used/pending breakdown. The Emergency block is only shown
/// when the plan funds an emergency pool.
class WalletPetCard extends StatelessWidget {
  final WalletPet wallet;
  final bool showStats;
  // The pet's plan tier, shown as a small badge next to the pet name so the
  // member can see which plan the wallet comes from. Hidden when null.
  final String? planType;

  /// Tapped to pay the next monthly instalment. Null hides the action — pass it
  /// only where a checkout can actually be launched and polled, since nothing
  /// bills automatically and a dead button here would strand a subscriber.
  final VoidCallback? onPayInstalment;

  const WalletPetCard({
    super.key,
    required this.wallet,
    this.showStats = false,
    this.planType,
    this.onPayInstalment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = wallet;
    final hasEmergency = c.emergencyWalletCentavos > 0;

    return Semantics(
      label:
          'Benefits for ${c.petName}. '
          'Preventive Wellness: ${pesoFromCentavos(c.remainingCentavos)} remaining '
          'of ${pesoFromCentavos(c.walletCentavos)}.'
          '${hasEmergency ? ' Emergency: ${pesoFromCentavos(c.emergencyRemainingCentavos)} remaining of ${pesoFromCentavos(c.emergencyWalletCentavos)}.' : ''}',
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet name + tier badge header — the two pools share it.
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.petName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.planExpired) ...[
                  const SizedBox(width: 8),
                  // Plan year over: claims are blocked until renewal, so the
                  // wallet balances shown below are dormant — flag it here.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Expired — renew',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (planType != null && planType!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TierBadge(planType: planType!, small: true),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _WalletPoolMeter(
              available: c.preventiveAvailable,
              label: 'Preventive Wellness',
              totalCentavos: c.walletCentavos,
              remainingCentavos: c.remainingCentavos,
              usedCentavos: c.usedCentavos,
              pendingCentavos: c.pendingCentavos,
              showStats: showStats,
            ),
            if (hasEmergency) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              _WalletPoolMeter(
                available: c.emergencyAvailable,
                label: 'Emergency',
                totalCentavos: c.emergencyWalletCentavos,
                remainingCentavos: c.emergencyRemainingCentavos,
                usedCentavos: c.emergencyUsedCentavos,
                pendingCentavos: c.emergencyPendingCentavos,
                showStats: showStats,
              ),
            ],
            if (c.isMonthly) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              _MonthlyFooter(wallet: c, onPayInstalment: onPayInstalment),
            ],
          ],
        ),
      ),
    );
  }
}

/// The monthly-membership strip under the pools: what state the membership is
/// in, when the next instalment is due, and the way to pay it.
///
/// It sits inside the wallet card because a subscription is per PET — a member
/// can hold one pet annually and another monthly, and a single screen-level
/// button could not say which one it meant.
class _MonthlyFooter extends StatelessWidget {
  final WalletPet wallet;
  final VoidCallback? onPayInstalment;

  const _MonthlyFooter({required this.wallet, required this.onPayInstalment});

  String _dueLabel(DateTime due) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final today = DateTime.now();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final date = '${months[due.month - 1]} ${due.day}';
    if (days < 0) return 'Overdue since $date';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Next payment $date';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final due = wallet.subscriptionNextDueOn;
    // Only a withheld membership needs explaining. A fully eligible subscriber
    // sees the same wallet as anyone else, so labelling their status would be
    // noise.
    final withheld = wallet.benefitsWithheld;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                // The contract's own wording, sent by the server so the app
                // never carries a phrase only the document may change.
                withheld ? wallet.membershipStatusLabel : 'Monthly membership',
                style: tt.labelLarge?.copyWith(
                  color: withheld ? cs.error : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${wallet.subscriptionPaymentsMade} paid',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        if (withheld) ...[
          const SizedBox(height: 4),
          Text(
            wallet.membershipStatus == 'suspended'
                ? 'Settle the outstanding payment to use benefits again. '
                      'Paying late restarts the qualifying period.'
                : 'Keep paying each month and your benefits open up.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (due != null) ...[
          const SizedBox(height: 10),
          Text(
            _dueLabel(due),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (onPayInstalment != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPayInstalment,
              child: const Text('Pay next instalment'),
            ),
          ),
        ],
      ],
    );
  }
}

/// One wallet pool inside a [WalletPetCard]: label + remaining, a progress bar,
/// a "% used" read-out, and (optionally) a Used/Pending stat row.
class _WalletPoolMeter extends StatelessWidget {
  /// False while a monthly subscriber has not vested this pool. The balance
  /// is still shown — it is real, and it is what they are working toward —
  /// but presenting it as spendable would invite a claim the server refuses.
  final bool available;

  const _WalletPoolMeter({
    this.available = true,
    required this.label,
    required this.totalCentavos,
    required this.remainingCentavos,
    required this.usedCentavos,
    required this.pendingCentavos,
    required this.showStats,
  });

  final String label;
  final int totalCentavos;
  final int remainingCentavos;
  final int usedCentavos;
  final int pendingCentavos;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pct = totalCentavos == 0
        ? 0.0
        : (usedCentavos / totalCentavos).clamp(0.0, 1.0);
    final pctUsed = (pct * 100).round();
    // A fresh pool (nothing used or pending) needs no "0% used" / "Used ₱0.00"
    // read-out — the full balance and empty bar already say it. Surface those
    // details only once there's real activity, so the card stays calm at rest.
    final hasActivity = usedCentavos > 0 || pendingCentavos > 0;
    // Remaining balance is the member's money — a high-value number, so it
    // earns the gold accent (goldDark on light surfaces for contrast; raw
    // gold reads fine once the surface goes dark).
    // Gold means "yours to spend". An unvested pool is not, so it drops to
    // muted text — the number stays legible, but stops reading as available
    // money the member can act on.
    final remainingColor = !available
        ? cs.onSurfaceVariant
        : (isDark ? AppColors.gold : AppColors.goldDark);

    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!available)
          Text(
            'Not available yet',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );

    // The amount block is inflexible, so on a narrow screen it wrapped to two
    // lines and crossAxisAlignment.end dropped "Preventive Wellness" down to
    // the second line's baseline — the label read as belonging to the wrong
    // row. Stacking is the same reflow the Home card's meter uses; keeping the
    // two consistent is the point of them sharing a visual.
    final tight = context.isTight;
    final amountBlock = Column(
      crossAxisAlignment: tight
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          pesoFromCentavos(remainingCentavos),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: remainingColor,
          ),
        ),
        Text(
          'left of ${pesoFromCentavos(totalCentavos)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tight)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelBlock, const SizedBox(height: 4), amountBlock],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: labelBlock),
              const SizedBox(width: 8),
              amountBlock,
            ],
          ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.secondary),
          ),
        ),
        // Numeric read-out of the bar — agrees with the fill ("used"), not the
        // remaining-oriented header, so the two don't contradict. Hidden at
        // rest (see [hasActivity]).
        if (hasActivity) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$pctUsed% used',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        if (showStats && hasActivity) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WalletStat(
                  label: 'Used',
                  value: pesoFromCentavos(usedCentavos),
                ),
              ),
              if (pendingCentavos > 0) ...[
                const SizedBox(width: 20),
                Expanded(
                  child: _WalletStat(
                    label: 'Pending',
                    value: pesoFromCentavos(pendingCentavos),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

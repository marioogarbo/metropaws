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

  const WalletPetCard({
    super.key,
    required this.wallet,
    this.showStats = false,
    this.planType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = wallet;
    final hasEmergency = c.emergencyWalletCentavos > 0;

    return Semantics(
      label: 'Benefit Wallet for ${c.petName}. '
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
                        horizontal: 8, vertical: 3),
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
                label: 'Emergency',
                totalCentavos: c.emergencyWalletCentavos,
                remainingCentavos: c.emergencyRemainingCentavos,
                usedCentavos: c.emergencyUsedCentavos,
                pendingCentavos: c.emergencyPendingCentavos,
                showStats: showStats,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One wallet pool inside a [WalletPetCard]: label + remaining, a progress bar,
/// a "% used" read-out, and (optionally) a Used/Pending stat row.
class _WalletPoolMeter extends StatelessWidget {
  const _WalletPoolMeter({
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
    final remainingColor = isDark ? AppColors.gold : AppColors.goldDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
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
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}

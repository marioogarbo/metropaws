import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/paw_points.dart';
import '../../../core/widgets/mp_empty_state.dart';
import '../../../core/widgets/mp_help_sheet.dart';
import '../../../core/widgets/paw_coin.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Themed icon per transaction activity type (presentation concern — kept out
/// of the PawPointsTransaction model). Star only for admin bonus awards, per
/// the "stars mean bonus/featured, never PawPoints" rule.
IconData _activityIcon(String activityType) {
  switch (activityType) {
    case 'membership_activation':
      return Icons.workspace_premium_rounded;
    case 'membership_renewal':
      return Icons.autorenew_rounded;
    case 'pet_profile_completed':
      return Icons.pets;
    case 'service_deployed_vet':
      return Icons.vaccines_outlined;
    case 'service_deployed_grooming':
      return Icons.content_cut_rounded;
    case 'admin_manual_award':
      return Icons.star_rounded;
    default:
      return Icons.pets;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PawPointsScreen extends StatefulWidget {
  const PawPointsScreen({super.key, this.planType});

  /// The member's plan name, used to show their own earning rate instead of a
  /// span. Null when they have no plan yet.
  final String? planType;

  @override
  State<PawPointsScreen> createState() => _PawPointsScreenState();
}

class _PawPointsScreenState extends State<PawPointsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    context.read<MemberBloc>().add(PawPointsLoadRequested());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showHowPawPointsWork() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PawPointsHelpSheet(tier: _tierFor(widget.planType)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;
    final gold = cs.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 64,
        // Same screen-title register as the Reimbursements AppBar: display
        // size per the typography mandate, PawCoin as the brand mark.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const PawCoin(size: 24),
              const SizedBox(width: 10),
              Text(
                'PawPoints',
                style: theme.textTheme.displaySmall!.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How PawPoints work',
            onPressed: _showHowPawPointsWork,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: gold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: theme.textTheme.labelLarge!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          tabs: const [
            Tab(text: 'Rewards'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: BlocBuilder<MemberBloc, MemberState>(
        buildWhen: (_, curr) =>
            curr is PawPointsLoaded ||
            curr is PawPointsFailure ||
            curr is MemberInitial,
        builder: (context, state) {
          if (state is PawPointsLoaded) {
            return Column(
              children: [
                _BalanceHero(balance: state.balance),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _RewardsTab(
                        rewards: state.rewards,
                        balance: state.balance.currentBalance,
                      ),
                      _HistoryTab(history: state.history),
                    ],
                  ),
                ),
              ],
            );
          }
          if (state is PawPointsFailure) {
            return _ErrorState(
              message: state.message,
              onRetry: () =>
                  context.read<MemberBloc>().add(PawPointsLoadRequested()),
            );
          }
          return const _LoadingState();
        },
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: cs.secondary, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your PawPoints…',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('😕', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load PawPoints',
              style: theme.textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: navy, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                ),
                child: Text(
                  'Try again',
                  style: theme.textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance hero ──────────────────────────────────────────────────────────────

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});
  final PawPointsBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navy = theme.colorScheme.primary;
    final gold = theme.colorScheme.secondary;

    return Container(
      width: double.infinity,
      color: navy,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -16,
            top: -14,
            child: Icon(
              Icons.pets,
              size: 130,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Semantics(
              label:
                  '${balance.currentBalance} PawPoints available. Lifetime earned: ${balance.lifetimeEarned} points.',
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow pill — raised to alpha 0.3, white text (7.5:1 on navy)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'YOUR BALANCE',
                      style: theme.textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Balance number in Flexible — prevents overflow on wide values
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '${balance.currentBalance}',
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                          style: theme.textTheme.displayLarge!.copyWith(
                            color: gold,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          'pts',
                          style: theme.textTheme.titleLarge!.copyWith(
                            color: gold.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Raised to 0.75 alpha → 7.2:1 on navy ✓
                  Text(
                    'PawPoints available',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  // Lifetime stat — normal casing, raised to 0.65 → 5.4:1 ✓
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lifetime earned',
                        style: theme.textTheme.labelSmall!.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${balance.lifetimeEarned} pts',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});
  final List<PawPointsTransaction> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;
    final isDark = theme.brightness == Brightness.dark;

    if (history.isEmpty) {
      return const MpEmptyState(
        icon: Icons.pets,
        title: 'No points yet',
        message: 'Activate your plan or register a pet to start earning.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final tx = history[i];
        final isEarn = tx.points > 0;

        // Earn: surfaceContainerHighest (navyLight/darkElevated)
        // Spend: errorLight (light) / errorBg (dark)
        final cardBg = isEarn
            ? cs.surfaceContainerHighest
            : (isDark ? AppDarkColors.errorBg : AppColors.errorLight);
        final cardBorder = isEarn
            ? navy.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.15);

        // Earn badge: goldDark on secondaryContainer (goldLight/darkGoldBg)
        // In dark mode use gold directly — 6.3:1 on darkGoldBg ✓
        final earnBadgeText = isDark ? cs.secondary : AppColors.goldDark;

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container — surface color lifts off the tinted card
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _activityIcon(tx.activityType),
                      size: 22,
                      color: isEarn
                          ? (isDark ? cs.secondary : navy)
                          : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.label,
                        style: theme.textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(tx.createdAt.toLocal()),
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Point badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEarn
                        ? cs.secondaryContainer
                        : (isDark
                            ? AppDarkColors.elevated
                            : AppColors.errorLight),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isEarn
                          ? cs.secondary.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${isEarn ? '+' : ''}${tx.points}',
                    style: theme.textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isEarn ? earnBadgeText : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Rewards tab ───────────────────────────────────────────────────────────────

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({required this.rewards, required this.balance});
  final List<PawReward> rewards;
  final int balance;

  IconData _rewardIcon(String type) {
    switch (type) {
      case 'credit':
        return Icons.savings_outlined;
      case 'voucher':
        return Icons.confirmation_number_outlined;
      case 'recognition':
        return Icons.military_tech_outlined;
      case 'merchandise':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;
    final gold = cs.secondary;
    final isDark = theme.brightness == Brightness.dark;

    if (rewards.isEmpty) {
      return const MpEmptyState(
        icon: Icons.card_giftcard_rounded,
        title: 'Rewards coming soon',
        message: 'Check back later for exciting pet wellness rewards.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final reward = rewards[i];
        final canRedeem = balance >= reward.pointsRequired;
        final progress = (balance / reward.pointsRequired).clamp(0.0, 1.0);
        final remaining = reward.pointsRequired - balance;

        // Reachable badge — successDark on successLight (8.7:1) ✓
        //                  — success on successBg dark (5.5:1) ✓
        final reachableBadgeBg =
            isDark ? AppDarkColors.successBg : AppColors.successLight;
        final reachableBadgeText =
            isDark ? AppColors.success : AppColors.successDark;

        // "You have enough points!" — successDark on secondaryContainer (8.5:1 light) ✓
        //                           — success on secondaryContainer dark (5.1:1) ✓
        final successTextColor =
            isDark ? AppColors.success : AppColors.successDark;

        // pts pill text — goldDark on surface (light), gold on surface (dark)
        final ptsPillText =
            isDark ? gold : AppColors.goldDark;

        return Container(
          decoration: BoxDecoration(
            color: canRedeem ? cs.secondaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canRedeem
                  ? gold.withValues(alpha: 0.45)
                  : cs.outline,
              width: canRedeem ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: canRedeem ? cs.surface : cs.outline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _rewardIcon(reward.rewardType),
                          size: 22,
                          color: canRedeem
                              ? (isDark ? gold : navy)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  reward.name,
                                  style: theme.textTheme.labelLarge!.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: canRedeem
                                        ? navy
                                        : cs.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (canRedeem) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: reachableBadgeBg,
                                    borderRadius:
                                        BorderRadius.circular(100),
                                    border: Border.all(
                                        color: AppColors.success
                                            .withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'Reachable',
                                    style: theme.textTheme.labelSmall!.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: reachableBadgeText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (reward.description != null &&
                              reward.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              reward.description!,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  label:
                      'Progress toward ${reward.name}: ${(progress * 100).round()} percent',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: canRedeem
                          ? cs.surface.withValues(alpha: 0.6)
                          : cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canRedeem ? gold : gold.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        canRedeem
                            ? 'You have enough points!'
                            : '$remaining more pts needed',
                        style: theme.textTheme.labelSmall!.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: canRedeem
                              ? successTextColor
                              : cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: canRedeem ? cs.surface : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${reward.pointsRequired} pts',
                        style: theme.textTheme.labelSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: canRedeem ? ptsPillText : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Earning activities ────────────────────────────────────────────────────────

/// The three earning rates. Mirrors `_normalize_tier` in
/// `backend/app/domain/paw_points_utils.py`: anything that isn't premium or
/// deluxe earns the standard rate.
enum _PlanTier {
  standard('Standard'),
  deluxe('Deluxe'),
  premium('Premium');

  const _PlanTier(this.label);

  final String label;
}

/// Null when the member has no plan yet — the backend would treat that as
/// standard, but on screen "we can't tell you your rate" is the honest answer.
/// Activation points follow the plan being bought, not a rate they hold today.
_PlanTier? _tierFor(String? planType) {
  final name = planType?.toLowerCase().trim();
  if (name == null || name.isEmpty) return null;
  if (name.contains('premium')) return _PlanTier.premium;
  if (name.contains('deluxe')) return _PlanTier.deluxe;
  return _PlanTier.standard;
}

/// One row of the backend's POINTS_BY_TIER table. Kept per-tier rather than as a
/// min–max range: a member on Deluxe is owed their own number, not a span they
/// have to decode.
class _EarnActivity {
  final String label;

  /// The qualifier that a bare number can't carry — how often it's awarded.
  final String rule;

  final int standard;
  final int deluxe;
  final int premium;

  const _EarnActivity({
    required this.label,
    required this.rule,
    required this.standard,
    required this.deluxe,
    required this.premium,
  });

  int pointsFor(_PlanTier tier) => switch (tier) {
    _PlanTier.standard => standard,
    _PlanTier.deluxe => deluxe,
    _PlanTier.premium => premium,
  };
}

// Mirrors POINTS_BY_TIER in backend/app/domain/paw_points_utils.py. A change
// there has to land here too — the member reads these numbers before earning
// them, so a drift shows up as a broken promise.
const _earnActivities = [
  _EarnActivity(
    label: 'Activate Membership',
    rule: 'On activation or upgrade',
    standard: 100,
    deluxe: 200,
    premium: 300,
  ),
  _EarnActivity(
    label: 'Add a Pet Profile',
    rule: 'Once per pet',
    standard: 50,
    deluxe: 75,
    premium: 100,
  ),
  _EarnActivity(
    label: 'Vet Service Used',
    rule: 'Each vet session',
    standard: 20,
    deluxe: 30,
    premium: 40,
  ),
  _EarnActivity(
    label: 'Grooming Service Used',
    rule: 'Each grooming session',
    standard: 15,
    deluxe: 25,
    premium: 35,
  ),
  _EarnActivity(
    label: 'Renew Membership',
    rule: 'Each annual renewal',
    standard: 150,
    deluxe: 300,
    premium: 500,
  ),
];

/// Fixed column widths: they line every row's numbers up without the cost of a
/// full [Table], and they give the table an intrinsic width to scroll inside.
/// Sized for the spelled-out plan names — abbreviating the headings to fit a
/// phone would save a scroll and cost the member the words.
const double _activityColumnWidth = 180;
const double _rateColumnWidth = 76;

/// The earning matrix, with the member's own plan carried as a tinted column.
/// The data is two-dimensional — activity against plan — so it reads as a table
/// rather than five cards each repeating the same three tier names.
class _EarnRateTable extends StatelessWidget {
  const _EarnRateTable({required this.tier});

  final _PlanTier? tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final goldInk = isDark ? AppColors.gold : AppColors.goldDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            tier == null
                ? 'What you earn depends on your plan — higher plans earn more.'
                : 'The gold column is your ${tier!.label} plan. Higher plans '
                      'earn more.',
            style: theme.textTheme.bodySmall!.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        // Spelled-out plan names put the table past a phone's width, so it
        // scrolls sideways. The clipped right edge is the affordance — the
        // rounded border sliding under the screen edge reads as "more here".
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              children: [
                _EarnRateHeader(tier: tier, goldInk: goldInk),
                for (final activity in _earnActivities)
                  _EarnRateRow(
                    activity: activity,
                    tier: tier,
                    goldInk: goldInk,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EarnRateHeader extends StatelessWidget {
  const _EarnRateHeader({required this.tier, required this.goldInk});

  final _PlanTier? tier;
  final Color goldInk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: _activityColumnWidth, height: 32),
          for (final t in _PlanTier.values)
            Container(
              width: _rateColumnWidth,
              color: t == tier ? cs.secondaryContainer : null,
              alignment: Alignment.center,
              child: Text(
                t.label,
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: t == tier ? goldInk : cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EarnRateRow extends StatelessWidget {
  const _EarnRateRow({
    required this.activity,
    required this.tier,
    required this.goldInk,
  });

  final _EarnActivity activity;
  final _PlanTier? tier;
  final Color goldInk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // A table is close to unreadable cell-by-cell under TalkBack, so each row
    // is announced as one sentence instead.
    final spoken = [
      '${activity.label}. ${activity.rule}.',
      for (final t in _PlanTier.values)
        '${t.label} ${activity.pointsFor(t)} points'
            '${t == tier ? ', your plan' : ''}',
    ].join(' ');

    return Semantics(
      label: spoken,
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outline)),
          ),
          // stretch paints each rate cell over the row's full height, giving
          // the tinted column an unbroken band. It needs a bounded height, and
          // the sheet's ListView hands the table an unbounded one.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _activityColumnWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          activity.label,
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activity.rule,
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final t in _PlanTier.values)
                  Container(
                    width: _rateColumnWidth,
                    color: t == tier ? cs.secondaryContainer : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${activity.pointsFor(t)}',
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontSize: 14,
                        fontWeight: t == tier
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: t == tier ? goldInk : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Help sheet ───────────────────────────────────────────────────────────────

/// The program rules behind PawPoints, reached from the AppBar help icon — the
/// fine print that had no home while "How to Earn" owned the third tab.
///
/// Deliberately silent on expiry. MMS-DWP-001 §67 only *suggests* a 12-month
/// life, management has not ratified it, and nothing in the backend expires a
/// point — publishing a rule the ledger does not enforce is worse than saying
/// nothing. Add a section here when expiry actually ships.
class _PawPointsHelpSheet extends StatelessWidget {
  const _PawPointsHelpSheet({required this.tier});

  final _PlanTier? tier;

  @override
  Widget build(BuildContext context) {
    return MpHelpSheet(
      title: 'How PawPoints work',
      intro:
          'PawPoints are a thank-you for looking after your pets through '
          'MetroPaws. They aren’t cash — you exchange them for rewards from '
          'the MetroPaws catalogue.',
      children: [
        const MpHelpHeading('What earns points'),
        _EarnRateTable(tier: tier),

        const SizedBox(height: 18),
        const MpHelpHeading('When points appear'),
        MpHelpBullet(
          'They’re added automatically. Nothing to claim, no code to enter.',
        ),
        MpHelpBullet(
          'Activation and renewal points land once your payment is confirmed.',
        ),
        MpHelpBullet(
          'Pet profile points land once that pet’s profile is complete — once '
          'per pet.',
        ),
        MpHelpBullet(
          'Vet and grooming points land after MetroPaws records the session, '
          'so allow a little time after the visit.',
        ),

        SizedBox(height: 18),
        MpHelpHeading('Redeeming a reward'),
        MpHelpBullet(
          'Once your balance reaches a reward’s target, it’s yours to claim.',
        ),
        MpHelpBullet(
          'Message csr@metropaws.ph with the reward you want. MetroPaws '
          'confirms it and deducts the points from your balance.',
        ),
        MpHelpBullet('Your membership has to be active when you redeem.'),
        MpHelpBullet(
          'Rewards depend on availability. If one runs out, MetroPaws may '
          'offer an equivalent.',
        ),
        MpHelpBullet(
          'A redemption is final once processed, unless MetroPaws approves a '
          'reversal.',
        ),

        SizedBox(height: 18),
        MpHelpHeading('When points can be taken back'),
        MpHelpBullet(
          'Points from a payment that’s later refunded, cancelled or reversed '
          'may be removed.',
        ),
        MpHelpBullet(
          'Points on an account under review may be held until the review '
          'finishes.',
        ),
      ],
    );
  }
}

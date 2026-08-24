import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/member.dart';
import '../../../core/models/paw_points.dart';
import '../../../core/models/reimbursement.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/paw_points_strip.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/wallet_category_card.dart';
import '../../../theme.dart';
import 'member_dashboard_screen.dart' show kNavClearance;
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';
import 'paw_points_screen.dart';
import 'payout_details_screen.dart';
import 'reimbursement_screen.dart';

/// The "Benefits" bottom-tab hub: surfaces PawPoints, the reimbursement Benefit
/// Wallet, and entry points into claims/submit. Deep flows reuse the existing
/// [PawPointsScreen] and [ReimbursementScreen] (opened as pushed routes sharing
/// the same [MemberBloc]).
class BenefitsTab extends StatefulWidget {
  const BenefitsTab({super.key});

  @override
  State<BenefitsTab> createState() => _BenefitsTabState();
}

class _BenefitsTabState extends State<BenefitsTab> {
  PawPointsBalance? _balance;
  List<WalletPet> _wallet = const [];
  bool _walletLoaded = false;
  Member? _member;

  // Instalment checkout in flight. Held so the payment can be polled to
  // completion even if the member never comes back through the deep link.
  Timer? _pollTimer;
  String? _activePaymentId;

  // The pet's plan tier, for the wallet card badge. Null when the member isn't
  // loaded yet or the pet has no active plan.
  String? _planTypeFor(String petId) {
    final pets = _member?.pets;
    if (pets == null) return null;
    for (final p in pets) {
      if (p.id == petId) return p.planType;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Catch the member if it loaded before this tab mounted.
    final current = context.read<MemberBloc>().state;
    if (current is MemberLoaded) _member = current.member;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _load() {
    final bloc = context.read<MemberBloc>();
    bloc.add(PawPointsBalanceLoadRequested());
    bloc.add(ReimbursementsLoadRequested());
  }

  /// Open the hosted checkout for an instalment, then poll until the payment
  /// clears.
  ///
  /// The polling is the important half. The webhook is unreliable on dev and
  /// the member may never return to the app through the deep link, so dropping
  /// the payment id here is exactly what once left a paying member without
  /// their plan. Same rule as the plan-selection flow.
  Future<void> _launchInstalment(String url, String paymentId) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!mounted) return;
    _activePaymentId = paymentId;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _activePaymentId != null) {
        context.read<MemberBloc>().add(PaymentStatusPolled(_activePaymentId!));
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activePaymentId = null;
  }

  void _openPawPoints() {
    final bloc = context.read<MemberBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const PawPointsScreen()),
      ),
    );
  }

  void _openPayoutSetup() {
    final member = _member;
    if (member == null) return;
    final bloc = context.read<MemberBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: PayoutDetailsScreen(member: member),
        ),
      ),
    );
  }

  Future<void> _openReimbursements(int initialTab) async {
    final bloc = context.read<MemberBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ReimbursementScreen(initialTab: initialTab),
        ),
      ),
    );
    if (mounted) _load(); // refresh wallet after returning
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocListener<MemberBloc, MemberState>(
      listenWhen: (_, s) =>
          s is PawPointsLoaded ||
          s is ReimbursementLoaded ||
          s is ReimbursementFailure ||
          s is MemberLoaded ||
          s is PetOperationSuccess ||
          s is PayoutSaveSuccess ||
          s is CheckoutReady ||
          s is CheckoutFailed ||
          s is PaymentVerified ||
          s is PaymentDeclined,
      listener: (context, state) {
        if (state is PawPointsLoaded) {
          setState(() => _balance = state.balance);
        } else if (state is ReimbursementLoaded) {
          setState(() {
            _wallet = state.wallet.pets;
            _walletLoaded = true;
          });
        } else if (state is ReimbursementFailure) {
          setState(() => _walletLoaded = true);
        } else if (state is MemberLoaded) {
          setState(() => _member = state.member);
        } else if (state is PetOperationSuccess) {
          setState(() => _member = state.member);
        } else if (state is PayoutSaveSuccess) {
          setState(() => _member = state.member);
        } else if (state is CheckoutReady) {
          _launchInstalment(state.checkoutUrl, state.paymentId);
        } else if (state is CheckoutFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else if (state is PaymentVerified) {
          _stopPolling();
          _load();
        } else if (state is PaymentDeclined) {
          // Without this the poll would keep firing until the tab is
          // disposed, and the member would be told nothing.
          _stopPolling();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "That payment didn't go through. You can try again.",
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: RefreshIndicator(
        color: cs.primary,
        onRefresh: () async => _load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 40 + kNavClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Benefits', style: theme.textTheme.displaySmall),
              ),
              const SizedBox(height: 6),
              Text(
                'Your points, balances and claims',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (_walletLoaded && _wallet.isNotEmpty) ...[
                const SizedBox(height: 20),
                _AvailableToClaimHero(wallet: _wallet),
              ],
              const SizedBox(height: 20),

              // ── PawPoints ──────────────────────────────────────────────
              PawPointsStrip(balance: _balance, onTap: _openPawPoints),
              const SizedBox(height: 24),

              // ── Benefit balances ───────────────────────────────────────
              Semantics(
                header: true,
                child: Text(
                  // Not "Benefits" -- the page heading is already that, and a
                  // section repeating its own page title names nothing.
                  'Benefit balances',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reimbursable balances from your plan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (!_walletLoaded)
                const _WalletSkeleton()
              else if (_wallet.isEmpty)
                _WalletEmpty()
              else
                ..._wallet.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaggeredReveal(
                      index: entry.key,
                      child: WalletPetCard(
                        wallet: entry.value,
                        showStats: true,
                        planType: _planTypeFor(entry.value.petId),
                        onPayInstalment: entry.value.isMonthly
                            ? () => context.read<MemberBloc>().add(
                                InstallmentRequested(entry.value.petId),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ── Actions ────────────────────────────────────────────────
              // Claims require a payout destination on file — gate submit
              // until the member sets one (the backend enforces this too).
              if (_member != null && !_member!.hasPayoutMethod) ...[
                _PayoutSetupCard(onSetup: _openPayoutSetup),
                const SizedBox(height: 10),
              ] else
                MpButton(
                  label: 'Submit a claim',
                  gold: true,
                  onPressed: () => _openReimbursements(1),
                ),
              const SizedBox(height: 10),
              MpButton(
                label: 'My claims',
                outlined: true,
                onPressed: () => _openReimbursements(0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Available-to-claim hero stat ────────────────────────────────────────────
//
// The one "shockingly large" element the page's typography mandate calls for
// — otherwise Benefits is just a stack of medium-sized cards with no anchor.
// Gold-accented because this is the member's own money: it earns the accent.

class _AvailableToClaimHero extends StatelessWidget {
  const _AvailableToClaimHero({required this.wallet});
  final List<WalletPet> wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final heroGold = isDark ? AppColors.gold : AppColors.goldDark;

    // Both pools count toward what the member can still claim back.
    final totalRemaining = wallet.fold<int>(
      0,
      (sum, c) => sum + c.remainingCentavos + c.emergencyRemainingCentavos,
    );
    final totalPending = wallet.fold<int>(
      0,
      (sum, c) => sum + c.pendingCentavos + c.emergencyPendingCentavos,
    );

    return Semantics(
      label:
          'Available to claim across all pets: '
          '${pesoFromCentavos(totalRemaining)}.'
          '${totalPending > 0 ? ' ${pesoFromCentavos(totalPending)} pending review.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE TO CLAIM',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          // The hero amount must stay one line and show every digit (hiding
          // peso digits with an ellipsis would misstate money), so scale it
          // down only when a very large multi-pet total would otherwise
          // overflow a narrow screen — the intended display size is preserved
          // whenever it fits.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              pesoFromCentavos(totalRemaining),
              maxLines: 1,
              style: theme.textTheme.displayMedium?.copyWith(
                color: heroGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // The number is a reimbursement cap, not cash on hand — say so, so
          // it isn't read as a withdrawable balance.
          Text(
            'Claim this back with receipts, across all your pets',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (totalPending > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${pesoFromCentavos(totalPending)} pending review',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Wallet loading skeleton ──────────────────────────────────────────────────

class _WalletSkeleton extends StatefulWidget {
  const _WalletSkeleton();

  @override
  State<_WalletSkeleton> createState() => _WalletSkeletonState();
}

class _WalletSkeletonState extends State<_WalletSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final blockColor = isDark ? AppDarkColors.elevated : AppColors.greyLight;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget row() => Container(
      height: 92,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Opacity(
          opacity: reduceMotion ? 0.6 : 0.45 + _pulse.value * 0.35,
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(children: [row(), const SizedBox(height: 10), row()]);
  }
}

// ── Payout setup prompt (gates claim submission) ────────────────────────────

class _PayoutSetupCard extends StatelessWidget {
  const _PayoutSetupCard({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // goldDark is tuned for light-gold surfaces; on darkGoldBg it fails
    // contrast — use raw gold in dark mode (same rule as WalletPetCard).
    final iconGold = theme.brightness == Brightness.dark
        ? AppColors.gold
        : AppColors.goldDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: iconGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set up your payout method first',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us where to send approved reimbursements: GCash, bank, '
            'or cash pickup. Takes a minute, one time only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          MpButton(
            label: 'Set up payout method',
            gold: true,
            onPressed: onSetup,
          ),
        ],
      ),
    );
  }
}

// ── Wallet empty ────────────────────────────────────────────────────────────

class _WalletEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: cs.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No reimbursable benefits yet. Activate a plan that includes '
              'reimbursement, or ask clinic staff for details.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

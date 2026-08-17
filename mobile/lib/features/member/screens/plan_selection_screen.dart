import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/pet.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/plan_quote.dart';
import '../../../core/widgets/agreement_checkbox.dart';
import '../../../core/widgets/cadence_toggle.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';

enum _ScreenState { loading, plans, polling, success, failure }

class PlanSelectionScreen extends StatefulWidget {
  final Pet pet;
  const PlanSelectionScreen({super.key, required this.pet});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  _ScreenState _screenState = _ScreenState.loading;
  List<Plan> _plans = [];
  Map<String, PlanQuote> _quotes = {};
  bool _paymentsEnabled = true;
  bool _isCheckoutLoading = false;

  /// Which price the member is looking at. Presentation state, like the
  /// selected plan — it only becomes real when checkout is dispatched.
  String _cadence = 'annual';
  Plan? _selectedPlan;
  String? _activePaymentId;
  Timer? _pollTimer;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    context.read<MemberBloc>().add(PlansLoadRequested(petId: widget.pet.id));
    _listenDeepLinks();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  void _listenDeepLinks() {
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      if (!mounted) return;
      if (uri.scheme == 'metropaws' && uri.host == 'payment') {
        final paymentId = uri.queryParameters['payment_id'];
        if (paymentId != null) {
          _stopPolling();
          context.read<MemberBloc>().add(PaymentStatusPolled(paymentId));
        }
      }
    });
  }

  void _startPolling(String paymentId) {
    _activePaymentId = paymentId;
    setState(() => _screenState = _ScreenState.polling);
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

  Future<void> _launchCheckout(String url, String paymentId) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) _startPolling(paymentId);
  }

  void _onSelectPlan(Plan plan) {
    setState(() => _selectedPlan = plan);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlanConfirmSheet(
        plan: plan,
        quote: _quotes[plan.id],
        cadence: _cadence,
        petName: widget.pet.name,
        onConfirm: () {
          Navigator.pop(ctx);
          context.read<MemberBloc>().add(
            CheckoutRequested(
              planId: plan.id,
              petId: widget.pet.id,
              cadence: _cadence,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<MemberBloc, MemberState>(
      listener: (context, state) {
        if (state is PlansLoaded) {
          setState(() {
            _plans = state.plans;
            _quotes = state.quotes;
            _paymentsEnabled = state.paymentsEnabled;
            _screenState = _ScreenState.plans;
          });
        } else if (state is CheckoutLoading) {
          setState(() => _isCheckoutLoading = true);
        } else if (state is CheckoutReady) {
          setState(() => _isCheckoutLoading = false);
          _launchCheckout(state.checkoutUrl, state.paymentId);
        } else if (state is CheckoutFailed) {
          setState(() {
            _isCheckoutLoading = false;
            _screenState = _ScreenState.plans;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: cs.error,
          ));
        } else if (state is PaymentVerified) {
          _stopPolling();
          setState(() => _screenState = _ScreenState.success);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.read<MemberBloc>().add(MemberLoadRequested());
              Navigator.pop(context);
            }
          });
        } else if (state is PaymentDeclined) {
          _stopPolling();
          setState(() => _screenState = _ScreenState.failure);
        } else if (state is MemberFailure && _screenState == _ScreenState.loading) {
          setState(() => _screenState = _ScreenState.plans);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Plans for ${_cap(widget.pet.name)}', style: tt.titleMedium),
        ),
        body: SafeArea(child: _buildBody(context, cs)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs) {
    switch (_screenState) {
      case _ScreenState.loading:
        return Center(child: CircularProgressIndicator(color: cs.primary));

      case _ScreenState.plans:
        return Stack(
          children: [
            _PlansBody(
              plans: _plans,
              quotes: _quotes,
              currentPlanType: widget.pet.planType,
              activeUntil: widget.pet.planActivatedAt
                  ?.add(const Duration(days: 365)),
              paymentsEnabled: _paymentsEnabled && !_isCheckoutLoading,
              onSelect: _onSelectPlan,
              cadence: _cadence,
              onCadenceChanged: (value) => setState(() => _cadence = value),
            ),
            if (_isCheckoutLoading)
              const ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),
          ],
        );

      case _ScreenState.polling:
        return _PollingBody(
          onCancel: () {
            _stopPolling();
            Navigator.pop(context);
          },
        );

      case _ScreenState.success:
        return _SuccessBody(planName: _selectedPlan?.name ?? 'membership');

      case _ScreenState.failure:
        return _FailureBody(
          onRetry: () {
            if (_selectedPlan != null) {
              context.read<MemberBloc>().add(
                CheckoutRequested(
                  planId: _selectedPlan!.id,
                  petId: widget.pet.id,
                  cadence: _cadence,
                ),
              );
            } else {
              setState(() => _screenState = _ScreenState.plans);
            }
          },
          onBack: () => setState(() => _screenState = _ScreenState.plans),
        );
    }
  }
}

// ── Plan list ─────────────────────────────────────────────────────────────

class _PlansBody extends StatelessWidget {
  final List<Plan> plans;
  final Map<String, PlanQuote> quotes;

  /// The pet's current plan name + computed term end (activated + 365d);
  /// both null for a plan-less pet. Display-only — eligibility comes from
  /// the server via each PlanQuote.
  final String? currentPlanType;
  final DateTime? activeUntil;
  final bool paymentsEnabled;
  final void Function(Plan) onSelect;
  final String cadence;
  final ValueChanged<String> onCadenceChanged;

  const _PlansBody({
    required this.plans,
    required this.quotes,
    required this.currentPlanType,
    required this.activeUntil,
    required this.paymentsEnabled,
    required this.onSelect,
    required this.cadence,
    required this.onCadenceChanged,
  });

  /// Only offer the choice when at least one visible plan actually has a
  /// monthly price — otherwise the toggle would switch to an option that
  /// changes nothing.
  bool get _anyMonthlyOffered =>
      _visiblePlans.any((p) => p.priceMonthly != null);

  /// Plans worth showing a card for: purchasable right now (eligible) or the
  /// pet's own current plan (shown for reference even though it's not
  /// re-buyable mid-term). Same/lower plans and usage-blocked upgrades are
  /// hidden rather than shown disabled — no quote (fetch failure) fails open.
  List<Plan> get _visiblePlans => plans.where((p) {
        final q = quotes[p.id];
        return q == null || q.eligible || q.isCurrent;
      }).toList();

  bool get _hiddenForBenefitsUsed =>
      plans.any((p) => quotes[p.id]?.eligibility == 'benefits_used');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!paymentsEnabled)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: cs.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Online payments are temporarily unavailable. Ask clinic staff to activate your plan in person.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          if (currentPlanType != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        children: [
                          const TextSpan(text: 'Current plan: '),
                          TextSpan(
                            text: currentPlanType,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (activeUntil != null)
                            TextSpan(
                              text: ' · active until ${_fmtDate(activeUntil!)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (plans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'No plans available at this time.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            // Ineligible plans (same/lower plan mid-term, or upgrade blocked
            // because this term's benefits are already in use) are hidden
            // entirely rather than shown disabled — the current plan's own
            // card always stays so the member can see what they have.
            if (_hiddenForBenefitsUsed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "This pet's benefits have already been used this year — "
                  'other plans become available again at renewal.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (_visiblePlans.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'No other plans available right now.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              if (_anyMonthlyOffered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CadenceToggle(
                    cadence: cadence,
                    onChanged: onCadenceChanged,
                  ),
                ),
              ..._visiblePlans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PlanCard(
                  plan: plan,
                  quote: quotes[plan.id],
                  paymentsEnabled: paymentsEnabled,
                  onSelect: () => onSelect(plan),
                  cadence: cadence,
                ),
              )),
            ],
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Secured by PayMongo',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  /// Server-computed Pack Discount quote for this plan; null = full price
  /// (no discount, or the quote fetch failed and we fall back gracefully).
  final PlanQuote? quote;
  final bool paymentsEnabled;
  final VoidCallback onSelect;

  /// 'annual' or 'monthly' — which price this card is quoting.
  final String cadence;

  const _PlanCard({
    required this.plan,
    required this.quote,
    required this.paymentsEnabled,
    required this.onSelect,
    required this.cadence,
  });

  /// True only when the member picked monthly AND this plan actually offers it.
  /// A plan with no monthly price always shows its annual figure rather than a
  /// blank one.
  bool get isMonthly => cadence == 'monthly' && plan.priceMonthly != null;

  /// CTA copy per upgrade/renewal state. 'lower_plan'/'benefits_used' never
  /// reach this card — _PlansBody hides those entirely rather than showing
  /// them disabled.
  String _ctaLabel() {
    if (!paymentsEnabled) return 'Unavailable';
    switch (quote?.eligibility ?? 'new') {
      case 'upgrade':
        return 'Upgrade to ${plan.name}';
      case 'renewal':
        return (quote?.isCurrent ?? false)
            ? 'Renew ${plan.name}'
            : 'Switch to ${plan.name}';
      case 'current_plan':
        return 'Current plan';
      default:
        return 'Select ${plan.name}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isFeatured = plan.isFeatured;

    // Upgrade/renewal state, mirrored from the server quote (display only —
    // checkout re-validates and 409s with a human message).
    final isCurrent = quote?.isCurrent ?? false;
    final selectable = quote?.eligible ?? true;

    final cardBg = isFeatured
        ? (isDark ? AppDarkColors.goldBg : AppColors.goldLight)
        : (isDark ? AppDarkColors.surface : AppColors.white);
    final borderColor = isFeatured
        ? AppColors.gold.withValues(alpha: 0.5)
        : (isDark ? AppDarkColors.border : AppColors.greyLight);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isFeatured ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(plan.name, style: tt.headlineSmall)),
                    // "Current plan" outranks "Popular" — a member looking at
                    // their own plan cares about that, not marketing.
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: Text(
                          'Current plan',
                          style: tt.labelSmall?.copyWith(
                            color: isDark ? AppColors.gold : AppColors.goldDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Popular',
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      // Pack Discount: struck-through full price ahead of the
                      // server-quoted final price. Never computed client-side.
                      // Instalments carry no discount — it is 15% off an ANNUAL
                      // plan — so the strike-through is annual-only.
                      if (!isMonthly && (quote?.hasDiscount ?? false))
                        TextSpan(
                          text: '₱${quote!.fullPhp}  ',
                          style: tt.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      TextSpan(
                        text: isMonthly
                            ? '₱${plan.priceMonthly}'
                            : '₱${quote?.finalPhp ?? plan.price}',
                        style: tt.displaySmall?.copyWith(
                          color: isFeatured ? AppColors.gold : cs.primary,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: isMonthly ? ' / month' : ' / year',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isMonthly) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Benefits unlock as you keep paying',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (!isMonthly && (quote?.hasDiscount ?? false)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${quote!.discountPercent}% Pack Discount · save ₱${quote!.discountPhp}',
                      style: tt.labelSmall?.copyWith(
                        color: isDark ? AppColors.gold : AppColors.goldDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                if (plan.tagline != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.tagline!,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (plan.features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...plan.features.take(5).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_rounded, size: 15, color: AppColors.gold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f, style: tt.bodyMedium)),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? AppDarkColors.border : AppColors.greyLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: (paymentsEnabled && selectable) ? onSelect : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFeatured ? AppColors.gold : AppColors.navy,
                      foregroundColor: isFeatured ? AppColors.text : AppColors.white,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      disabledBackgroundColor: cs.outline,
                    ),
                    child: Text(
                      _ctaLabel(),
                      style: tt.labelLarge?.copyWith(
                        color: (paymentsEnabled && selectable)
                            ? (isFeatured ? AppColors.text : AppColors.white)
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm bottom sheet ──────────────────────────────────────────────────

class _PlanConfirmSheet extends StatefulWidget {
  final Plan plan;

  /// Server-computed Pack Discount quote; null = full price.
  final PlanQuote? quote;
  final String petName;
  final VoidCallback onConfirm;
  final String cadence;

  const _PlanConfirmSheet({
    required this.plan,
    required this.quote,
    required this.petName,
    required this.onConfirm,
    required this.cadence,
  });

  @override
  State<_PlanConfirmSheet> createState() => _PlanConfirmSheetState();
}

class _PlanConfirmSheetState extends State<_PlanConfirmSheet> {
  // Pre-payment agreement gate — must be re-confirmed before money moves.
  bool _agreementAccepted = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final quote = widget.quote;
    // Monthly charges the instalment, never the discounted annual figure —
    // this number must match what the server is about to bill.
    final isMonthly =
        widget.cadence == 'monthly' && plan.priceMonthly != null;
    final payPhp =
        isMonthly ? plan.priceMonthly! : (quote?.finalPhp ?? plan.price);
    final petName = widget.petName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm plan for ${_cap(petName)}',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(plan.name, style: tt.headlineMedium),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        if (!isMonthly && (quote?.hasDiscount ?? false))
                          TextSpan(
                            text: '₱${quote!.fullPhp}  ',
                            style: tt.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        TextSpan(
                          text: '₱$payPhp',
                          style: tt.headlineSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: isMonthly ? ' / month' : ' / year',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!isMonthly && (quote?.hasDiscount ?? false)) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${quote!.discountPercent}% Pack Discount applied — you save ₱${quote.discountPhp}.',
                      style: tt.bodySmall?.copyWith(
                        color: isDark ? AppColors.gold : AppColors.goldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  // Monthly is not a cheaper way to buy the same thing, and the
                  // member must understand that before paying: this first
                  // payment opens the app, not the benefits.
                  if (isMonthly) ...[
                    const SizedBox(height: 10),
                    Text(
                      'This is the first of your monthly payments. It activates '
                      "${_cap(petName)}'s membership and app access — service "
                      'benefits open up as your payments continue, and you pay '
                      'each month from the app.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  // Replacement transparency: an upgrade/renewal wipes the old
                  // benefits ("no more, no less" than the new plan) — say so
                  // BEFORE money moves, not after.
                  if (quote?.eligibility == 'upgrade' ||
                      quote?.eligibility == 'renewal') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_cap(petName)}’s current benefits will be '
                        'replaced by this plan — the new plan year starts '
                        'today.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...plan.features.take(4).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.gold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f, style: tt.bodyMedium)),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 20),
                  AgreementCheckbox(
                    value: _agreementAccepted,
                    onChanged: (v) => setState(() => _agreementAccepted = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _agreementAccepted ? widget.onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.text,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: AppColors.text,
                      ),
                      // Scale the label down if the price + method string
                      // would otherwise overflow the button on a narrow screen
                      // at a large font scale, rather than clipping the CTA.
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pay ₱$payPhp',
                          maxLines: 1,
                          style: tt.labelLarge?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Secured by PayMongo · Annual membership, renews yearly.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Polling view ──────────────────────────────────────────────────────────

class _PollingBody extends StatelessWidget {
  final VoidCallback onCancel;
  const _PollingBody({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.secondary, strokeWidth: 3),
            const SizedBox(height: 32),
            Text(
              'Waiting for payment…',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete your payment in the browser, then return here.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  final String planName;
  const _SuccessBody({required this.planName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 36, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            Text('Plan activated!', style: tt.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your $planName plan is now active. Sessions will appear on your pet\'s card.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Failure view ──────────────────────────────────────────────────────────

class _FailureBody extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _FailureBody({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 36, color: cs.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment not completed',
              style: tt.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment was not completed or was declined. No charge was made.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Try again',
                  style: tt.labelLarge?.copyWith(color: AppColors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              child: const Text('Choose a different plan'),
            ),
          ],
        ),
      ),
    );
  }
}

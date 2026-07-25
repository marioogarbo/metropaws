import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/pet.dart';
import '../../../core/models/plan.dart';
import '../../../core/widgets/agreement_checkbox.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
  bool _paymentsEnabled = true;
  bool _isCheckoutLoading = false;
  Plan? _selectedPlan;
  String? _activePaymentId;
  Timer? _pollTimer;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    context.read<MemberBloc>().add(PlansLoadRequested());
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
        petName: widget.pet.name,
        onConfirm: () {
          Navigator.pop(ctx);
          context.read<MemberBloc>().add(
            CheckoutRequested(planId: plan.id, petId: widget.pet.id),
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
              paymentsEnabled: _paymentsEnabled && !_isCheckoutLoading,
              onSelect: _onSelectPlan,
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
  final bool paymentsEnabled;
  final void Function(Plan) onSelect;

  const _PlansBody({
    required this.plans,
    required this.paymentsEnabled,
    required this.onSelect,
  });

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
          else
            ...plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PlanCard(
                plan: plan,
                paymentsEnabled: paymentsEnabled,
                onSelect: () => onSelect(plan),
              ),
            )),
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
  final bool paymentsEnabled;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.paymentsEnabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isFeatured = plan.isFeatured;

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
                    if (isFeatured)
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
                      TextSpan(
                        text: '₱${plan.price}',
                        style: tt.displaySmall?.copyWith(
                          color: isFeatured ? AppColors.gold : cs.primary,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: ' / year',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
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
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: paymentsEnabled ? onSelect : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFeatured ? AppColors.gold : AppColors.navy,
                  foregroundColor: isFeatured ? AppColors.text : AppColors.white,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  disabledBackgroundColor: cs.outline,
                ),
                child: Text(
                  paymentsEnabled ? 'Select ${plan.name}' : 'Unavailable',
                  style: tt.labelLarge?.copyWith(
                    color: isFeatured ? AppColors.text : AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
  final String petName;
  final VoidCallback onConfirm;

  const _PlanConfirmSheet({
    required this.plan,
    required this.petName,
    required this.onConfirm,
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
                        TextSpan(
                          text: '₱${plan.price}',
                          style: tt.headlineSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' / year',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
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
                          'Pay ₱${plan.price}',
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

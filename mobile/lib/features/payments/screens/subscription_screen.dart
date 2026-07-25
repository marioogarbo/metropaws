import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/plan.dart';
import '../../../core/services/api_service.dart';
import '../../../theme.dart';
import '../bloc/payment_bloc.dart';
import '../bloc/payment_event.dart';
import '../bloc/payment_state.dart';
import '../payment_deep_link.dart';
import 'payment_result_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final String petId;
  const SubscriptionScreen({super.key, required this.petId});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Plan>? _plans;
  String? _loadError;
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final plans = await ApiService.fetchPlans();
      if (mounted) setState(() => _plans = plans);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load plans.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPrice(int p) {
    final s = p.toString();
    if (s.length <= 3) return '₱$s';
    final t = s.substring(0, s.length - 3);
    final h = s.substring(s.length - 3);
    return '₱$t,$h';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppDarkColors.bg : AppColors.surface;
    final textColor = isDark ? AppDarkColors.text : AppColors.text;

    return BlocProvider(
      create: (_) => PaymentBloc(),
      child: _DeepLinkListener(
        child: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) async {
          if (state is PaymentAwaitingProvider) {
            final uri = Uri.parse(state.checkoutUrl);
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open GCash. Please try again.'),
                ),
              );
            }
          } else if (state is PaymentSuccess) {
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PaymentResultScreen(
                  success: true,
                  paymentId: state.paymentId,
                ),
              ),
            );
          } else if (state is PaymentFailure) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final busy = state is PaymentLoading ||
              state is PaymentAwaitingProvider ||
              state is PaymentVerifying;
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              title: Text(
                'Membership',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              backgroundColor: bg,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
            ),
            body: SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.navy),
                    )
                  : _loadError != null
                      ? _ErrorState(message: _loadError!, onRetry: _loadPlans)
                      : _PlansList(
                          plans: _plans!,
                          selectedId: _selectedId,
                          onSelect: (id) => setState(() => _selectedId = id),
                          formatPrice: _formatPrice,
                          textColor: textColor,
                          isDark: isDark,
                        ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_selectedId == null || busy)
                        ? null
                        : () {
                            context
                                .read<PaymentBloc>()
                                .add(CheckoutStarted(_selectedId!, widget.petId));
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.text,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.navy,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            state is PaymentVerifying
                                ? 'Confirming…'
                                : 'Pay with GCash',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _DeepLinkListener extends StatefulWidget {
  final Widget child;
  const _DeepLinkListener({required this.child});

  @override
  State<_DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<_DeepLinkListener> {
  StreamSubscription<PaymentDeepLinkEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = PaymentDeepLinkChannel.stream.listen((event) {
      if (!mounted) return;
      context.read<PaymentBloc>().add(
            PaymentReturned(
              paymentId: event.paymentId,
              success: event.success,
            ),
          );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PlansList extends StatelessWidget {
  final List<Plan> plans;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String Function(int) formatPrice;
  final Color textColor;
  final bool isDark;

  const _PlansList({
    required this.plans,
    required this.selectedId,
    required this.onSelect,
    required this.formatPrice,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final plan = plans[i];
        final selected = plan.id == selectedId;
        final cardBg = isDark ? AppDarkColors.surface : Colors.white;
        return InkWell(
          onTap: () => onSelect(plan.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.greyLight,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.subtitle.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatPrice(plan.price),
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                if (plan.tagline != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.tagline!,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: AppColors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/api_service.dart';
import 'payment_event.dart';
import 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc() : super(PaymentInitial()) {
    on<CheckoutStarted>(_onCheckoutStarted);
    on<PaymentReturned>(_onPaymentReturned);
    on<PaymentStatusPolled>(_onPaymentStatusPolled);
    on<PaymentReset>((_, emit) => emit(PaymentInitial()));
  }

  Future<void> _onCheckoutStarted(
    CheckoutStarted event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final res = await ApiService.createCheckout(event.planId, event.petId);
      emit(PaymentAwaitingProvider(
        paymentId: res.paymentId,
        checkoutUrl: res.checkoutUrl,
      ));
    } on ApiException catch (e) {
      emit(PaymentFailure(e.message));
    } catch (_) {
      emit(PaymentFailure('Could not start payment. Please try again.'));
    }
  }

  Future<void> _onPaymentReturned(
    PaymentReturned event,
    Emitter<PaymentState> emit,
  ) async {
    if (!event.success) {
      emit(PaymentFailure('Payment was cancelled or failed.'));
      return;
    }
    emit(PaymentVerifying(event.paymentId));
    await _pollUntilResolved(event.paymentId, emit);
  }

  Future<void> _onPaymentStatusPolled(
    PaymentStatusPolled event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentVerifying(event.paymentId));
    await _pollUntilResolved(event.paymentId, emit);
  }

  Future<void> _pollUntilResolved(
    String paymentId,
    Emitter<PaymentState> emit,
  ) async {
    // Webhook from PayMongo may lag a few seconds behind the deep-link return.
    // Poll up to ~30s before giving up.
    const maxAttempts = 15;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final payment = await ApiService.getPayment(paymentId);
        if (payment.isPaid) {
          emit(PaymentSuccess(paymentId));
          return;
        }
        if (payment.isFailed) {
          emit(PaymentFailure('Payment did not complete.'));
          return;
        }
      } on ApiException catch (e) {
        emit(PaymentFailure(e.message));
        return;
      } catch (_) {
        // transient — keep polling
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    emit(PaymentFailure(
      'Still waiting for confirmation. Pull to refresh from your dashboard in a minute.',
    ));
  }
}

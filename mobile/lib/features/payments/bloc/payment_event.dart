abstract class PaymentEvent {}

class CheckoutStarted extends PaymentEvent {
  final String planId;
  final String petId;
  CheckoutStarted(this.planId, this.petId);
}

class PaymentReturned extends PaymentEvent {
  final String paymentId;
  final bool success;
  PaymentReturned({required this.paymentId, required this.success});
}

class PaymentStatusPolled extends PaymentEvent {
  final String paymentId;
  PaymentStatusPolled(this.paymentId);
}

class PaymentReset extends PaymentEvent {}

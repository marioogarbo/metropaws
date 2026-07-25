abstract class PaymentState {}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentAwaitingProvider extends PaymentState {
  final String paymentId;
  final String checkoutUrl;
  PaymentAwaitingProvider({required this.paymentId, required this.checkoutUrl});
}

class PaymentVerifying extends PaymentState {
  final String paymentId;
  PaymentVerifying(this.paymentId);
}

class PaymentSuccess extends PaymentState {
  final String paymentId;
  PaymentSuccess(this.paymentId);
}

class PaymentFailure extends PaymentState {
  final String message;
  PaymentFailure(this.message);
}

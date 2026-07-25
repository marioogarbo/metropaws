import 'dart:async';

class PaymentDeepLinkEvent {
  final String paymentId;
  final bool success;
  const PaymentDeepLinkEvent({required this.paymentId, required this.success});
}

class PaymentDeepLinkChannel {
  static final _controller =
      StreamController<PaymentDeepLinkEvent>.broadcast();

  static Stream<PaymentDeepLinkEvent> get stream => _controller.stream;

  /// Parse a `metropaws://payment/success?payment_id=...` URI and
  /// emit it. Returns true if the URI matched the payment scheme.
  static bool tryHandle(Uri uri) {
    if (uri.scheme != 'metropaws' || uri.host != 'payment') return false;
    final paymentId = uri.queryParameters['payment_id'];
    if (paymentId == null) return false;
    final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final success = path == 'success';
    _controller.add(
      PaymentDeepLinkEvent(paymentId: paymentId, success: success),
    );
    return true;
  }
}

class CheckoutResponse {
  final String paymentId;
  final String checkoutUrl;

  const CheckoutResponse({required this.paymentId, required this.checkoutUrl});

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) =>
      CheckoutResponse(
        paymentId: json['payment_id'] as String,
        checkoutUrl: json['checkout_url'] as String,
      );
}

class PaymentRecord {
  final String id;
  final String planId;
  final int amountPhp;
  final String currency;
  final String status;

  const PaymentRecord({
    required this.id,
    required this.planId,
    required this.amountPhp,
    required this.currency,
    required this.status,
  });

  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed' || status == 'expired';
  bool get isPending => status == 'pending';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String,
        planId: json['plan_id'] as String,
        amountPhp: json['amount_php'] as int,
        currency: json['currency'] as String,
        status: json['status'] as String,
      );
}

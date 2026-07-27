/// Member-specific price for one plan from `GET /payments/quotes` — the Pack
/// Discount (15% off the 2nd/3rd pet's cheaper plan) computed SERVER-SIDE.
/// The app only displays these; it never derives a price itself. Whole pesos,
/// matching the payments money unit (NOT the centavos used by reimbursements).
class PlanQuote {
  final String planId;
  final int fullPhp;
  final int discountPhp;
  final int finalPhp;
  final int discountPercent;

  const PlanQuote({
    required this.planId,
    required this.fullPhp,
    required this.discountPhp,
    required this.finalPhp,
    required this.discountPercent,
  });

  bool get hasDiscount => discountPhp > 0;

  factory PlanQuote.fromJson(Map<String, dynamic> json) => PlanQuote(
        planId: json['plan_id'] as String,
        fullPhp: json['full_php'] as int,
        discountPhp: json['discount_php'] as int,
        finalPhp: json['final_php'] as int,
        discountPercent: json['discount_percent'] as int,
      );
}

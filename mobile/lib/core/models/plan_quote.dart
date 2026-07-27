/// Member-specific price for one plan from `GET /payments/quotes` — the Pack
/// Discount (15% off the 2nd/3rd pet's cheaper plan) computed SERVER-SIDE.
/// The app only displays these; it never derives a price itself. Whole pesos,
/// matching the payments money unit (NOT the centavos used by reimbursements).
///
/// [eligibility] mirrors the backend upgrade/renewal rules for the pet passed
/// to the quotes call: allowed codes `new` / `upgrade` / `renewal`, blocked
/// codes `current_plan` / `lower_plan` / `benefits_used`. Display-only — the
/// checkout re-validates server-side and 409s with a human message.
class PlanQuote {
  final String planId;
  final int fullPhp;
  final int discountPhp;
  final int finalPhp;
  final int discountPercent;
  final bool eligible;
  final String eligibility;
  final bool isCurrent;

  const PlanQuote({
    required this.planId,
    required this.fullPhp,
    required this.discountPhp,
    required this.finalPhp,
    required this.discountPercent,
    this.eligible = true,
    this.eligibility = 'new',
    this.isCurrent = false,
  });

  bool get hasDiscount => discountPhp > 0;

  factory PlanQuote.fromJson(Map<String, dynamic> json) => PlanQuote(
        planId: json['plan_id'] as String,
        fullPhp: json['full_php'] as int,
        discountPhp: json['discount_php'] as int,
        finalPhp: json['final_php'] as int,
        discountPercent: json['discount_percent'] as int,
        // Tolerant defaults: an older backend without these keys behaves like
        // today (everything selectable; server still enforces).
        eligible: (json['eligible'] as bool?) ?? true,
        eligibility: (json['eligibility'] as String?) ?? 'new',
        isCurrent: (json['is_current'] as bool?) ?? false,
      );
}

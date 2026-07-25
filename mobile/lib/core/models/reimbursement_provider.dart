/// A verified clinic/groomer members can pick when filing a "pay the provider
/// directly" claim (see Reimbursement.payoutTarget). Brief shape only — payout
/// details are never sent to the app, they're admin/backend-only.
class ReimbursementProvider {
  final String id;
  final String name;
  final String? category;

  const ReimbursementProvider({
    required this.id,
    required this.name,
    this.category,
  });

  factory ReimbursementProvider.fromJson(Map<String, dynamic> json) =>
      ReimbursementProvider(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
      );
}

import 'pet.dart';
import 'member_service.dart';

class Member {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? address;
  final String? photoUrl;
  final String? planType;
  final String? payoutMethod; // 'gcash' | 'bank'
  final String? payoutAccountName;
  final String? payoutAccountNumber;
  final String? payoutBankName;
  final String qrToken;
  final bool isFoundingMember;
  final String? previousPlanTier;
  final String? memberId;
  final DateTime joinedAt;
  final List<Pet> pets;
  final List<MemberService> services;

  const Member({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.address,
    this.photoUrl,
    this.planType,
    this.payoutMethod,
    this.payoutAccountName,
    this.payoutAccountNumber,
    this.payoutBankName,
    required this.qrToken,
    this.isFoundingMember = false,
    this.previousPlanTier,
    this.memberId,
    required this.joinedAt,
    required this.pets,
    required this.services,
  });

  bool get discountEligible =>
      previousPlanTier == 'Deluxe' || previousPlanTier == 'Premium';

  String get fullName => '$firstName $lastName';

  bool get hasPayoutMethod =>
      (payoutMethod ?? '').isNotEmpty &&
      (payoutMethod == 'cash' || (payoutAccountNumber ?? '').isNotEmpty);

  Member withMemberId(String? id) => Member(
    id: this.id,
    userId: userId,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    address: address,
    photoUrl: photoUrl,
    planType: planType,
    payoutMethod: payoutMethod,
    payoutAccountName: payoutAccountName,
    payoutAccountNumber: payoutAccountNumber,
    payoutBankName: payoutBankName,
    qrToken: qrToken,
    isFoundingMember: isFoundingMember,
    previousPlanTier: previousPlanTier,
    memberId: id,
    joinedAt: joinedAt,
    pets: pets,
    services: services,
  );

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    photoUrl: json['photo_url'] as String?,
    planType: json['plan_type'] as String?,
    payoutMethod: json['payout_method'] as String?,
    payoutAccountName: json['payout_account_name'] as String?,
    payoutAccountNumber: json['payout_account_number'] as String?,
    payoutBankName: json['payout_bank_name'] as String?,
    qrToken: json['qr_token'] as String,
    isFoundingMember: (json['is_founding'] as bool?) ?? false,
    previousPlanTier: json['previous_plan_tier'] as String?,
    memberId: json['member_id'] as String?,
    joinedAt: DateTime.parse(json['joined_at'] as String),
    pets: (json['pets'] as List<dynamic>? ?? [])
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList(),
    services: (json['services'] as List<dynamic>? ?? [])
        .map((e) => MemberService.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

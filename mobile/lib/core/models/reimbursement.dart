import 'service_type.dart';

/// Formats integer centavos as a peso string, e.g. 52375 -> "₱523.75".
String pesoFromCentavos(int centavos) {
  final pesos = centavos / 100;
  final fixed = pesos.toStringAsFixed(2);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱${negative ? '-' : ''}$buf.${parts[1]}';
}

/// One pet's Benefit Wallet — TWO pools per plan. Non-emergency claims draw from
/// the Preventive Wellness pool (`wallet*`); "Emergency"-category claims draw
/// from the Emergency pool (`emergency*`). A pool with a 0 total isn't offered.
class WalletPet {
  final String petId;
  final String petName;
  // Preventive Wellness Wallet
  final int walletCentavos; // the plan's annual preventive pool
  final int pendingCentavos; // claimed amounts awaiting a decision
  final int usedCentavos; // approved + paid
  final int remainingCentavos; // max(0, wallet - used - pending)
  // Emergency Wallet
  final int emergencyWalletCentavos;
  final int emergencyPendingCentavos;
  final int emergencyUsedCentavos;
  final int emergencyRemainingCentavos;
  // Plan term: 'active' | 'renewal_window' | 'expired'. Expired pets can't
  // file new claims until renewed (server 400s; the app gates the Submit tab).
  final String planStatus;
  final DateTime? planExpiresAt;
  // Agreement §5.7 membership status. `membershipStatus` is the stable wire
  // value to branch on; `membershipStatusLabel` is the contract's own wording,
  // sent by the server so the app never hardcodes a phrase only the document
  // may change. Older backends omit both — the defaults match how an annual
  // member has always behaved.
  final String membershipStatus;
  final String membershipStatusLabel;
  // Monthly subscribers only. Both stay empty for annual members.
  final DateTime? subscriptionNextDueOn;
  final int subscriptionPaymentsMade;
  // Whether each pool may actually be drawn on right now. Always true for an
  // annual member; false while a monthly subscriber is vesting or in default.
  // Defaults are true so an older backend behaves exactly as before.
  final bool preventiveAvailable;
  final bool emergencyAvailable;

  const WalletPet({
    required this.petId,
    required this.petName,
    required this.walletCentavos,
    required this.pendingCentavos,
    required this.usedCentavos,
    required this.remainingCentavos,
    this.emergencyWalletCentavos = 0,
    this.emergencyPendingCentavos = 0,
    this.emergencyUsedCentavos = 0,
    this.emergencyRemainingCentavos = 0,
    this.planStatus = 'active',
    this.planExpiresAt,
    this.membershipStatus = 'fully_service_eligible',
    this.membershipStatusLabel = 'Fully Service-Eligible',
    this.subscriptionNextDueOn,
    this.subscriptionPaymentsMade = 0,
    this.preventiveAvailable = true,
    this.emergencyAvailable = true,
  });

  bool get planExpired => planStatus == 'expired';

  /// Whether this pet's plan is paid monthly rather than annually.
  ///
  /// Keyed on the payment count because the wallet only ever lists pets that
  /// already hold a plan, and a plan is granted by the FIRST cleared instalment
  /// — so inside this payload "has paid at least once" and "is a subscriber"
  /// are the same set. A pet still awaiting its first instalment has no plan
  /// yet and never reaches here.
  bool get isMonthly => subscriptionPaymentsMade > 0;

  /// Benefits are withheld right now — either vesting is incomplete or an
  /// instalment is overdue. The server refuses the claim either way; this only
  /// decides whether to explain that before the member tries.
  bool get benefitsWithheld =>
      membershipStatus == 'digital_access_active' ||
      membershipStatus == 'vesting_in_progress' ||
      membershipStatus == 'suspended';

  factory WalletPet.fromJson(Map<String, dynamic> json) => WalletPet(
        petId: json['pet_id'] as String,
        petName: json['pet_name'] as String,
        walletCentavos: json['wallet_centavos'] as int? ?? 0,
        pendingCentavos: json['pending_centavos'] as int? ?? 0,
        usedCentavos: json['used_centavos'] as int? ?? 0,
        remainingCentavos: json['remaining_centavos'] as int? ?? 0,
        emergencyWalletCentavos: json['emergency_wallet_centavos'] as int? ?? 0,
        emergencyPendingCentavos: json['emergency_pending_centavos'] as int? ?? 0,
        emergencyUsedCentavos: json['emergency_used_centavos'] as int? ?? 0,
        emergencyRemainingCentavos:
            json['emergency_remaining_centavos'] as int? ?? 0,
        planStatus: json['plan_status'] as String? ?? 'active',
        planExpiresAt: json['plan_expires_at'] != null
            ? DateTime.tryParse(json['plan_expires_at'] as String)
            : null,
        membershipStatus:
            json['membership_status'] as String? ?? 'fully_service_eligible',
        membershipStatusLabel:
            json['membership_status_label'] as String? ?? 'Fully Service-Eligible',
        subscriptionNextDueOn: json['subscription_next_due_on'] != null
            ? DateTime.tryParse(json['subscription_next_due_on'] as String)
            : null,
        subscriptionPaymentsMade:
            json['subscription_payments_made'] as int? ?? 0,
        preventiveAvailable: json['preventive_available'] as bool? ?? true,
        emergencyAvailable: json['emergency_available'] as bool? ?? true,
      );
}

/// The `/members/me/wallet` payload: per-pet pools plus the service categories
/// a claim can be filed under (labels only — no per-category budget).
class Wallet {
  final List<WalletPet> pets;
  final List<ServiceType> serviceTypes;

  /// Whether THIS member may file a direct-to-provider request — the global
  /// setting already resolved against their per-member override, server-side.
  ///
  /// Null when the backend predates the per-member override: that build has no
  /// such field, so callers fall back to the global flag from
  /// /settings/mobile-config. Deliberately not defaulted to false — that would
  /// hide the option for everyone the moment the app shipped ahead of the API.
  final bool? directPayAvailable;

  const Wallet({
    this.pets = const [],
    this.serviceTypes = const [],
    this.directPayAvailable,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        pets: (json['pets'] as List<dynamic>? ?? [])
            .map((e) => WalletPet.fromJson(e as Map<String, dynamic>))
            .toList(),
        serviceTypes: (json['service_types'] as List<dynamic>? ?? [])
            .map((e) => ServiceType.fromJson(e as Map<String, dynamic>))
            .toList(),
        directPayAvailable: json['direct_pay_available'] as bool?,
      );
}

/// A reimbursement claim and its current status.
class Reimbursement {
  final String id;
  final String petId;
  final ServiceType serviceType;
  final String providerName;
  final DateTime serviceDate;
  final int claimedAmountCentavos;
  final int? approvedAmountCentavos;
  final String receiptUrl;
  final String? receiptReference;
  final String? memberNotes;
  final String status;
  final String? adminNotes;
  final DateTime? reviewedAt;
  final DateTime? paidAt;
  // 'member' (default, existing flow) or 'provider' (MetroPaws pays the
  // provider directly — see ReimbursementProvider). Defaults to 'member' when
  // absent so older cached payloads still parse.
  final String payoutTarget;
  final String? providerId;
  final DateTime createdAt;

  const Reimbursement({
    required this.id,
    required this.petId,
    required this.serviceType,
    required this.providerName,
    required this.serviceDate,
    required this.claimedAmountCentavos,
    this.approvedAmountCentavos,
    required this.receiptUrl,
    this.receiptReference,
    this.memberNotes,
    required this.status,
    this.adminNotes,
    this.reviewedAt,
    this.paidAt,
    this.payoutTarget = 'member',
    this.providerId,
    required this.createdAt,
  });

  bool get isProviderTarget => payoutTarget == 'provider';

  bool get needsInfo => status == 'needs_info';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under review';
      case 'needs_info':
        return 'Needs info';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'paid':
        return 'Paid';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  factory Reimbursement.fromJson(Map<String, dynamic> json) => Reimbursement(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        serviceType:
            ServiceType.fromJson(json['service_type'] as Map<String, dynamic>),
        providerName: json['provider_name'] as String,
        serviceDate: DateTime.parse(json['service_date'] as String),
        claimedAmountCentavos: json['claimed_amount_centavos'] as int,
        approvedAmountCentavos: json['approved_amount_centavos'] as int?,
        receiptUrl: json['receipt_url'] as String,
        receiptReference: json['receipt_reference'] as String?,
        memberNotes: json['member_notes'] as String?,
        status: json['status'] as String,
        adminNotes: json['admin_notes'] as String?,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'] as String)
            : null,
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'] as String)
            : null,
        payoutTarget: json['payout_target'] as String? ?? 'member',
        providerId: json['provider_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

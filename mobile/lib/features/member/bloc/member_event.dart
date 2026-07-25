abstract class MemberEvent {}

class MemberLoadRequested extends MemberEvent {}

class ProfilePhotoUpdateRequested extends MemberEvent {
  final List<int> photoBytes;
  final String photoExt;

  ProfilePhotoUpdateRequested({required this.photoBytes, required this.photoExt});
}

class PetUpdateRequested extends MemberEvent {
  final String petId;
  final String name;
  final String? species;
  final String? breed;
  final int? birthMonth;
  final int? birthYear;
  final int? birthDay;
  final double? weightKg;
  final String? sex;
  final String? notes;
  final List<int>? photoBytes;
  final String? photoExt;

  PetUpdateRequested({
    required this.petId,
    required this.name,
    this.species,
    this.breed,
    this.birthMonth,
    this.birthYear,
    this.birthDay,
    this.weightKg,
    this.sex,
    this.notes,
    this.photoBytes,
    this.photoExt,
  });
}

class PetDeleteRequested extends MemberEvent {
  final String petId;
  PetDeleteRequested(this.petId);
}

class BookingsLoadRequested extends MemberEvent {}

class BookingRequested extends MemberEvent {
  final String serviceTypeId;
  final String clinicId;
  final DateTime bookingDate;
  final String timeSlot;
  final String? notes;

  BookingRequested({
    required this.serviceTypeId,
    required this.clinicId,
    required this.bookingDate,
    required this.timeSlot,
    this.notes,
  });
}

class BookingCancelRequested extends MemberEvent {
  final String bookingId;
  BookingCancelRequested(this.bookingId);
}

class PawPointsLoadRequested extends MemberEvent {}

class PawPointsBalanceLoadRequested extends MemberEvent {}

class PlansLoadRequested extends MemberEvent {}

class CheckoutRequested extends MemberEvent {
  final String planId;
  final String petId;
  CheckoutRequested({required this.planId, required this.petId});
}

class PaymentStatusPolled extends MemberEvent {
  final String paymentId;
  PaymentStatusPolled(this.paymentId);
}

class ReimbursementsLoadRequested extends MemberEvent {}

class ReimbursementSubmitted extends MemberEvent {
  final String petId;
  final String serviceTypeId;
  final String providerName;
  final DateTime serviceDate;
  final int claimedAmountCentavos;
  final String? receiptReference;
  final String? memberNotes;
  final List<int> receiptBytes;
  final String receiptExt;
  // 'member' (default, reimburse the member) or 'provider' (MetroPaws pays
  // providerId directly) — see Reimbursement.payoutTarget.
  final String payoutTarget;
  final String? providerId;

  ReimbursementSubmitted({
    required this.petId,
    required this.serviceTypeId,
    required this.providerName,
    required this.serviceDate,
    required this.claimedAmountCentavos,
    this.receiptReference,
    this.memberNotes,
    required this.receiptBytes,
    required this.receiptExt,
    this.payoutTarget = 'member',
    this.providerId,
  });
}

class ReimbursementResubmitted extends MemberEvent {
  final String id;
  final List<int>? receiptBytes;
  final String? receiptExt;
  final String? memberNotes;
  // Full-edit resubmit: a needs_info complaint may be about the amount,
  // provider, or date — not just receipt legibility — so all claim fields
  // are correctable, matching what the backend endpoint already accepts.
  final String? providerName;
  final DateTime? serviceDate;
  final int? claimedAmountCentavos;

  ReimbursementResubmitted({
    required this.id,
    this.receiptBytes,
    this.receiptExt,
    this.memberNotes,
    this.providerName,
    this.serviceDate,
    this.claimedAmountCentavos,
  });
}

class NotificationsLoadRequested extends MemberEvent {}

class NotificationsCountRequested extends MemberEvent {}

class NotificationReadRequested extends MemberEvent {
  final String id;
  NotificationReadRequested(this.id);
}

class NotificationsReadAllRequested extends MemberEvent {}

/// Fetch the startup feature flags (currently just booking_enabled — the Book
/// tab is on standby until partner clinics exist).
class MobileConfigRequested extends MemberEvent {}

class PromosLoadRequested extends MemberEvent {}

class PayoutDetailsSubmitted extends MemberEvent {
  final String method; // 'gcash' | 'bank'
  final String accountName;
  final String accountNumber;
  final String? bankName;

  PayoutDetailsSubmitted({
    required this.method,
    required this.accountName,
    required this.accountNumber,
    this.bankName,
  });
}

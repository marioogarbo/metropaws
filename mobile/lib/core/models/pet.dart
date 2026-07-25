import 'service_type.dart';

class PetService {
  final String id;
  final ServiceType serviceType;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;
  final DateTime? expiresAt;

  const PetService({
    required this.id,
    required this.serviceType,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
    this.expiresAt,
  });

  factory PetService.fromJson(Map<String, dynamic> json) => PetService(
        id: json['id'] as String,
        serviceType: ServiceType.fromJson(json['service_type'] as Map<String, dynamic>),
        totalSessions: json['total_sessions'] as int,
        usedSessions: json['used_sessions'] as int,
        remainingSessions: json['remaining_sessions'] as int,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
      );
}

/// One of the optional identity-photo slots a member can add after
/// registration to complete their pet's verified profile.
class PetPhotoSlot {
  final String field;
  final String label;
  final String hint;

  const PetPhotoSlot({
    required this.field,
    required this.label,
    required this.hint,
  });
}

/// One identity photo already uploaded, for display in a gallery — pairs a
/// human label with its URL, unlike [PetPhotoSlot] which describes a slot
/// still waiting to be filled.
class PetPhoto {
  final String label;
  final String url;

  const PetPhoto({required this.label, required this.url});
}

class Pet {
  final String id;
  final String name;
  final String? species;
  final String? breed;
  final int? birthMonth;
  final int? birthYear;
  final int? birthDay;
  final double? weightKg;
  final String? photoUrl;
  final String? vaxCardUrl;
  final String? sex;
  final String? notes;
  final String? planId;
  final String? planType;
  final DateTime? planActivatedAt;
  final DateTime createdAt;
  final List<PetService> petServices;

  // Identity photos (MP-FRM-PET-001) — photoUrl above is slot 1 (front face).
  final String? photoFullBodyUrl;
  final String? photoWithOwnerUrl;
  final String? photoLeftProfileUrl;
  final String? photoRightProfileUrl;
  final String? photoRearUrl;
  final String? photoTopUrl;
  final String? photoWithIdCardUrl;
  final bool isProfileVerified;

  const Pet({
    required this.id,
    required this.name,
    this.species,
    this.breed,
    this.birthMonth,
    this.birthYear,
    this.birthDay,
    this.weightKg,
    this.photoUrl,
    this.vaxCardUrl,
    this.sex,
    this.notes,
    this.planId,
    this.planType,
    this.planActivatedAt,
    required this.createdAt,
    this.petServices = const [],
    this.photoFullBodyUrl,
    this.photoWithOwnerUrl,
    this.photoLeftProfileUrl,
    this.photoRightProfileUrl,
    this.photoRearUrl,
    this.photoTopUrl,
    this.photoWithIdCardUrl,
    this.isProfileVerified = false,
  });

  /// Every identity-photo slot still missing, in the order it should be
  /// presented for the member to complete their pet's profile. Hints are
  /// written as instructions to follow while taking the photo, not as
  /// checklist fragments copied from the printed standard.
  ///
  /// The 3 photos captured at registration (front face, full body, with owner)
  /// are normally always present, so this list is usually just the 5 optional
  /// angles. But they CAN go missing — e.g. their files were lost and the dead
  /// URLs nulled server-side — so they're listed here too when null, giving the
  /// member a re-upload path and keeping the "N of 8" progress honest (the
  /// progress bar derives completed = 8 − remainingPhotoSlots.length, so a slot
  /// omitted here is silently counted as done whether it exists or not).
  /// Field names match the backend PUT /pets/{id} form fields exactly.
  List<PetPhotoSlot> get remainingPhotoSlots => [
    if (photoUrl == null)
      const PetPhotoSlot(
        field: 'photo',
        label: 'Front face',
        hint: 'A clear, front-on look at their face',
      ),
    if (photoFullBodyUrl == null)
      const PetPhotoSlot(
        field: 'photo_full_body',
        label: 'Full body',
        hint: 'Their whole body from the side, standing',
      ),
    if (photoWithOwnerUrl == null)
      const PetPhotoSlot(
        field: 'photo_with_owner',
        label: 'With owner',
        hint: 'You and your pet together in one shot',
      ),
    if (photoLeftProfileUrl == null)
      const PetPhotoSlot(
        field: 'photo_left_profile',
        label: 'Left profile',
        hint: 'Show their full side profile, facing left',
      ),
    if (photoRightProfileUrl == null)
      const PetPhotoSlot(
        field: 'photo_right_profile',
        label: 'Right profile',
        hint: 'Show their full side profile, facing right',
      ),
    if (photoRearUrl == null)
      const PetPhotoSlot(
        field: 'photo_rear',
        label: 'Rear view',
        hint: 'Capture the tail and any markings from behind',
      ),
    if (photoTopUrl == null)
      const PetPhotoSlot(
        field: 'photo_top',
        label: 'Top view',
        hint: 'Shoot from above to show their back and build',
      ),
    if (photoWithIdCardUrl == null)
      const PetPhotoSlot(
        field: 'photo_with_id_card',
        label: 'Pet with ID card',
        hint: 'Hold their Digital Pawprint QR card next to them',
      ),
  ];

  /// All identity photos actually on file (MP-FRM-PET-001), in slot order —
  /// the 3 required at registration plus any optional ones added since. The
  /// pet's hero photo only ever shows the front face, so this is the only
  /// place the other required photos (full body, with owner) are reachable.
  List<PetPhoto> get uploadedPhotos => [
    if (photoUrl != null) PetPhoto(label: 'Front face', url: photoUrl!),
    if (photoFullBodyUrl != null)
      PetPhoto(label: 'Full body', url: photoFullBodyUrl!),
    if (photoWithOwnerUrl != null)
      PetPhoto(label: 'With owner', url: photoWithOwnerUrl!),
    if (photoLeftProfileUrl != null)
      PetPhoto(label: 'Left profile', url: photoLeftProfileUrl!),
    if (photoRightProfileUrl != null)
      PetPhoto(label: 'Right profile', url: photoRightProfileUrl!),
    if (photoRearUrl != null) PetPhoto(label: 'Rear view', url: photoRearUrl!),
    if (photoTopUrl != null) PetPhoto(label: 'Top view', url: photoTopUrl!),
    if (photoWithIdCardUrl != null)
      PetPhoto(label: 'Pet with ID card', url: photoWithIdCardUrl!),
  ];

  bool get hasActivePlan => planId != null;

  int? get computedAge {
    if (birthMonth == null || birthYear == null) return null;
    final now = DateTime.now();
    int years = now.year - birthYear!;
    if (now.month < birthMonth! ||
        (now.month == birthMonth! && birthDay != null && now.day < birthDay!)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  /// Total whole months since birth. Used to show "4 months" instead of the
  /// confusing "0 years" for pets under a year old.
  int? get computedAgeMonths {
    if (birthMonth == null || birthYear == null) return null;
    final now = DateTime.now();
    int months = (now.year - birthYear!) * 12 + (now.month - birthMonth!);
    if (birthDay != null && now.day < birthDay!) months--;
    return months < 0 ? 0 : months;
  }

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
    id: json['id'] as String,
    name: json['name'] as String,
    species: json['species'] as String?,
    breed: json['breed'] as String?,
    birthMonth: json['birth_month'] as int?,
    birthYear: json['birth_year'] as int?,
    birthDay: json['birth_day'] as int?,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    photoUrl: json['photo_url'] as String?,
    vaxCardUrl: json['vax_card_url'] as String?,
    sex: json['sex'] as String?,
    notes: json['notes'] as String?,
    planId: json['plan_id'] as String?,
    planType: json['plan_type'] as String?,
    planActivatedAt: json['plan_activated_at'] != null
        ? DateTime.parse(json['plan_activated_at'] as String)
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    petServices: (json['pet_services'] as List<dynamic>? ?? [])
        .map((e) => PetService.fromJson(e as Map<String, dynamic>))
        .toList(),
    photoFullBodyUrl: json['photo_full_body_url'] as String?,
    photoWithOwnerUrl: json['photo_with_owner_url'] as String?,
    photoLeftProfileUrl: json['photo_left_profile_url'] as String?,
    photoRightProfileUrl: json['photo_right_profile_url'] as String?,
    photoRearUrl: json['photo_rear_url'] as String?,
    photoTopUrl: json['photo_top_url'] as String?,
    photoWithIdCardUrl: json['photo_with_id_card_url'] as String?,
    isProfileVerified: json['is_profile_verified'] as bool? ?? false,
  );
}

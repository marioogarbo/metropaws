import 'clinic_booking.dart';

class ClinicServiceLog {
  final String id;
  final String serviceTypeName;
  final String? notes;
  final DateTime loggedAt;

  const ClinicServiceLog({
    required this.id,
    required this.serviceTypeName,
    this.notes,
    required this.loggedAt,
  });

  factory ClinicServiceLog.fromJson(Map<String, dynamic> json) =>
      ClinicServiceLog(
        id: json['id'] as String,
        serviceTypeName:
            (json['service_type'] as Map<String, dynamic>)['name'] as String,
        notes: json['notes'] as String?,
        loggedAt: DateTime.parse(json['logged_at'] as String),
      );
}

class ClinicMemberService {
  final String id;
  final String serviceTypeName;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;
  final DateTime? expiresAt;

  const ClinicMemberService({
    required this.id,
    required this.serviceTypeName,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
    this.expiresAt,
  });

  factory ClinicMemberService.fromJson(Map<String, dynamic> json) =>
      ClinicMemberService(
        id: json['id'] as String,
        serviceTypeName:
            (json['service_type'] as Map<String, dynamic>)['name'] as String,
        totalSessions: json['total_sessions'] as int,
        usedSessions: json['used_sessions'] as int,
        remainingSessions: json['remaining_sessions'] as int,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
      );
}

class ClinicPetService {
  final String id;
  final String serviceTypeName;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;

  const ClinicPetService({
    required this.id,
    required this.serviceTypeName,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
  });

  factory ClinicPetService.fromJson(Map<String, dynamic> json) =>
      ClinicPetService(
        id: json['id'] as String,
        serviceTypeName:
            (json['service_type'] as Map<String, dynamic>)['name'] as String,
        totalSessions: json['total_sessions'] as int,
        usedSessions: json['used_sessions'] as int,
        remainingSessions: json['remaining_sessions'] as int,
      );
}

class ClinicPet {
  final String id;
  final String name;
  final String? species;
  final String? breed;
  final int? birthMonth;
  final int? birthYear;
  final int? birthDay;
  final double? weightKg;
  final String? sex;
  final String? photoUrl;
  final String? vaxCardUrl;
  final String? notes;
  final List<ClinicPetService> petServices;
  final List<ClinicServiceLog> serviceLogs;

  const ClinicPet({
    required this.id,
    required this.name,
    this.species,
    this.breed,
    this.birthMonth,
    this.birthYear,
    this.birthDay,
    this.weightKg,
    this.sex,
    this.photoUrl,
    this.vaxCardUrl,
    this.notes,
    required this.petServices,
    required this.serviceLogs,
  });

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

  factory ClinicPet.fromJson(Map<String, dynamic> json) => ClinicPet(
    id: json['id'] as String,
    name: json['name'] as String,
    species: json['species'] as String?,
    breed: json['breed'] as String?,
    birthMonth: json['birth_month'] as int?,
    birthYear: json['birth_year'] as int?,
    birthDay: json['birth_day'] as int?,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    sex: json['sex'] as String?,
    photoUrl: json['photo_url'] as String?,
    vaxCardUrl: json['vax_card_url'] as String?,
    notes: json['notes'] as String?,
    petServices: (json['pet_services'] as List<dynamic>? ?? [])
        .map((e) => ClinicPetService.fromJson(e as Map<String, dynamic>))
        .toList(),
    serviceLogs: (json['service_logs'] as List<dynamic>)
        .map((e) => ClinicServiceLog.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ClinicScanResult {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? address;
  final String? planType;
  final List<ClinicMemberService> services;
  final List<ClinicPet> pets;
  final List<ClinicBooking> bookings;

  const ClinicScanResult({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
    this.planType,
    required this.services,
    required this.pets,
    this.bookings = const [],
  });

  factory ClinicScanResult.fromJson(Map<String, dynamic> json) =>
      ClinicScanResult(
        id: json['id'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        planType: json['plan_type'] as String?,
        services: (json['services'] as List<dynamic>? ?? [])
            .map((e) => ClinicMemberService.fromJson(e as Map<String, dynamic>))
            .toList(),
        pets: (json['pets'] as List<dynamic>)
            .map((e) => ClinicPet.fromJson(e as Map<String, dynamic>))
            .toList(),
        bookings: (json['bookings'] as List<dynamic>? ?? [])
            .map((e) => ClinicBooking.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

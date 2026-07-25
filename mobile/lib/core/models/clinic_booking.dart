class ClinicBookingMember {
  final String id;
  final String firstName;
  final String lastName;
  final String? planType;

  const ClinicBookingMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.planType,
  });

  String get fullName => '$firstName $lastName';

  factory ClinicBookingMember.fromJson(Map<String, dynamic> json) =>
      ClinicBookingMember(
        id: json['id'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        planType: json['plan_type'] as String?,
      );
}

class ClinicBooking {
  final String id;
  final ClinicBookingMember member;
  final String serviceTypeName;
  final DateTime bookingDate;
  final String timeSlot;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const ClinicBooking({
    required this.id,
    required this.member,
    required this.serviceTypeName,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory ClinicBooking.fromJson(Map<String, dynamic> json) => ClinicBooking(
        id: json['id'] as String,
        member:
            ClinicBookingMember.fromJson(json['member'] as Map<String, dynamic>),
        serviceTypeName:
            (json['service_type'] as Map<String, dynamic>)['name'] as String,
        bookingDate: DateTime.parse(json['booking_date'] as String),
        timeSlot: json['time_slot'] as String,
        status: json['status'] as String,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

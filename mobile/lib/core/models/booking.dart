import 'service_type.dart';
import 'clinic_partner.dart';

enum BookingStatus { pending, confirmed, cancelled }

BookingStatus _bookingStatusFromJson(String value) => BookingStatus.values
    .firstWhere((s) => s.name == value, orElse: () => BookingStatus.pending);

class Booking {
  final String id;
  final ServiceType serviceType;
  final ClinicPartner? clinic;
  final DateTime bookingDate;
  final String timeSlot;
  final BookingStatus status;
  final bool creditUsed;
  final String? notes;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.serviceType,
    this.clinic,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    this.creditUsed = false,
    this.notes,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        serviceType:
            ServiceType.fromJson(json['service_type'] as Map<String, dynamic>),
        clinic: json['clinic'] != null
            ? ClinicPartner.fromJson(json['clinic'] as Map<String, dynamic>)
            : null,
        bookingDate: DateTime.parse(json['booking_date'] as String),
        timeSlot: json['time_slot'] as String,
        status: _bookingStatusFromJson(json['status'] as String),
        creditUsed: json['credit_used'] as bool? ?? false,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

import '../../../core/models/clinic_scan_result.dart';
import '../../../core/models/clinic_booking.dart';

abstract class ClinicState {}

class ClinicInitial extends ClinicState {}

/// Emitted while a QR scan lookup is in flight.
class ClinicLoading extends ClinicState {}

class ClinicScanSuccess extends ClinicState {
  final ClinicScanResult result;
  ClinicScanSuccess(this.result);
}

class ClinicFailure extends ClinicState {
  final String message;
  ClinicFailure(this.message);
}

/// Emitted while the schedule (bookings) list is being fetched.
class ClinicScheduleLoading extends ClinicState {}

class ClinicScheduleLoaded extends ClinicState {
  final List<ClinicBooking> bookings;
  ClinicScheduleLoaded(this.bookings);
}

class ClinicScheduleError extends ClinicState {
  final String message;
  ClinicScheduleError(this.message);
}

/// Emitted while a single booking's confirm/cancel request is in flight.
/// [bookingId] lets the schedule list show a spinner on just that card
/// while the rest of the (already-loaded) list stays visible.
class ClinicBookingActionInProgress extends ClinicState {
  final String bookingId;
  ClinicBookingActionInProgress(this.bookingId);
}

class ClinicBookingActionError extends ClinicState {
  final String message;
  ClinicBookingActionError(this.message);
}

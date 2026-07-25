abstract class ClinicEvent {}

/// Look up a member/pet record by QR token (scanned or manually entered).
class ClinicScanRequested extends ClinicEvent {
  final String token;
  ClinicScanRequested(this.token);
}

/// Clears a scan result and returns the bloc to [ClinicInitial] — dispatched
/// after "Scan Another", after a tab switch away from a result, and after a
/// scan failure snackbar has been shown.
class ClinicReset extends ClinicEvent {}

/// Fetches this clinic's bookings, optionally filtered to a single date
/// (YYYY-MM-DD). `date: null` requests every upcoming booking ("All").
class ClinicScheduleRequested extends ClinicEvent {
  final String? date;
  ClinicScheduleRequested({this.date});
}

class ClinicBookingConfirmRequested extends ClinicEvent {
  final String bookingId;
  ClinicBookingConfirmRequested(this.bookingId);
}

class ClinicBookingCancelRequested extends ClinicEvent {
  final String bookingId;
  ClinicBookingCancelRequested(this.bookingId);
}

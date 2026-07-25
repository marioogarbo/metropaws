abstract class AdminEvent {}

/// Look up a member by their Digital Pawprint QR token (or pet-level QR),
/// via camera scan or manual token entry.
class AdminScanRequested extends AdminEvent {
  final String token;
  AdminScanRequested(this.token);
}

/// Clears any scan/deploy result and returns the bloc to its initial state —
/// dispatched after a failed lookup's snackbar, and after the deploy screen
/// is popped, so the scanner is ready for the next member.
class AdminReset extends AdminEvent {}

/// Logs a service session against the scanned member (and optionally one of
/// their pets), consuming a session per the backend's deploy-service rules.
class AdminDeployServiceRequested extends AdminEvent {
  final String memberId;
  final String serviceTypeId;
  final String? petId;
  final String? notes;

  AdminDeployServiceRequested({
    required this.memberId,
    required this.serviceTypeId,
    this.petId,
    this.notes,
  });
}

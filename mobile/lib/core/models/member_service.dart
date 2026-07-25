import 'service_type.dart';

class MemberService {
  final String id;
  final ServiceType serviceType;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;
  final DateTime? expiresAt;

  const MemberService({
    required this.id,
    required this.serviceType,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
    this.expiresAt,
  });

  factory MemberService.fromJson(Map<String, dynamic> json) => MemberService(
        id: json['id'] as String,
        serviceType:
            ServiceType.fromJson(json['service_type'] as Map<String, dynamic>),
        totalSessions: json['total_sessions'] as int,
        usedSessions: json['used_sessions'] as int,
        remainingSessions: json['remaining_sessions'] as int,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
      );
}

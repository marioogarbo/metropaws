class TokenResponse {
  final String accessToken;
  final String role;
  final String? memberId;
  final String userId;

  const TokenResponse({
    required this.accessToken,
    required this.role,
    this.memberId,
    required this.userId,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        role: json['role'] as String,
        memberId: json['member_id'] as String?,
        userId: json['user_id'] as String,
      );
}

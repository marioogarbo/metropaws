class PawPointsBalance {
  final int currentBalance;
  final int lifetimeEarned;

  const PawPointsBalance({
    required this.currentBalance,
    required this.lifetimeEarned,
  });

  factory PawPointsBalance.fromJson(Map<String, dynamic> json) =>
      PawPointsBalance(
        currentBalance: json['current_balance'] as int? ?? 0,
        lifetimeEarned: json['lifetime_earned'] as int? ?? 0,
      );
}

class PawPointsTransaction {
  final String id;
  final int points;
  final String activityType;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;

  const PawPointsTransaction({
    required this.id,
    required this.points,
    required this.activityType,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory PawPointsTransaction.fromJson(Map<String, dynamic> json) =>
      PawPointsTransaction(
        id: json['id'] as String,
        points: json['points'] as int,
        activityType: json['activity_type'] as String,
        referenceId: json['reference_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get label {
    switch (activityType) {
      case 'membership_activation':
        return 'Membership Activated';
      case 'membership_renewal':
        return 'Membership Renewed';
      case 'pet_profile_completed':
        return 'Pet Profile Completed';
      case 'service_deployed_vet':
        return 'Vet Visit';
      case 'service_deployed_grooming':
        return 'Grooming Session';
      case 'admin_manual_award':
        return notes ?? 'Bonus Points';
      default:
        return activityType.replaceAll('_', ' ');
    }
  }

}

class PawReward {
  final String id;
  final String name;
  final String? description;
  final int pointsRequired;
  final String rewardType;
  final bool isActive;
  final int sortOrder;

  const PawReward({
    required this.id,
    required this.name,
    this.description,
    required this.pointsRequired,
    required this.rewardType,
    required this.isActive,
    required this.sortOrder,
  });

  factory PawReward.fromJson(Map<String, dynamic> json) => PawReward(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        pointsRequired: json['points_required'] as int,
        rewardType: json['reward_type'] as String,
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

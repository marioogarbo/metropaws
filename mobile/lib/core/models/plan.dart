class Plan {
  final String id;
  final String name;
  final String subtitle;
  final int price;
  final String? tagline;
  final List<String> features;
  final bool isFeatured;
  final bool isActive;
  final int sortOrder;

  const Plan({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.price,
    this.tagline,
    required this.features,
    required this.isFeatured,
    required this.isActive,
    required this.sortOrder,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as String,
        name: json['name'] as String,
        subtitle: (json['subtitle'] as String?) ?? (json['name'] as String),
        price: json['price'] as int,
        tagline: json['tagline'] as String?,
        features: List<String>.from(json['features'] as List),
        isFeatured: json['is_featured'] as bool,
        isActive: json['is_active'] as bool,
        sortOrder: json['sort_order'] as int,
      );
}

class ServiceType {
  final String id;
  final String name;
  final String? description;
  final String icon;

  const ServiceType({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String? ?? 'pets',
      );
}

/// A member-facing event or promo shown on the Events tab (the Book tab's
/// stand-in while booking is on standby — no partner clinics yet).
class Promo {
  final String id;
  final String title;
  final String? body;
  final String type; // 'event' | 'promo'
  final DateTime? eventDate; // events only
  final String? location; // events only
  final String? linkUrl;
  final String? imageUrl;
  final DateTime createdAt;

  const Promo({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.eventDate,
    this.location,
    this.linkUrl,
    this.imageUrl,
    required this.createdAt,
  });

  bool get isEvent => type == 'event';

  factory Promo.fromJson(Map<String, dynamic> json) => Promo(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        type: json['type'] as String? ?? 'promo',
        eventDate: json['event_date'] == null
            ? null
            : DateTime.parse(json['event_date'] as String),
        location: json['location'] as String?,
        linkUrl: json['link_url'] as String?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

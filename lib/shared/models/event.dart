class Event {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String title;
  final String category;
  final String description;
  final DateTime eventDate;
  final String time;
  final String location;
  final String? farmId;
  final int maxAttendees;
  final int currentAttendees;
  final bool isCoHosted;
  final List<String> coHostIds;
  final List<String> coHostNames;
  final DateTime createdAt;
  final List<String> tags;
  final String? imageUrl;

  Event({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.title,
    required this.category,
    required this.description,
    required this.eventDate,
    required this.time,
    required this.location,
    this.farmId,
    required this.maxAttendees,
    required this.currentAttendees,
    this.isCoHosted = false,
    this.coHostIds = const [],
    this.coHostNames = const [],
    required this.createdAt,
    this.tags = const [],
    this.imageUrl,
  });

  factory Event.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String userName,
    String? userAvatar,
    List<String> coHostNames = const [],
  }) {
    return Event(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: userName,
      userAvatar: userAvatar,
      title: row['title'] as String,
      category: row['category'] as String,
      description: row['description'] as String? ?? '',
      eventDate: DateTime.parse(row['event_date'] as String),
      time: row['time'] as String,
      location: row['location'] as String,
      farmId: row['farm_id'] as String?,
      maxAttendees: row['max_attendees'] as int? ?? 0,
      currentAttendees: row['current_attendees'] as int? ?? 0,
      isCoHosted: row['is_co_hosted'] as bool? ?? false,
      coHostIds: (row['co_host_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coHostNames: coHostNames,
      createdAt: DateTime.parse(row['created_at'] as String),
      tags:
          (row['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      imageUrl: row['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'category': category,
      'description': description,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'time': time,
      'location': location,
      'farm_id': farmId,
      'max_attendees': maxAttendees,
      'current_attendees': currentAttendees,
      'is_co_hosted': isCoHosted,
      'co_host_ids': coHostIds,
      'tags': tags,
      'image_url': imageUrl,
    };
  }
}

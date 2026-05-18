class MarketplaceListing {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String title;
  final String price;
  final String description;
  final String? condition;
  final List<String> tags;
  final List<String> imageUrls;
  final Map<String, String> specifications;
  final String? location;
  final DateTime createdAt;

  MarketplaceListing({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.title,
    required this.price,
    required this.description,
    this.condition,
    required this.tags,
    required this.imageUrls,
    required this.specifications,
    this.location,
    required this.createdAt,
  });

  MarketplaceListing copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? title,
    String? price,
    String? description,
    String? condition,
    List<String>? tags,
    List<String>? imageUrls,
    Map<String, String>? specifications,
    String? location,
    DateTime? createdAt,
  }) {
    return MarketplaceListing(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      tags: tags ?? this.tags,
      imageUrls: imageUrls ?? this.imageUrls,
      specifications: specifications ?? this.specifications,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'price': price,
      'description': description,
      'condition': condition,
      'tags': tags,
      'image_urls': imageUrls,
      'specifications': specifications,
      'location': location,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      id: json['id'],
      userId: json['user_id'],
      userName: json['userName'] ?? 'User',
      userAvatar: json['userAvatar'],
      title: json['title'],
      price: json['price'],
      description: json['description'],
      condition: json['condition'],
      tags: List<String>.from(json['tags'] ?? []),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      specifications: Map<String, String>.from(json['specifications'] ?? {}),
      location: json['location'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory MarketplaceListing.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String userName,
    String? userAvatar,
    String? location,
  }) {
    final List<dynamic>? imageUrls = row['image_urls'] as List<dynamic>?;
    final List<dynamic>? tagsArray = row['tags'] as List<dynamic>?;
    final Map<String, dynamic>? specsMap =
        row['specifications'] as Map<String, dynamic>?;

    return MarketplaceListing(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: userName,
      userAvatar: userAvatar,
      title: row['title'] as String,
      price: row['price'] as String,
      description: row['description'] as String? ?? '',
      condition: row['condition'] as String?,
      tags: tagsArray != null
          ? tagsArray.map((e) => e.toString()).toList()
          : <String>[],
      imageUrls: imageUrls != null
          ? imageUrls.map((e) => e.toString()).toList()
          : <String>[],
      specifications: specsMap != null
          ? specsMap
              .map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{},
      location: location ?? row['location'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

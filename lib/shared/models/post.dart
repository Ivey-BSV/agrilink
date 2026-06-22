import 'package:cap/shared/utils/image_url_utils.dart';

class Post {
  final String id;
  final String title;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String? imageUrl;
  final String? location;
  final int likes;
  final int comments;
  final DateTime timestamp;
  final List<String> tags;

  Post({
    required this.id,
    required this.title,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.imageUrl,
    this.location,
    required this.likes,
    required this.comments,
    required this.timestamp,
    required this.tags,
  });

  Post copyWith({
    String? id,
    String? title,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    String? imageUrl,
    String? location,
    int? likes,
    int? comments,
    DateTime? timestamp,
    List<String>? tags,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      timestamp: timestamp ?? this.timestamp,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'imageUrl': imageUrl,
      'location': location,
      'likes': likes,
      'comments': comments,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      userId: json['userId'],
      userName: json['userName'],
      userAvatar: sanitizeImageUrl(json['userAvatar'] as String?),
      content: json['content'],
      imageUrl: sanitizeImageUrl(json['imageUrl'] as String?),
      location: json['location'],
      likes: json['likes'],
      comments: json['comments'],
      timestamp: DateTime.parse(json['timestamp']),
      tags: List<String>.from(json['tags']),
    );
  }

  factory Post.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String userName,
    String? userAvatar,
    int commentCount = 0,
    int likeCount = 0,
  }) {
    final List<dynamic>? tagsArray = row['tags'] as List<dynamic>?;

    return Post(
      id: row['id'] as String,
      title: (row['title'] ?? 'Post') as String,
      userId: row['user_id'] as String,
      userName: userName,
      userAvatar: sanitizeImageUrl(userAvatar),
      content: (row['content'] ?? '') as String,
      imageUrl: firstPostImageUrl(row['image_urls']),
      location: row['location'] as String?,
      likes: likeCount,
      comments: commentCount,
      timestamp: DateTime.parse(row['created_at'] as String),
      tags: tagsArray != null
          ? tagsArray.map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

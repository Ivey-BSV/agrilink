class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final DateTime? readAt;
  final String? eventId;
  final String? postId;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.readAt,
    this.eventId,
    this.postId,
  });

  bool get isRead => readAt != null;

  Message copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? timestamp,
    DateTime? readAt,
    String? eventId,
    String? postId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      readAt: readAt ?? this.readAt,
      eventId: eventId ?? this.eventId,
      postId: postId ?? this.postId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'created_at': timestamp.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'event_id': eventId,
      'post_id': postId,
    };
  }

  factory Message.fromSupabaseRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      content: (row['content'] as String?)?.trim() ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      readAt: row['read_at'] != null
          ? DateTime.parse(row['read_at'] as String)
          : null,
      eventId: row['event_id'] as String?,
      postId: row['post_id'] as String?,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['senderId'] as String? ?? json['sender_id'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(
          json['timestamp'] as String? ?? json['created_at'] as String),
      readAt: json['readAt'] != null || json['read_at'] != null
          ? DateTime.parse((json['readAt'] ?? json['read_at']) as String)
          : null,
      eventId: json['eventId'] as String? ?? json['event_id'] as String?,
      postId: json['postId'] as String? ?? json['post_id'] as String?,
    );
  }
}

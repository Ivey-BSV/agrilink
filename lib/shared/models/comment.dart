class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? usernameHandle;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final String? parentId;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.usernameHandle,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentId,
  });

  factory Comment.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String userName,
    String? usernameHandle,
    String? userAvatar,
  }) {
    return Comment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      userId: row['user_id'] as String,
      userName: userName,
      usernameHandle: usernameHandle,
      userAvatar: userAvatar,
      content: row['content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      parentId: row['parent_id'] as String?,
    );
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? usernameHandle,
    String? userAvatar,
    String? content,
    DateTime? createdAt,
    String? parentId,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      usernameHandle: usernameHandle ?? this.usernameHandle,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
    );
  }
}

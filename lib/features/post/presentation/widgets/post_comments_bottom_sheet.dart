import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/comment.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postTitle;

  const PostCommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String postTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostCommentsBottomSheet(
        postId: postId,
        postTitle: postTitle,
      ),
    );
  }

  @override
  State<PostCommentsBottomSheet> createState() =>
      _PostCommentsBottomSheetState();
}

class _PostCommentsBottomSheetState extends State<PostCommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _currentUserAvatar;
  String _currentUserName = 'User';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().loadCommentsForPost(widget.postId);
      _loadCurrentUser();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;

    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.currentProfile != null) {
      if (!mounted) return;
      setState(() {
        _currentUserAvatar = profileProvider.currentProfile!.avatarUrl;
        _currentUserName = profileProvider.currentProfile!.fullName ??
            profileProvider.currentProfile!.displayUsername ??
            'User';
      });
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || profile == null) return;
      setState(() {
        _currentUserAvatar = profile['avatar_url'] as String?;
        _currentUserName = profile['full_name'] as String? ??
            (profile['username'] as String?)?.toLowerCase() ??
            'User';
      });
    } catch (_) {}
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    await context.read<PostProvider>().addComment(
          widget.postId,
          text,
          parentId: _replyingToCommentId,
        );

    if (!mounted) return;
    _commentController.clear();
    setState(() {
      _replyingToCommentId = null;
      _isSubmitting = false;
    });
  }

  String _replyBannerText(List<Comment> comments) {
    final id = _replyingToCommentId;
    if (id == null) return '';
    for (final c in comments) {
      if (c.id == id) return 'Replying to ${c.userName}';
    }
    return 'Replying to comment';
  }

  Widget _buildCommentTile(Comment comment, String currentUserId) {
    final canDelete = comment.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user-profile/${comment.userId}'),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: NetworkCircleAvatar(
                radius: 16,
                imageUrl: comment.userAvatar,
                fallbackLetter: comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : 'U',
                fallbackTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey[600]),
                        onPressed: () async {
                          await context
                              .read<PostProvider>()
                              .deleteComment(comment.id, widget.postId);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                LinkifiedText(
                  text: comment.content,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToCommentId = comment.id;
                        });
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatFriendlyRelativeTime(comment.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comments',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/post/${widget.postId}');
                        },
                        child: const Text('View post'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Consumer<PostProvider>(
                    builder: (context, postProvider, _) {
                      final comments =
                          postProvider.getCommentsForPost(widget.postId) ?? [];
                      final authProvider = context.read<AuthProvider>();
                      final currentUserId = authProvider.userId ?? '';

                      if (comments.isEmpty) {
                        return Center(
                          child: Text(
                            'No comments yet. Be the first!',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      final sorted = List<Comment>.from(comments)
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          return _buildCommentTile(
                              sorted[index], currentUserId);
                        },
                      );
                    },
                  ),
                ),
                if (_replyingToCommentId != null)
                  Consumer<PostProvider>(
                    builder: (context, postProvider, _) {
                      final comments =
                          postProvider.getCommentsForPost(widget.postId) ?? [];
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _replyBannerText(comments),
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _replyingToCommentId = null;
                                });
                                _commentController.clear();
                              },
                              child: Icon(Icons.close,
                                  size: 16, color: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: NetworkCircleAvatar(
                            radius: 16,
                            imageUrl: _currentUserAvatar,
                            fallbackLetter: _currentUserName.isNotEmpty
                                ? _currentUserName[0].toUpperCase()
                                : 'U',
                            fallbackTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isSubmitting ? null : _submitComment,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.send,
                                  color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

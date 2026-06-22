import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/comment.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cap/features/post/presentation/widgets/post_comments_bottom_sheet.dart';
import 'package:cap/features/post/presentation/widgets/share_post_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Post? _post;
  String? _currentUserAvatar;
  String _currentUserName = 'User';
  bool _isLoading = false;
  String? _replyingToCommentId;
  final Set<String> _expandedReplies = {};
  bool _sortOldestFirst = true;
  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _loadPostAndComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadPostAndComments() async {
    final postProvider = context.read<PostProvider>();

    setState(() {
      _isLoading = true;
    });

    Post? foundPost;
    try {
      foundPost = postProvider.posts
          .where((post) => post.id == widget.postId)
          .firstOrNull;
    } catch (_) {
      foundPost = null;
    }
    foundPost ??= await postProvider.fetchPostById(widget.postId);
    _post = foundPost;

    if (_post != null) {
      await postProvider.ensureLikesLoaded(widget.postId);
    }

    await postProvider.loadCommentsForPost(widget.postId);
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId != null) {
      final profileProvider = context.read<ProfileProvider>();
      if (profileProvider.currentProfile != null) {
        setState(() {
          _currentUserAvatar = profileProvider.currentProfile!.avatarUrl;
          _currentUserName = profileProvider.currentProfile!.fullName ??
              profileProvider.currentProfile!.displayUsername ??
              'User';
        });
      } else {
        try {
          final supabase = Supabase.instance.client;
          final profile = await supabase
              .from('user_profiles')
              .select('full_name, username, avatar_url')
              .eq('id', userId)
              .maybeSingle();

          if (profile != null) {
            setState(() {
              _currentUserAvatar =
                  sanitizeImageUrl(profile['avatar_url'] as String?);
              _currentUserName = profile['full_name'] ??
                  (profile['username'] as String?)?.toLowerCase() ??
                  'User';
            });
          }
        } catch (e) {
          setState(() {
            _currentUserName = authProvider.userName ?? 'User';
            _currentUserAvatar = authProvider.userAvatar;
          });
        }
      }
    }

    setState(() {
      _isLoading = false;
    });

    final previewUrl = sanitizeImageUrl(_post?.imageUrl);
    if (previewUrl != null && isDirectImageUrl(previewUrl)) {
      _resolveImageAspectRatio(previewUrl);
    }
  }

  void _resolveImageAspectRatio(String imageUrl) {
    final sanitized = sanitizeImageUrl(imageUrl) ?? imageUrl;
    final ImageProvider provider = isNetworkImageUrl(sanitized)
        ? CachedNetworkImageProvider(sanitized)
        : AssetImage(sanitized) as ImageProvider;
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      final int w = info.image.width;
      final int h = info.image.height;
      if (mounted) {
        setState(() {
          if (h != 0) {
            _imageAspectRatio = w / h;
          }
        });
      }
      stream.removeListener(listener!);
    }, onError: (dynamic _, __) {
      if (mounted) {
        setState(() {
          _imageAspectRatio = null;
        });
      }
      stream.removeListener(listener!);
    });
    stream.addListener(listener);
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final postProvider = context.read<PostProvider>();
    await postProvider.addComment(widget.postId, _commentController.text.trim(),
        parentId: _replyingToCommentId);

    _commentController.clear();
    _replyingToCommentId = null;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final postProvider = context.read<PostProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    await postProvider.deleteComment(commentId, widget.postId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deletePost() async {
    final postProvider = context.read<PostProvider>();
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await postProvider.deletePost(widget.postId);

      if (!mounted) return;

      await postProvider.loadPostsFromSupabase();

      if (!mounted) return;

      navigator.pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPostContent() {
    if (_post == null) return const SizedBox.shrink();

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId ?? '';
    final isCurrentUser = _post!.userId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            context.push('/user-profile/${_post!.userId}');
          },
          child: Row(
            children: [
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: NetworkCircleAvatar(
                  radius: 24,
                  imageUrl: _post!.userAvatar,
                  fallbackLetter: _post!.userName.isNotEmpty
                      ? _post!.userName[0].toUpperCase()
                      : 'U',
                  fallbackTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post!.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        decoration: isCurrentUser ? TextDecoration.none : null,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                        children: [
                          TextSpan(text: _formatTimestamp(_post!.timestamp)),
                          if (_post!.location != null &&
                              _post!.location!.isNotEmpty) ...[
                            TextSpan(
                              text: ' • ',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            TextSpan(text: _post!.location!),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_post!.title.isNotEmpty && _post!.title != 'Post')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _post!.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        if (_post!.content.isNotEmpty) ...[
          LinkifiedText(
            text: _post!.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_post!.tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _post!.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (sanitizeImageUrl(_post!.imageUrl) != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                isDirectImageUrl(_post!.imageUrl) && _imageAspectRatio != null
                    ? AspectRatio(
                        aspectRatio: _imageAspectRatio!,
                        child: PostMediaPreview(
                          mediaUrl: _post!.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: PostMediaPreview(
                          mediaUrl: _post!.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
          ),
          const SizedBox(height: 16),
        ],
        Consumer<PostProvider>(
          builder: (context, postProvider, _) {
            if (_post == null) return const SizedBox.shrink();

            final likes = postProvider.likeCountForPost(_post!.id);
            final comments =
                postProvider.getCommentsForPost(widget.postId)?.length ??
                    _post!.comments;
            final isLiked = postProvider.isPostLikedByMe(_post!.id);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          postProvider.togglePostLike(_post!.id),
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        PostCommentsBottomSheet.show(
                          context,
                          postId: _post!.id,
                          postTitle: _post!.title,
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: Colors.black87),
                    ),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => SharePostBottomSheet(
                            postId: _post!.id,
                            postTitle: _post!.title,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_outlined,
                          color: Colors.black87),
                    ),
                  ],
                ),
                if (likes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      likes == 1 ? '1 like' : '$likes likes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                if (comments > 0)
                  Text(
                    comments == 1 ? '1 comment' : '$comments comments',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _replyingToBannerText(List<Comment> comments) {
    final id = _replyingToCommentId;
    if (id == null) return '';
    for (final c in comments) {
      if (c.id == id) {
        return 'Replying to ${c.userName}';
      }
    }
    return 'Replying to comment';
  }

  String _mentionPrefixForComment(Comment comment) {
    final h = comment.usernameHandle?.trim();
    if (h != null && h.isNotEmpty) {
      return '@$h ';
    }
    final display = comment.userName.trim();
    if (display.isEmpty) return '@user ';
    final first = display.split(RegExp(r'\s+')).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => 'user',
        );
    return '@${first.toLowerCase()} ';
  }

  void _beginReplyTo(Comment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
    });
    final prefix = _mentionPrefixForComment(comment);
    _commentController.text = prefix;
    _commentController.selection =
        TextSelection.collapsed(offset: _commentController.text.length);
  }

  Widget _buildCommentWithReplies(
      Comment comment, List<Comment> allComments, String currentUserId,
      {int maxDepth = 3}) {
    final List<Comment> allReplies = [];
    List<Comment> currentLevel = [comment];

    while (currentLevel.isNotEmpty) {
      final List<Comment> nextLevel = [];
      for (final parent in currentLevel) {
        final children =
            allComments.where((c) => c.parentId == parent.id).toList();
        allReplies.addAll(children);
        nextLevel.addAll(children);
      }
      currentLevel = nextLevel;
    }

    return _buildCommentCard(comment, currentUserId, allComments, allReplies,
        currentDepth: 0, maxDepth: maxDepth);
  }

  List<Widget> _buildReplyList(
      List<Comment> replies,
      List<Comment> allComments,
      String currentUserId,
      String parentCommentId,
      int currentDepth,
      int maxDepth) {
    final sortedReplies = List<Comment>.from(replies);
    sortedReplies.sort((a, b) => _sortOldestFirst
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));

    final isExpanded = _expandedReplies.contains(parentCommentId);
    final shownReplies =
        isExpanded ? sortedReplies : sortedReplies.take(2).toList();

    return [
      ...shownReplies.map((reply) {
        return _buildCommentCard(reply, currentUserId, allComments, [],
            currentDepth: currentDepth, maxDepth: maxDepth);
      }),
      if (sortedReplies.length > 2)
        GestureDetector(
          onTap: () {
            setState(() {
              if (_expandedReplies.contains(parentCommentId)) {
                _expandedReplies.remove(parentCommentId);
              } else {
                _expandedReplies.add(parentCommentId);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 20, top: 8),
            child: Text(
              isExpanded
                  ? 'Show less'
                  : sortedReplies.length - 2 == 1
                      ? '1 more reply'
                      : '${sortedReplies.length - 2} more replies',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildCommentCard(Comment comment, String currentUserId,
      List<Comment> allComments, List<Comment> replies,
      {int currentDepth = 0, int maxDepth = 3}) {
    final canDelete = comment.userId == currentUserId;
    final isCurrentUser = comment.userId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                context.push('/user-profile/${comment.userId}');
              },
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
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.push('/user-profile/${comment.userId}');
                          },
                          child: Text(
                            comment.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              decoration:
                                  isCurrentUser ? TextDecoration.none : null,
                            ),
                          ),
                        ),
                      ),
                      if (canDelete)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _deleteComment(comment.id),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  LinkifiedText(
                    text: comment.content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _beginReplyTo(comment),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(comment.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (replies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              children: _buildReplyList(replies, allComments, currentUserId,
                  comment.id, currentDepth, maxDepth),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId ?? '';
    final isCurrentUser = _post != null && _post!.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Forums Post',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: () => _deletePost(),
            ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _post == null
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SharePostBottomSheet(
                        postId: _post!.id,
                        postTitle: _post!.title,
                      ),
                    );
                  },
          ),
        ],
      ),
      body: _isLoading && _post == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : _post == null
              ? const Center(child: Text('Post not found'))
              : Consumer<PostProvider>(
                  builder: (context, postProvider, child) {
                    final comments =
                        postProvider.getCommentsForPost(widget.postId) ?? [];
                    final authProvider = context.read<AuthProvider>();
                    final currentUserId = authProvider.userId ?? '';

                    final sortedComments = List<Comment>.from(comments);
                    sortedComments.sort((a, b) => _sortOldestFirst
                        ? a.createdAt.compareTo(b.createdAt)
                        : b.createdAt.compareTo(a.createdAt));

                    final topLevelComments = sortedComments
                        .where((c) => c.parentId == null)
                        .toList();

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPostContent(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text(
                                      'Comments',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${comments.length}',
                                        style: TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _sortOldestFirst = !_sortOldestFirst;
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            _sortOldestFirst
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                            size: 16,
                                            color: AppTheme.primaryGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _sortOldestFirst
                                                ? 'Oldest'
                                                : 'Newest',
                                            style: TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (topLevelComments.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 32),
                                    child: Text(
                                      'No comments yet. Be the first to comment!',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  ...topLevelComments.map((comment) =>
                                      _buildCommentWithReplies(
                                          comment, comments, currentUserId)),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_replyingToCommentId != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _replyingToBannerText(comments),
                                            style: TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontSize: 12,
                                              fontFamily: 'Poppins',
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
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppTheme.primaryGradient,
                                      ),
                                      child: NetworkCircleAvatar(
                                        radius: 18,
                                        imageUrl: _currentUserAvatar,
                                        fallbackLetter: _currentUserName
                                                .isNotEmpty
                                            ? _currentUserName[0].toUpperCase()
                                            : 'U',
                                        fallbackTextStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        decoration: InputDecoration(
                                          hintText: _replyingToCommentId != null
                                              ? 'Write a reply...'
                                              : 'Add a comment...',
                                          filled: true,
                                          fillColor: Colors.grey[100],
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          hintStyle: TextStyle(
                                            color: Colors.grey[600],
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Poppins',
                                        ),
                                        onSubmitted: (_) => _addComment(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed:
                                          _isLoading ? null : _addComment,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            )
                                          : Icon(
                                              Icons.send,
                                              color: AppTheme.primaryGreen,
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

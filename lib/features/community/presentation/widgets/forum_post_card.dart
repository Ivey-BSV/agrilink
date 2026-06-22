import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:provider/provider.dart';

class ForumPostCard extends StatelessWidget {
  final Post post;
  final bool isVideo;
  final VoidCallback onOpenPost;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.isVideo,
    required this.onOpenPost,
    required this.onComment,
    required this.onShare,
  });

  String get _displayTitle =>
      post.title.trim().isEmpty || post.title == 'Post' ? '' : post.title;

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, _) {
        final livePost = postProvider.posts
                .where((p) => p.id == post.id)
                .firstOrNull ??
            post;
        final likes = postProvider.likeCountForPost(post.id);
        final comments = postProvider.commentCountForPost(post.id);
        final isLiked = postProvider.isPostLikedByMe(post.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: onOpenPost,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                ),
                                child: NetworkCircleAvatar(
                                  radius: 18,
                                  imageUrl: livePost.userAvatar,
                                  fallbackLetter: livePost.userName.isNotEmpty
                                      ? livePost.userName[0].toUpperCase()
                                      : 'U',
                                  fallbackTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      livePost.userName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _metaLine(livePost),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_displayTitle.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              _displayTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                          if (livePost.content.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              livePost.content,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[900],
                                height: 1.45,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (livePost.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: livePost.tags.take(4).map((tag) {
                                return Text(
                                  '#$tag',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (sanitizeImageUrl(livePost.imageUrl) != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onOpenPost,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: PostMediaPreview(
                              mediaUrl: livePost.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (isVideo)
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              postProvider.togglePostLike(post.id),
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: onComment,
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: Colors.black87),
                        ),
                        IconButton(
                          onPressed: onShare,
                          icon: const Icon(Icons.send_outlined,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (likes > 0)
                          Text(
                            likes == 1 ? '1 like' : '$likes likes',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (comments > 0) ...[
                          if (likes > 0) const SizedBox(height: 4),
                          GestureDetector(
                            onTap: onComment,
                            child: Text(
                              comments == 1
                                  ? 'View 1 comment'
                                  : 'View all $comments comments',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          ],
        );
      },
    );
  }

  String _metaLine(Post livePost) {
    final time = formatFriendlyRelativeTime(livePost.timestamp);
    if (livePost.location != null && livePost.location!.isNotEmpty) {
      return '$time · ${livePost.location}';
    }
    return time;
  }
}

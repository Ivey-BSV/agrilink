import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/post/presentation/widgets/post_action_bar.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';

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
                  child: _buildPostHeaderAndBody(),
                ),
              ),
              if (sanitizeImageUrl(post.imageUrl) != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: onOpenPost,
                  child: _buildMedia(),
                ),
              ],
              PostActionBar(
                postId: post.id,
                onComment: onComment,
                onShare: onShare,
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildPostHeaderAndBody() {
    return Column(
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
                imageUrl: post.userAvatar,
                fallbackLetter: post.userName.isNotEmpty
                    ? post.userName[0].toUpperCase()
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
                    post.userName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    _metaLine(post),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[900],
              height: 1.45,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.tags.map((tag) => '#$tag').join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMedia() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PostMediaPreview(
            mediaUrl: post.imageUrl,
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

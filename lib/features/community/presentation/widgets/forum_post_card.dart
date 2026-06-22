import 'package:flutter/material.dart';
import 'package:cap/features/post/presentation/widgets/forum_post_header.dart';
import 'package:cap/features/post/presentation/widgets/forum_post_landscape_media.dart';
import 'package:cap/features/post/presentation/widgets/forum_post_text_content.dart';
import 'package:cap/features/post/presentation/widgets/post_action_bar.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/image_url_utils.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ForumPostHeader(post: post),
                      ForumPostTextContent(post: post),
                    ],
                  ),
                ),
              ),
              if (sanitizeImageUrl(post.imageUrl) != null) ...[
                const SizedBox(height: 10),
                ForumPostLandscapeMedia(
                  mediaUrl: post.imageUrl,
                  isVideo: isVideo,
                  onTap: onOpenPost,
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
}

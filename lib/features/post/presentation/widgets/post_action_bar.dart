import 'package:flutter/material.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:provider/provider.dart';

class PostActionBar extends StatelessWidget {
  final String postId;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final EdgeInsetsGeometry padding;
  final bool viewAllCommentsLabel;

  const PostActionBar({
    super.key,
    required this.postId,
    required this.onComment,
    required this.onShare,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 16, 0),
    this.viewAllCommentsLabel = true,
  });

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, _) {
        final likes = postProvider.likeCountForPost(postId);
        final comments = postProvider.commentCountForPost(postId);
        final isLiked = postProvider.isPostLikedByMe(postId);

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _actionIcon(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black87,
                    onTap: () => postProvider.togglePostLike(postId),
                  ),
                  const SizedBox(width: 2),
                  _actionIcon(
                    icon: Icons.chat_bubble_outline,
                    color: Colors.black87,
                    onTap: onComment,
                  ),
                  const SizedBox(width: 2),
                  _actionIcon(
                    icon: Icons.send_outlined,
                    color: Colors.black87,
                    onTap: onShare,
                  ),
                ],
              ),
              if (likes > 0 || comments > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (likes > 0)
                        Text(
                          likes == 1 ? '1 like' : '$likes likes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      if (comments > 0) ...[
                        if (likes > 0) const SizedBox(height: 2),
                        GestureDetector(
                          onTap: onComment,
                          child: Text(
                            comments == 1
                                ? (viewAllCommentsLabel
                                    ? 'View 1 comment'
                                    : '1 comment')
                                : (viewAllCommentsLabel
                                    ? 'View all $comments comments'
                                    : '$comments comments'),
                            style: TextStyle(
                              fontSize: 12,
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
        );
      },
    );
  }
}

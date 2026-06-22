import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';

class ForumPostHeader extends StatelessWidget {
  final Post post;

  const ForumPostHeader({super.key, required this.post});

  String _metaLine() {
    final time = formatFriendlyRelativeTime(post.timestamp);
    if (post.location != null && post.location!.isNotEmpty) {
      return '$time · ${post.location}';
    }
    return time;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/user-profile/${post.userId}'),
      child: Row(
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
                  _metaLine(),
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
    );
  }
}

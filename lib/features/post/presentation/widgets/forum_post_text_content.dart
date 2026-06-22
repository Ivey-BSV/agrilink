import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/widgets/linkified_text.dart';

class ForumPostTextContent extends StatelessWidget {
  final Post post;
  final bool expandContent;

  const ForumPostTextContent({
    super.key,
    required this.post,
    this.expandContent = false,
  });

  String get _displayTitle =>
      post.title.trim().isEmpty || post.title == 'Post' ? '' : post.title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_displayTitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _displayTitle,
            maxLines: expandContent ? null : 2,
            overflow: expandContent ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (expandContent)
            LinkifiedText(
              text: post.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[900],
                height: 1.45,
              ),
            )
          else
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
            maxLines: expandContent ? null : 1,
            overflow: expandContent ? null : TextOverflow.ellipsis,
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
}

import 'package:flutter/material.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';

const double kForumPostMediaAspectRatio = 16 / 9;

class ForumPostLandscapeMedia extends StatelessWidget {
  final String? mediaUrl;
  final bool isVideo;
  final VoidCallback? onTap;

  const ForumPostLandscapeMedia({
    super.key,
    required this.mediaUrl,
    this.isVideo = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final media = Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: kForumPostMediaAspectRatio,
          child: PostMediaPreview(
            mediaUrl: mediaUrl,
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

    if (onTap == null) return media;

    return InkWell(
      onTap: onTap,
      child: media,
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/features/post/presentation/widgets/forum_post_landscape_media.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';

class ForumPostDetailMedia extends StatefulWidget {
  final String? mediaUrl;
  final bool isVideo;

  const ForumPostDetailMedia({
    super.key,
    required this.mediaUrl,
    this.isVideo = false,
  });

  @override
  State<ForumPostDetailMedia> createState() => _ForumPostDetailMediaState();
}

class _ForumPostDetailMediaState extends State<ForumPostDetailMedia> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(ForumPostDetailMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  void _resolveAspectRatio() {
    if (widget.isVideo) return;

    final previewUrl = sanitizeImageUrl(widget.mediaUrl);
    if (previewUrl == null || !isDirectImageUrl(previewUrl)) return;

    final sanitized = previewUrl;
    final ImageProvider provider = isNetworkImageUrl(sanitized)
        ? CachedNetworkImageProvider(sanitized)
        : AssetImage(sanitized) as ImageProvider;
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final w = info.image.width;
      final h = info.image.height;
      if (mounted && h > 0) {
        setState(() {
          _aspectRatio = w / h;
        });
      }
      stream.removeListener(listener!);
    }, onError: (dynamic _, __) {
      stream.removeListener(listener!);
    });
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final useNativeRatio = !widget.isVideo && _aspectRatio != null;
    final aspectRatio =
        widget.isVideo ? kForumPostMediaAspectRatio : (_aspectRatio ?? kForumPostMediaAspectRatio);

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: aspectRatio,
          child: PostMediaPreview(
            mediaUrl: widget.mediaUrl,
            fit: useNativeRatio ? BoxFit.contain : BoxFit.cover,
          ),
        ),
        if (widget.isVideo)
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
}

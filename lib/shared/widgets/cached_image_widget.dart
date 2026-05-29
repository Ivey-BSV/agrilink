import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/shared/utils/image_url_utils.dart';

class CachedImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = sanitizeImageUrl(imageUrl);
    if (url == null) {
      return errorWidget ??
          Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          );
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
      memCacheWidth: width != null && width!.isFinite
          ? (width! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
      memCacheHeight: height != null && height!.isFinite
          ? (height! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

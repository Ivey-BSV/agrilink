import 'package:flutter/material.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/widgets/image_placeholder.dart';
import 'package:cap/shared/widgets/post_media_preview.dart';

class ListingMediaTile extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget placeholder;
  final Widget? errorWidget;

  const ListingMediaTile({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder = const ImagePlaceholder(
      borderRadius: 12,
      icon: Icons.inventory_2,
    ),
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final url = sanitizeImageUrl(imageUrl);
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    if (!isNetworkImageUrl(url)) {
      return Image.asset(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => errorWidget ?? placeholder,
      );
    }
    if (!isDirectImageUrl(url)) {
      return PostMediaPreview(
        mediaUrl: url,
        fit: fit,
      );
    }
    return CachedImageWidget(
      imageUrl: url,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorWidget: errorWidget ?? placeholder,
    );
  }
}

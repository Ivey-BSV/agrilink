import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/shared/utils/image_url_utils.dart';

class NetworkCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackLetter;
  final Color backgroundColor;
  final TextStyle? fallbackTextStyle;
  final String? cacheBustKey;
  final Key? avatarKey;
  final Widget? fallbackWidget;

  const NetworkCircleAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    required this.fallbackLetter,
    this.backgroundColor = Colors.transparent,
    this.fallbackTextStyle,
    this.cacheBustKey,
    this.avatarKey,
    this.fallbackWidget,
  });

  String? get _resolvedUrl => cacheBustKey != null
      ? imageUrlWithCacheBust(imageUrl, cacheBustKey!)
      : sanitizeImageUrl(imageUrl);

  Widget _buildFallback() {
    final size = radius * 2;
    final baseStyle = fallbackTextStyle ??
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        );
    final content = fallbackWidget ??
        Text(
          fallbackLetter,
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: baseStyle.copyWith(height: 1),
        );
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    final fallback = _buildFallback();
    final size = radius * 2;

    return CircleAvatar(
      key: avatarKey,
      radius: radius,
      backgroundColor: backgroundColor,
      child: url == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => fallback,
                placeholder: (_, __) => SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: SizedBox(
                      width: radius,
                      height: radius,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

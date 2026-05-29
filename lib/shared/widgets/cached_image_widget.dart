import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/shared/utils/image_url_utils.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final String? fallbackImageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  late String _activeUrl;
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = _resolvePrimaryUrl();
  }

  @override
  void didUpdateWidget(CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _usingFallback = false;
      _activeUrl = _resolvePrimaryUrl();
    }
  }

  String _resolvePrimaryUrl() {
    return networkDisplayImageUrl(widget.imageUrl) ?? widget.imageUrl;
  }

  void _onImageError() {
    final original = sanitizeImageUrl(widget.imageUrl);
    final fallback = sanitizeImageUrl(widget.fallbackImageUrl) ?? original;
    if (!_usingFallback && fallback != null && fallback != _activeUrl) {
      setState(() {
        _usingFallback = true;
        _activeUrl = fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = sanitizeImageUrl(_activeUrl);
    if (url == null) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          );
    }

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;
        final resolvedWidth = widget.width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final resolvedHeight = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : null);

        return CachedNetworkImage(
          key: ValueKey(url),
          imageUrl: url,
          width: resolvedWidth,
          height: resolvedHeight,
          fit: widget.fit,
          placeholder: (context, url) =>
              widget.placeholder ??
              Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (context, url, error) {
            final original = sanitizeImageUrl(widget.imageUrl);
            final canFallback = !_usingFallback &&
                original != null &&
                original != url &&
                (widget.fallbackImageUrl != null || original != _activeUrl);
            if (canFallback) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onImageError();
              });
              return widget.placeholder ??
                  Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
            }
            return widget.errorWidget ??
                Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error_outline, color: Colors.grey),
                );
          },
          memCacheWidth: resolvedWidth != null && resolvedWidth.isFinite
              ? (resolvedWidth * pixelRatio).toInt()
              : null,
          memCacheHeight: resolvedHeight != null && resolvedHeight.isFinite
              ? (resolvedHeight * pixelRatio).toInt()
              : null,
        );
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

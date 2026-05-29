import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/utils/link_preview_utils.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/widgets/image_placeholder.dart';

/// Renders uploaded image files or link-preview thumbnails for webpage URLs.
class PostMediaPreview extends StatefulWidget {
  final String? mediaUrl;
  final BoxFit fit;

  const PostMediaPreview({
    super.key,
    required this.mediaUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<PostMediaPreview> createState() => _PostMediaPreviewState();
}

class _PostMediaPreviewState extends State<PostMediaPreview> {
  Future<String?>? _previewFuture;
  String? _cachedSourceUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensurePreviewFuture();
  }

  @override
  void didUpdateWidget(PostMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _cachedSourceUrl = null;
      _previewFuture = null;
      _ensurePreviewFuture();
    }
  }

  void _ensurePreviewFuture() {
    final url = sanitizeImageUrl(widget.mediaUrl);
    if (url == null || url == _cachedSourceUrl) return;
    _cachedSourceUrl = url;
    if (isDirectImageUrl(url)) {
      _previewFuture = null;
    } else if (isNetworkImageUrl(url)) {
      _previewFuture = fetchOpenGraphImageUrl(url);
    } else {
      _previewFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = sanitizeImageUrl(widget.mediaUrl);
    if (url == null) {
      return const ImagePlaceholder(borderRadius: 8);
    }

    if (isDirectImageUrl(url)) {
      return CachedImageWidget(
        imageUrl: url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorWidget: _buildLinkFallback(url),
      );
    }

    if (!isNetworkImageUrl(url)) {
      return Image.asset(
        url,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(borderRadius: 8),
      );
    }

    _ensurePreviewFuture();
    return FutureBuilder<String?>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: AppTheme.primaryGreen.withValues(alpha: 0.06),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final previewUrl = snapshot.data;
        if (previewUrl != null) {
          return CachedImageWidget(
            imageUrl: previewUrl,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            errorWidget: _buildLinkFallback(url),
          );
        }

        return _buildLinkFallback(url);
      },
    );
  }

  Widget _buildLinkFallback(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    return Container(
      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, color: AppTheme.primaryGreen, size: 28),
          const SizedBox(height: 8),
          Text(
            host,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Link preview unavailable',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

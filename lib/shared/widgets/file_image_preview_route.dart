import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

void pushFileImagePreview(
  BuildContext context, {
  required String imageUrl,
  String? title,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _FileImagePreviewPage(
        imageUrl: imageUrl,
        title: title,
      ),
    ),
  );
}

class _FileImagePreviewPage extends StatelessWidget {
  const _FileImagePreviewPage({
    required this.imageUrl,
    this.title,
  });

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null && title!.trim().isNotEmpty
            ? Text(
                title!.trim(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
            errorWidget: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load image',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

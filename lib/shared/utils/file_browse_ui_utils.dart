import 'package:cap/shared/utils/file_browse_categories.dart';
import 'package:cap/shared/widgets/file_image_preview_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String fileBrowseContributorLabel(Map<String, dynamic> row) {
  final p = row['_profile'];
  if (p is Map) {
    final name = p['full_name'] as String?;
    final u = p['username'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (u != null && u.trim().isNotEmpty) return '@$u';
  }
  return 'Member';
}

String fileBrowseStoragePathFromPublicUrl(String url, String storageUrlMarker) {
  final i = url.indexOf(storageUrlMarker);
  if (i == -1) return '';
  return url.substring(i + storageUrlMarker.length);
}

IconData fileBrowseIconForName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart;
    case 'doc':
    case 'docx':
    case 'odt':
      return Icons.description;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'heic':
      return Icons.image;
    default:
      return Icons.insert_drive_file;
  }
}

Future<void> openFileBrowseRow(
  BuildContext context,
  Map<String, dynamic> row, {
  required void Function(String url) onOpenExternalUrl,
}) async {
  final url = row['file_url'] as String? ?? '';
  if (url.isEmpty) return;
  final fileName = row['file_name'] as String? ?? '';
  final mime = row['mime_type'] as String?;
  final title = row['title'] as String?;
  if (isGalleryImageFile(fileName, mime, url, title)) {
    pushFileImagePreview(
      context,
      imageUrl: url,
      title: title ?? fileName,
    );
  } else {
    onOpenExternalUrl(url);
  }
}

Future<void> launchFileBrowseUrl(
  BuildContext context,
  String url,
) async {
  final u = Uri.tryParse(url);
  if (u == null) return;
  if (!await launchUrl(u, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open file')),
    );
  }
}

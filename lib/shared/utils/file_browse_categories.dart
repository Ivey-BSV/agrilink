import 'package:cap/shared/utils/resource_link_utils.dart';

const _imageExt = {
  'jpg',
  'jpeg',
  'jpe',
  'jfif',
  'png',
  'gif',
  'webp',
  'avif',
  'bmp',
  'heic',
  'heif',
  'ico',
};

bool isPreviewableImage(String fileName, String? mimeType) {
  final mt = mimeType?.toLowerCase().trim() ?? '';
  if (mt.isNotEmpty) {
    if (mt == 'image/svg+xml') return true;
    if (mt.startsWith('image/') && !mt.contains('tiff')) return true;
  }
  final parts = fileName.split('.');
  final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
  if (ext == 'svg') return true;
  return _imageExt.contains(ext);
}

String? fileNameFromPublicUrl(String? fileUrl) {
  if (fileUrl == null || fileUrl.trim().isEmpty) return null;
  try {
    final u = Uri.parse(fileUrl);
    final decoded = Uri.decodeComponent(u.path);
    final parts = decoded.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.last;
  } catch (_) {
    return null;
  }
}

bool isGalleryImageFile(
  String fileName,
  String? mimeType,
  String? fileUrl,
  String? title,
) {
  if (isPreviewableImage(fileName, mimeType)) return true;

  final fromUrl = fileNameFromPublicUrl(fileUrl);
  if (fromUrl != null && isPreviewableImage(fromUrl, null)) return true;

  if (title != null && title.isNotEmpty) {
    if (isPreviewableImage(title, null)) return true;
  }

  return false;
}

typedef FileBrowseMap = Map<String, dynamic>;

typedef FileBrowseSplit = ({
  List<FileBrowseMap> gallery,
  List<FileBrowseMap> documents,
  List<FileBrowseMap> links,
});

FileBrowseSplit splitGalleryDocumentsAndLinks(
  List<FileBrowseMap> items, {
  required String storageUrlMarker,
  bool includeLinks = true,
}) {
  final gallery = <FileBrowseMap>[];
  final documents = <FileBrowseMap>[];
  final links = <FileBrowseMap>[];
  for (final item in items) {
    final fn = item['file_name'] as String? ?? '';
    final mime = item['mime_type'] as String?;
    final url = item['file_url'] as String?;
    final title = item['title'] as String?;
    if (isGalleryImageFile(fn, mime, url, title)) {
      gallery.add(item);
    } else if (includeLinks &&
        isResourceLinkRow(url, mime, storageUrlMarker: storageUrlMarker)) {
      links.add(item);
    } else {
      documents.add(item);
    }
  }
  return (gallery: gallery, documents: documents, links: links);
}

({List<FileBrowseMap> gallery, List<FileBrowseMap> documents})
    splitGalleryAndDocuments(List<FileBrowseMap> items) {
  final split = splitGalleryDocumentsAndLinks(
    items,
    storageUrlMarker: '/knowledge-repository/',
    includeLinks: false,
  );
  return (gallery: split.gallery, documents: split.documents);
}

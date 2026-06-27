import 'package:cap/shared/utils/image_url_utils.dart';

const String kMimeResourceLink = 'text/uri-list';
const String kMimeYouTubeLink = 'video/youtube';

final RegExp _youTubeHostPattern = RegExp(
  r'^(https?:\/\/)?(www\.|m\.)?(youtube\.com|youtu\.be)\/',
  caseSensitive: false,
);

final List<RegExp> _youTubeIdPatterns = [
  RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})', caseSensitive: false),
  RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})', caseSensitive: false),
  RegExp(r'embed/([a-zA-Z0-9_-]{11})', caseSensitive: false),
  RegExp(r'shorts/([a-zA-Z0-9_-]{11})', caseSensitive: false),
];

String? normalizeResourceLinkUrl(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains('://')) {
    trimmed = 'https://$trimmed';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri.toString();
}

bool isHttpResourceUrl(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

bool isYouTubeUrl(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return false;
  return _youTubeHostPattern.hasMatch(url);
}

String? extractYouTubeVideoId(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return null;
  for (final pattern in _youTubeIdPatterns) {
    final match = pattern.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
  }
  return null;
}

String? youTubeThumbnailUrl(String? raw, {String quality = 'hqdefault'}) {
  final id = extractYouTubeVideoId(raw);
  if (id == null) return null;
  return 'https://img.youtube.com/vi/$id/$quality.jpg';
}

String linkDisplayHost(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return 'link';
  if (isYouTubeUrl(url)) return 'YouTube';
  try {
    return Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '');
  } catch (_) {
    return 'link';
  }
}

bool isStoredBucketFileUrl(String? fileUrl, String storageUrlMarker) {
  final url = sanitizeImageUrl(fileUrl);
  if (url == null) return false;
  return url.contains(storageUrlMarker) ||
      url.contains('/storage/v1/object/public/');
}

bool isResourceLinkRow(
  String? fileUrl,
  String? mimeType, {
  required String storageUrlMarker,
}) {
  final mime = mimeType?.toLowerCase().trim() ?? '';
  if (mime == kMimeResourceLink || mime == kMimeYouTubeLink) return true;

  if (!isHttpResourceUrl(fileUrl)) return false;
  if (isStoredBucketFileUrl(fileUrl, storageUrlMarker)) return false;

  final url = fileUrl!;
  if (isDirectImageUrl(url)) return false;

  return true;
}

Map<String, dynamic> buildResourceLinkInsertRow({
  required String folderId,
  required String userId,
  required String title,
  required String url,
}) {
  final normalized = normalizeResourceLinkUrl(url)!;
  final isYouTube = isYouTubeUrl(normalized);
  return {
    'folder_id': folderId,
    'user_id': userId,
    'title': title.trim(),
    'file_url': normalized,
    'file_name': linkDisplayHost(normalized),
    'mime_type': isYouTube ? kMimeYouTubeLink : kMimeResourceLink,
    'approval_status': 'approved',
    'visibility_rules': <String, dynamic>{},
  };
}

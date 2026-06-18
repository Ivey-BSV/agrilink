import 'dart:convert';

String? sanitizeImageUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? imageUrlWithCacheBust(String? raw, String cacheKey) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return null;
  return url.contains('?') ? '$url&_u=$cacheKey' : '$url?_u=$cacheKey';
}

bool isNetworkImageUrl(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

List<String> parsePostImageUrls(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .map((entry) => sanitizeImageUrl(entry?.toString()))
        .whereType<String>()
        .toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return parsePostImageUrls(decoded);
      } catch (_) {}
    }
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return [];
      return inner
          .split(',')
          .map((part) => sanitizeImageUrl(part.replaceAll('"', '').trim()))
          .whereType<String>()
          .toList();
    }
    final single = sanitizeImageUrl(trimmed);
    return single != null ? [single] : [];
  }
  return [];
}

String? firstPostImageUrl(dynamic raw) {
  final urls = parsePostImageUrls(raw);
  return urls.isEmpty ? null : urls.first;
}

const _supabaseObjectPublic = '/storage/v1/object/public/';
const _supabaseRenderPublic = '/storage/v1/render/image/public/';

String? supabaseRenderImageUrl(String? raw, {int width = 1200}) {
  final url = sanitizeImageUrl(raw);
  if (url == null || !url.contains(_supabaseObjectPublic)) return null;
  final uri =
      Uri.parse(url.replaceFirst(_supabaseObjectPublic, _supabaseRenderPublic));
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    'width': width.toString(),
  }).toString();
}

String? networkDisplayImageUrl(String? raw, {int renderWidth = 1200}) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return null;
  final lower = url.toLowerCase();
  if (lower.contains('.heic') || lower.contains('.heif')) {
    return supabaseRenderImageUrl(url, width: renderWidth) ?? url;
  }
  return url;
}

bool isDirectImageUrl(String? raw) {
  final url = sanitizeImageUrl(raw);
  if (url == null) return false;

  final lower = url.toLowerCase();
  if (lower.contains('/storage/v1/object/public/') ||
      lower.contains('/storage/v1/render/image/public/') ||
      lower.contains('/post-images/')) {
    return true;
  }

  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  const extensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
    '.avif',
  ];
  for (final ext in extensions) {
    if (path.endsWith(ext)) return true;
  }
  return false;
}

bool isVideoMediaUrl(String? raw) {
  final url = sanitizeImageUrl(raw)?.toLowerCase();
  if (url == null) return false;
  if (url.contains('/post-videos/')) return true;
  return url.endsWith('.mp4') ||
      url.endsWith('.mov') ||
      url.endsWith('.avi') ||
      url.endsWith('.mkv') ||
      url.endsWith('.webm');
}

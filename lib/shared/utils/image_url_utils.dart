/// Normalizes image URLs from the API (trim whitespace, drop empty values).
String? sanitizeImageUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Optional cache-bust query param used for profile avatars in app bars.
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

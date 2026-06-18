import 'package:http/http.dart' as http;
import 'package:cap/shared/utils/image_url_utils.dart';

final Map<String, String?> _ogImageCache = {};

Future<String?> fetchOpenGraphImageUrl(String pageUrl) async {
  final normalized = sanitizeImageUrl(pageUrl);
  if (normalized == null) return null;
  if (_ogImageCache.containsKey(normalized)) {
    return _ogImageCache[normalized];
  }

  try {
    final uri = Uri.parse(normalized);
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (compatible; AgriLink/1.0; +https://agrilink.app)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      _ogImageCache[normalized] = null;
      return null;
    }

    final imageUrl = _parsePreviewImageFromHtml(response.body, normalized);
    _ogImageCache[normalized] = imageUrl;
    return imageUrl;
  } catch (_) {
    _ogImageCache[normalized] = null;
    return null;
  }
}

String? _parsePreviewImageFromHtml(String html, String pageUrl) {
  final patterns = [
    RegExp(
      r'''property=["']og:image["'][^>]*content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''content=["']([^"']+)["'][^>]*property=["']og:image["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''name=["']twitter:image["'][^>]*content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''content=["']([^"']+)["'][^>]*name=["']twitter:image["']''',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(html);
    if (match == null) continue;
    final resolved = _resolvePreviewImageUrl(match.group(1)!, pageUrl);
    if (resolved != null) return resolved;
  }
  return null;
}

String? _resolvePreviewImageUrl(String raw, String pageUrl) {
  var imageUrl = raw.trim().replaceAll('&amp;', '&');
  if (imageUrl.isEmpty) return null;

  if (imageUrl.startsWith('//')) {
    imageUrl = 'https:$imageUrl';
  } else if (imageUrl.startsWith('/')) {
    final base = Uri.parse(pageUrl);
    imageUrl = '${base.scheme}://${base.host}$imageUrl';
  }

  return sanitizeImageUrl(imageUrl);
}

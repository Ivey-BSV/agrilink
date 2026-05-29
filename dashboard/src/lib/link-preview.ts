import { isNetworkImageUrl, sanitizeImageUrl } from "@/lib/image-urls";

const ogImageCache = new Map<string, string | null>();

const OG_PATTERNS = [
  /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["'][^>]*>/i,
  /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["'][^>]*>/i,
  /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["'][^>]*>/i,
  /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["'][^>]*>/i,
];

function resolvePreviewImageUrl(raw: string, pageUrl: string): string | null {
  let imageUrl = raw.trim().replace(/&amp;/g, "&");
  if (!imageUrl) return null;

  if (imageUrl.startsWith("//")) {
    imageUrl = `https:${imageUrl}`;
  } else if (imageUrl.startsWith("/")) {
    try {
      const base = new URL(pageUrl);
      imageUrl = `${base.protocol}//${base.host}${imageUrl}`;
    } catch {
      return null;
    }
  }

  return sanitizeImageUrl(imageUrl);
}

export function parseOpenGraphImageFromHtml(html: string, pageUrl: string): string | null {
  for (const pattern of OG_PATTERNS) {
    const match = html.match(pattern);
    if (!match?.[1]) continue;
    const resolved = resolvePreviewImageUrl(match[1], pageUrl);
    if (resolved) return resolved;
  }
  return null;
}

/** Server-side fetch of og:image / twitter:image for a webpage URL. */
export async function fetchOpenGraphImageUrl(pageUrl: string): Promise<string | null> {
  const normalized = sanitizeImageUrl(pageUrl);
  if (!normalized || !isNetworkImageUrl(normalized)) return null;

  if (ogImageCache.has(normalized)) {
    return ogImageCache.get(normalized) ?? null;
  }

  try {
    const response = await fetch(normalized, {
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; AgriLink/1.0; +https://agrilink.app)",
        Accept: "text/html,application/xhtml+xml",
      },
      signal: AbortSignal.timeout(10_000),
    });

    if (!response.ok) {
      ogImageCache.set(normalized, null);
      return null;
    }

    const html = await response.text();
    const imageUrl = parseOpenGraphImageFromHtml(html, normalized);
    ogImageCache.set(normalized, imageUrl);
    return imageUrl;
  } catch {
    ogImageCache.set(normalized, null);
    return null;
  }
}

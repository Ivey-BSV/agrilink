import { parseImageUrls } from "@/lib/media-urls";

export { parseImageUrls };

export function sanitizeImageUrl(raw: string | null | undefined): string | null {
  if (raw == null) return null;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function isNetworkImageUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw);
  if (!url) return false;
  return url.startsWith("http://") || url.startsWith("https://");
}

/** True when the URL likely points at an image file, not a webpage. */
export function isDirectImageUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw);
  if (!url) return false;

  const lower = url.toLowerCase();
  if (
    lower.includes("/storage/v1/object/public/") ||
    lower.includes("/storage/v1/render/image/public/") ||
    lower.includes("/post-images/") ||
    lower.includes("/marketplace-images/")
  ) {
    return true;
  }

  let path = url;
  try {
    path = new URL(url).pathname;
  } catch {
    /* use full url */
  }
  const pathLower = path.toLowerCase();
  const extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".heic", ".heif", ".avif"];
  return extensions.some((ext) => pathLower.endsWith(ext));
}

export function isVideoMediaUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw)?.toLowerCase();
  if (!url) return false;
  if (url.includes("/post-videos/")) return true;
  return (
    url.endsWith(".mp4") ||
    url.endsWith(".mov") ||
    url.endsWith(".avi") ||
    url.endsWith(".mkv") ||
    url.endsWith(".webm") ||
    url.includes(".mp4?")
  );
}

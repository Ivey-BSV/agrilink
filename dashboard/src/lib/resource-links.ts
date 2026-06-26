import { isDirectImageUrl, sanitizeImageUrl } from "@/lib/image-urls";

export const MIME_RESOURCE_LINK = "text/uri-list";
export const MIME_YOUTUBE_LINK = "video/youtube";

const YOUTUBE_HOST = /^(https?:\/\/)?(www\.|m\.)?(youtube\.com|youtu\.be)\//i;

const YOUTUBE_ID_PATTERNS = [
  /youtu\.be\/([a-zA-Z0-9_-]{11})/i,
  /[?&]v=([a-zA-Z0-9_-]{11})/i,
  /embed\/([a-zA-Z0-9_-]{11})/i,
  /shorts\/([a-zA-Z0-9_-]{11})/i,
];

export function normalizeResourceLinkUrl(raw: string): string | null {
  let trimmed = raw.trim();
  if (!trimmed) return null;
  if (!trimmed.includes("://")) trimmed = `https://${trimmed}`;
  try {
    const uri = new URL(trimmed);
    if (uri.protocol !== "http:" && uri.protocol !== "https:") return null;
    if (!uri.hostname) return null;
    return uri.toString();
  } catch {
    return null;
  }
}

export function isHttpResourceUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw);
  if (!url) return false;
  return url.startsWith("http://") || url.startsWith("https://");
}

export function isYouTubeUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw);
  if (!url) return false;
  return YOUTUBE_HOST.test(url);
}

export function extractYouTubeVideoId(raw: string | null | undefined): string | null {
  const url = sanitizeImageUrl(raw);
  if (!url) return null;
  for (const pattern of YOUTUBE_ID_PATTERNS) {
    const match = pattern.exec(url);
    if (match?.[1]) return match[1];
  }
  return null;
}

export function youTubeThumbnailUrl(raw: string | null | undefined, quality = "hqdefault"): string | null {
  const id = extractYouTubeVideoId(raw);
  if (!id) return null;
  return `https://img.youtube.com/vi/${id}/${quality}.jpg`;
}

export function linkDisplayHost(raw: string | null | undefined): string {
  const url = sanitizeImageUrl(raw);
  if (!url) return "link";
  if (isYouTubeUrl(url)) return "YouTube";
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "link";
  }
}

export function isStoredBucketFileUrl(fileUrl: string | null | undefined, storageUrlMarker: string): boolean {
  const url = sanitizeImageUrl(fileUrl);
  if (!url) return false;
  return url.includes(storageUrlMarker) || url.includes("/storage/v1/object/public/");
}

export function isResourceLinkRow(
  fileUrl: string | null | undefined,
  mimeType: string | null | undefined,
  storageUrlMarker: string
): boolean {
  const mime = (mimeType ?? "").toLowerCase().trim();
  if (mime === MIME_RESOURCE_LINK || mime === MIME_YOUTUBE_LINK) return true;
  if (!isHttpResourceUrl(fileUrl)) return false;
  if (isStoredBucketFileUrl(fileUrl, storageUrlMarker)) return false;
  if (isDirectImageUrl(fileUrl)) return false;
  return true;
}

export function buildResourceLinkInsertRow(params: {
  folderId: string;
  userId: string;
  title: string;
  url: string;
  legacyWorkshopId?: string | null;
}): Record<string, unknown> {
  const normalized = normalizeResourceLinkUrl(params.url);
  if (!normalized) throw new Error("Invalid URL");
  const isYouTube = isYouTubeUrl(normalized);
  const row: Record<string, unknown> = {
    folder_id: params.folderId,
    user_id: params.userId,
    title: params.title.trim(),
    file_url: normalized,
    file_name: linkDisplayHost(normalized),
    mime_type: isYouTube ? MIME_YOUTUBE_LINK : MIME_RESOURCE_LINK,
    approval_status: "approved",
    visibility_rules: {},
  };
  if (params.legacyWorkshopId) {
    row.workshop_id = params.legacyWorkshopId;
  }
  return row;
}

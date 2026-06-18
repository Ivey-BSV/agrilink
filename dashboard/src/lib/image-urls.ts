const SUPABASE_OBJECT_PUBLIC = "/storage/v1/object/public/";
const SUPABASE_RENDER_PUBLIC = "/storage/v1/render/image/public/";

export function sanitizeImageUrl(raw: string | null | undefined): string | null {
  if (raw == null) return null;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
}


export function supabaseRenderImageUrl(raw: string | null | undefined, width = 1200): string | null {
  const url = sanitizeImageUrl(raw);
  if (!url || !url.includes(SUPABASE_OBJECT_PUBLIC)) return null;
  const render = url.replace(SUPABASE_OBJECT_PUBLIC, SUPABASE_RENDER_PUBLIC);
  try {
    const uri = new URL(render);
    uri.searchParams.set("width", String(width));
    return uri.toString();
  } catch {
    const sep = render.includes("?") ? "&" : "?";
    return `${render}${sep}width=${width}`;
  }
}


export function networkDisplayImageUrl(raw: string | null | undefined, renderWidth = 1200): string | null {
  const url = sanitizeImageUrl(raw);
  if (!url) return null;
  const lower = url.toLowerCase();
  if (lower.includes(".heic") || lower.includes(".heif")) {
    return supabaseRenderImageUrl(url, renderWidth) ?? url;
  }
  return url;
}

export function isNetworkImageUrl(raw: string | null | undefined): boolean {
  const url = sanitizeImageUrl(raw);
  if (!url) return false;
  return url.startsWith("http://") || url.startsWith("https://");
}


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

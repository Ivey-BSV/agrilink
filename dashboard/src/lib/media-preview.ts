const IMAGE_EXT = new Set(["jpg", "jpeg", "jpe", "jfif", "png", "gif", "webp", "avif", "bmp", "heic", "heif", "ico"]);

const VIDEO_EXT = new Set(["mp4", "webm", "ogv", "mov", "m4v", "mkv"]);
const AUDIO_EXT = new Set(["mp3", "wav", "ogg", "oga", "m4a", "aac", "flac", "opus", "weba"]);
const TEXT_EXT = new Set([
  "txt",
  "csv",
  "tsv",
  "log",
  "md",
  "markdown",
  "json",
  "xml",
  "yaml",
  "yml",
  "html",
  "htm",
  "css",
  "js",
  "ts",
  "tsx",
  "jsx",
]);

export type InlinePreviewKind = "image" | "pdf" | "video" | "audio" | "text" | "unsupported";

export function getInlinePreviewKind(fileName: string, mimeType?: string | null): InlinePreviewKind {
  const mt = (mimeType ?? "").toLowerCase().trim();
  const ext = fileName.split(".").pop()?.toLowerCase() ?? "";

  if (isPreviewableImage(fileName, mimeType)) return "image";
  if (mt === "application/pdf" || ext === "pdf") return "pdf";
  if (mt.startsWith("audio/")) return "audio";
  if (mt.startsWith("video/")) return "video";
  if (AUDIO_EXT.has(ext)) return "audio";
  if (VIDEO_EXT.has(ext)) return "video";
  if (
    mt.startsWith("text/") ||
    mt === "application/json" ||
    mt === "application/xml" ||
    mt === "application/javascript" ||
    mt === "text/javascript" ||
    TEXT_EXT.has(ext)
  ) {
    return "text";
  }
  return "unsupported";
}

export function isPreviewableImage(fileName: string, mimeType?: string | null): boolean {
  const mt = mimeType?.toLowerCase().trim();
  if (mt) {
    if (mt === "image/svg+xml") return true;
    if (mt.startsWith("image/") && !mt.includes("tiff")) return true;
  }
  const ext = fileName.split(".").pop()?.toLowerCase() ?? "";
  if (ext === "svg") return true;
  return IMAGE_EXT.has(ext);
}

export function fileExtension(fileName: string): string {
  const ext = fileName.split(".").pop()?.toUpperCase() ?? "FILE";
  return ext.length > 8 ? ext.slice(0, 8) : ext;
}

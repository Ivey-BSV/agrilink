import { isPreviewableImage } from "@/lib/media-preview";
import { isResourceLinkRow } from "@/lib/resource-links";

function fileNameFromPublicUrl(fileUrl: string | null | undefined): string | null {
  if (!fileUrl || !fileUrl.trim()) return null;
  try {
    const u = new URL(fileUrl);
    const decoded = decodeURIComponent(u.pathname);
    const parts = decoded.split("/").filter(Boolean);
    if (parts.length === 0) return null;
    return parts[parts.length - 1] ?? null;
  } catch {
    return null;
  }
}

export function isGalleryImageFile(
  fileName: string,
  mimeType?: string | null,
  fileUrl?: string | null,
  title?: string | null
): boolean {
  if (isPreviewableImage(fileName, mimeType)) return true;

  const fromUrl = fileNameFromPublicUrl(fileUrl ?? undefined);
  if (fromUrl && isPreviewableImage(fromUrl, null)) return true;

  if (title && isPreviewableImage(title, null)) return true;

  return false;
}

export function splitGalleryAndDocuments<
  T extends { file_name: string; mime_type?: string | null; file_url?: string | null; title?: string }
>(items: T[]): { gallery: T[]; documents: T[] } {
  const split = splitGalleryDocumentsAndLinks(items, "/knowledge-repository/", false);
  return { gallery: split.gallery, documents: split.documents };
}

export function splitGalleryDocumentsAndLinks<
  T extends { file_name: string; mime_type?: string | null; file_url?: string | null; title?: string }
>(
  items: T[],
  storageUrlMarker: string,
  includeLinks = true
): { gallery: T[]; documents: T[]; links: T[] } {
  const gallery: T[] = [];
  const documents: T[] = [];
  const links: T[] = [];
  for (const item of items) {
    if (isGalleryImageFile(item.file_name, item.mime_type, item.file_url ?? null, item.title ?? null)) {
      gallery.push(item);
    } else if (
      includeLinks &&
      isResourceLinkRow(item.file_url ?? null, item.mime_type ?? null, storageUrlMarker)
    ) {
      links.push(item);
    } else {
      documents.push(item);
    }
  }
  return { gallery, documents, links };
}

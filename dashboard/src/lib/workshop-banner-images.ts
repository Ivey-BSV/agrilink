import { isGalleryImageFile } from "@/lib/file-browse-layout";
import { networkDisplayImageUrl } from "@/lib/image-urls";
import { supabase } from "@/lib/supabase";

export type WorkshopBannerImage = {
  id: string;
  url: string;
  fullUrl: string;
  title: string | null;
  folderId: string | null;
  folderName: string | null;
};

type WorkshopDocRow = {
  id: string;
  folder_id: string | null;
  title: string;
  file_name: string;
  file_url: string;
  mime_type?: string | null;
};

const DOC_SELECT = "id, folder_id, title, file_name, file_url, mime_type";

function isHeicFile(row: Pick<WorkshopDocRow, "file_name" | "file_url" | "title" | "mime_type">): boolean {
  const mt = row.mime_type?.toLowerCase().trim();
  if (mt === "image/heic" || mt === "image/heif") return true;

  for (const value of [row.file_name, row.file_url, row.title]) {
    if (!value) continue;
    const lower = value.toLowerCase();
    if (lower.includes(".heic") || lower.includes(".heif")) return true;
  }

  return false;
}

function shuffle<T>(items: T[]): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** Repeat a shuffled set until the marquee has enough tiles to fill the viewport. */
export function buildMarqueeSequence(images: WorkshopBannerImage[], minPerHalf = 12): WorkshopBannerImage[] {
  if (images.length === 0) return [];

  const half: WorkshopBannerImage[] = [];
  let i = 0;
  while (half.length < minPerHalf) {
    half.push(images[i % images.length]);
    i += 1;
  }

  return [...half, ...half];
}

export async function loadWorkshopBannerImages(limit = 28): Promise<{
  images: WorkshopBannerImage[];
  error: string | null;
}> {
  const { data, error } = await supabase
    .from("workshop_documents")
    .select(DOC_SELECT)
    .not("file_url", "is", null)
    .order("created_at", { ascending: false })
    .limit(600);

  if (error) return { images: [], error: error.message };

  const gallery = ((data as WorkshopDocRow[]) ?? []).filter(
    (row) =>
      isGalleryImageFile(row.file_name, row.mime_type, row.file_url, row.title) && !isHeicFile(row),
  );

  const folderIds = [...new Set(gallery.map((row) => row.folder_id).filter(Boolean))] as string[];
  const folderNames = new Map<string, string>();

  if (folderIds.length > 0) {
    const { data: folders } = await supabase.from("resource_folders").select("id, name").in("id", folderIds);
    for (const folder of (folders as { id: string; name: string }[] | null) ?? []) {
      folderNames.set(folder.id, folder.name);
    }
  }

  const images = shuffle(gallery)
    .slice(0, limit)
    .map((row) => {
      const fullUrl = networkDisplayImageUrl(row.file_url, 1200) ?? row.file_url;
      const url = networkDisplayImageUrl(row.file_url, 520) ?? row.file_url;
      return {
        id: row.id,
        url,
        fullUrl,
        title: row.title?.trim() || row.file_name || null,
        folderId: row.folder_id,
        folderName: row.folder_id ? folderNames.get(row.folder_id) ?? null : null,
      };
    })
    .filter((row) => row.url.length > 0);

  return { images, error: null };
}

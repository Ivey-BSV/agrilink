"use client";

import { FileRowThumb } from "@/components/file-row-thumb";

function fileNameFromUrl(url: string): string {
  try {
    const u = new URL(url);
    const last = u.pathname.split("/").filter(Boolean).pop() ?? "media";
    return decodeURIComponent(last.split("?")[0] ?? "media");
  } catch {
    return "media.jpg";
  }
}

export function ContentThumbCell({ imageUrl }: { imageUrl: string | null | undefined }) {
  const url = imageUrl?.trim() ?? "";
  if (!url) {
    return (
      <div className="workshop-thumb-placeholder content-thumb-empty" title="No image" aria-hidden>
        —
      </div>
    );
  }
  return <FileRowThumb fileUrl={url} fileName={fileNameFromUrl(url)} mimeType={null} />;
}

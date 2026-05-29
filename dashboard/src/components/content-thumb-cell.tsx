"use client";

import { useState } from "react";
import { FilePreviewModal } from "@/components/file-preview-modal";
import { PostMediaPreview } from "@/components/post-media-preview";

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
  const [previewOpen, setPreviewOpen] = useState(false);
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null);

  if (!url) {
    return (
      <div className="workshop-thumb-placeholder content-thumb-empty" title="No image" aria-hidden>
        —
      </div>
    );
  }

  return (
    <>
      <PostMediaPreview
        compact
        mediaUrl={url}
        triggerClassName="workshop-thumb-wrap file-preview-trigger"
        imageClassName="workshop-thumb"
        onOpen={(displayUrl) => {
          setLightboxUrl(displayUrl);
          setPreviewOpen(true);
        }}
      />
      {lightboxUrl ? (
        <FilePreviewModal
          open={previewOpen}
          onClose={() => {
            setPreviewOpen(false);
            setLightboxUrl(null);
          }}
          fileUrl={lightboxUrl}
          fileName={fileNameFromUrl(lightboxUrl)}
          mimeType={null}
        />
      ) : null}
    </>
  );
}

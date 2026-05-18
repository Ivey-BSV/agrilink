"use client";

import { useState } from "react";
import { fileExtension, isPreviewableImage } from "@/lib/media-preview";
import { FilePreviewModal } from "@/components/file-preview-modal";

type FileRowThumbProps = {
  fileUrl: string;
  fileName: string;
  mimeType?: string | null;
  editing?: boolean;
};

export function FileRowThumb({ fileUrl, fileName, mimeType, editing }: FileRowThumbProps) {
  const [broken, setBroken] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false);

  if (editing) {
    return (
      <div className="workshop-thumb-placeholder" title="Editing metadata">
        Edit
      </div>
    );
  }

  const showImg = isPreviewableImage(fileName, mimeType) && !broken;

  const label = `Preview ${fileName}`;

  if (!showImg) {
    return (
      <>
        <button
          type="button"
          className="workshop-thumb-placeholder file-preview-trigger"
          title={label}
          aria-label={label}
          onClick={() => setPreviewOpen(true)}
        >
          {fileExtension(fileName)}
        </button>
        <FilePreviewModal
          open={previewOpen}
          onClose={() => setPreviewOpen(false)}
          fileUrl={fileUrl}
          fileName={fileName}
          mimeType={mimeType}
        />
      </>
    );
  }

  return (
    <>
      <button
        type="button"
        className="workshop-thumb-wrap file-preview-trigger"
        title={label}
        aria-label={label}
        aria-haspopup="dialog"
        onClick={() => setPreviewOpen(true)}
      >
        <img
          src={fileUrl}
          alt=""
          className="workshop-thumb"
          loading="lazy"
          onError={() => setBroken(true)}
        />
      </button>
      <FilePreviewModal
        open={previewOpen}
        onClose={() => setPreviewOpen(false)}
        fileUrl={fileUrl}
        fileName={fileName}
        mimeType={mimeType}
      />
    </>
  );
}

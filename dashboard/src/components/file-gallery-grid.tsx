"use client";

import { useState, type ReactNode } from "react";
import { FilePreviewModal } from "@/components/file-preview-modal";
import { isGalleryImageFile } from "@/lib/file-browse-layout";

export type GalleryGridItem = {
  id: string;
  title: string;
  file_name: string;
  file_url: string;
  mime_type?: string | null;
};

type FileGalleryGridProps<T extends GalleryGridItem> = {
  items: T[];
  subtitle?: (item: T) => string | null;
  renderFooter: (item: T) => ReactNode;
};

export function FileGalleryGrid<T extends GalleryGridItem>({ items, subtitle, renderFooter }: FileGalleryGridProps<T>) {
  const [preview, setPreview] = useState<T | null>(null);
  const [brokenIds, setBrokenIds] = useState<Set<string>>(() => new Set());

  if (items.length === 0) return null;

  return (
    <>
      <div className="file-gallery-grid" role="list">
        {items.map((item) => {
          const sub = subtitle?.(item);
          const canImg =
            isGalleryImageFile(item.file_name, item.mime_type, item.file_url, item.title) && !brokenIds.has(item.id);
          return (
            <article key={item.id} className="file-gallery-card" role="listitem">
              <button
                type="button"
                className="file-gallery-thumb-btn"
                aria-label={`Preview ${item.file_name}`}
                onClick={() => setPreview(item)}
              >
                {canImg ? (
                  <img
                    src={item.file_url}
                    alt=""
                    className="file-gallery-thumb-img"
                    loading="lazy"
                    onError={() =>
                      setBrokenIds((prev) => {
                        const next = new Set(prev);
                        next.add(item.id);
                        return next;
                      })
                    }
                  />
                ) : (
                  <span className="file-gallery-thumb-fallback subtle">Preview unavailable</span>
                )}
              </button>
              <div className="file-gallery-card-body">
                <div className="file-gallery-card-title" title={item.title}>
                  {item.title}
                </div>
                {sub ? <div className="file-gallery-card-sub subtle">{sub}</div> : null}
                <div className="file-gallery-card-meta subtle">{item.file_name}</div>
                <div className="file-gallery-card-actions">{renderFooter(item)}</div>
              </div>
            </article>
          );
        })}
      </div>

      {preview ? (
        <FilePreviewModal
          open
          onClose={() => setPreview(null)}
          fileUrl={preview.file_url}
          fileName={preview.file_name}
          mimeType={preview.mime_type}
        />
      ) : null}
    </>
  );
}

"use client";

import type { FormEvent, ReactNode } from "react";

type FileUploadModalProps = {
  open: boolean;
  title: string;
  onClose: () => void;
  onSubmit: () => void | Promise<void>;
  submitting?: boolean;
  submitLabel?: string;
  children: ReactNode;
};

export function FileUploadModal({
  open,
  title,
  onClose,
  onSubmit,
  submitting = false,
  submitLabel = "Upload",
  children,
}: FileUploadModalProps) {
  if (!open) return null;

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    void onSubmit();
  };

  return (
    <div className="backdrop active" role="dialog" aria-modal="true" aria-labelledby="file-upload-modal-title">
      <div className="absolute inset-0" onClick={submitting ? undefined : onClose} aria-hidden />
      <div className="modal-content platform-create-modal file-upload-modal" style={{ opacity: 1, transform: "none" }}>
        <form className="stack" style={{ gap: 14 }} onSubmit={handleSubmit}>
          <h3 id="file-upload-modal-title" className="section-title" style={{ margin: 0 }}>
            {title}
          </h3>
          {children}
          <div className="file-upload-modal-actions">
            <button type="button" className="btn btn-secondary" onClick={onClose} disabled={submitting}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Uploading…" : submitLabel}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

"use client";


import { AnimatePresence, motion } from "framer-motion";
import { createPortal } from "react-dom";
import { useCallback, useEffect, useId, useRef, useState, type MouseEvent, type ReactNode } from "react";
import { getInlinePreviewKind, type InlinePreviewKind } from "@/lib/media-preview";

const TEXT_PREVIEW_MAX_CHARS = 350_000;

async function fetchTextCapped(url: string, maxChars: number): Promise<string> {
  const res = await fetch(url, { mode: "cors", credentials: "omit" });
  if (!res.ok) throw new Error("fetch_failed");
  const reader = res.body?.getReader();
  if (!reader) {
    const t = await res.text();
    return t.length > maxChars ? t.slice(0, maxChars) + "\n\n… (truncated)" : t;
  }
  const decoder = new TextDecoder();
  let out = "";
  while (out.length < maxChars) {
    const { done, value } = await reader.read();
    if (done) break;
    out += decoder.decode(value, { stream: true });
    if (out.length > maxChars) {
      out = out.slice(0, maxChars) + "\n\n… (truncated)";
      await reader.cancel().catch(() => {});
      break;
    }
  }
  return out;
}

export type FilePreviewModalProps = {
  open: boolean;
  onClose: () => void;
  fileUrl: string;
  fileName: string;
  mimeType?: string | null;
  subtitle?: string | null;
  hideFooter?: boolean;
};

export function FilePreviewModal({
  open,
  onClose,
  fileUrl,
  fileName,
  mimeType,
  subtitle,
  hideFooter = false,
}: FilePreviewModalProps) {
  const titleId = useId();
  const closeBtnRef = useRef<HTMLButtonElement>(null);
  const [mediaError, setMediaError] = useState(false);
  const [textState, setTextState] = useState<"idle" | "loading" | "ok" | "error">("idle");
  const [textBody, setTextBody] = useState("");

  const kind: InlinePreviewKind = open ? getInlinePreviewKind(fileName, mimeType) : "unsupported";

  useEffect(() => {
    if (!open) {
      setMediaError(false);
      setTextState("idle");
      setTextBody("");
      return;
    }
    setMediaError(false);
    if (kind !== "text") {
      setTextState("idle");
      setTextBody("");
      return;
    }
    let cancelled = false;
    setTextState("loading");
    fetchTextCapped(fileUrl, TEXT_PREVIEW_MAX_CHARS)
      .then((t) => {
        if (!cancelled) {
          setTextBody(t);
          setTextState("ok");
        }
      })
      .catch(() => {
        if (!cancelled) setTextState("error");
      });
    return () => {
      cancelled = true;
    };
  }, [open, kind, fileUrl]);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  useEffect(() => {
    if (open) closeBtnRef.current?.focus();
  }, [open]);

  const handleBackdrop = useCallback(
    (e: MouseEvent<HTMLDivElement>) => {
      if (e.target === e.currentTarget) onClose();
    },
    [onClose]
  );

  const mediaKinds: InlinePreviewKind[] = ["image", "video", "audio"];
  const showMediaFallback = mediaError && mediaKinds.includes(kind);

  let body: ReactNode;
  if (showMediaFallback) {
    body = (
      <p className="preview-modal-hint">
        Could not load preview in the browser. Use <strong>Open in new tab</strong> below.
      </p>
    );
  } else {
    switch (kind) {
      case "image":
        body = (
          <div className="preview-modal-media-frame">
            <img
              src={fileUrl}
              alt={fileName}
              className="preview-modal-img"
              onError={() => setMediaError(true)}
            />
          </div>
        );
        break;
      case "pdf":
        body = <iframe title={fileName} src={fileUrl} className="preview-modal-iframe" />;
        break;
      case "video":
        body = (
          <video src={fileUrl} controls className="preview-modal-video" onError={() => setMediaError(true)} />
        );
        break;
      case "audio":
        body = (
          <div className="preview-modal-audio-wrap">
            <audio src={fileUrl} controls className="preview-modal-audio" onError={() => setMediaError(true)} />
          </div>
        );
        break;
      case "text":
        if (textState === "loading" || textState === "idle") {
          body = <p className="preview-modal-hint subtle">Loading text preview…</p>;
        } else if (textState === "error") {
          body = (
            <p className="preview-modal-hint">
              Text preview failed (network or CORS). Try <strong>Open in new tab</strong>.
            </p>
          );
        } else {
          body = (
            <pre className="preview-modal-pre" tabIndex={0}>
              {textBody}
            </pre>
          );
        }
        break;
      default:
        body = (
          <div className="preview-modal-placeholder">
            <p className="preview-modal-hint">
              There is no in-browser preview for this file type in the dashboard (for example Word or Excel
              binaries).
            </p>
            <p className="subtle" style={{ marginTop: 8 }}>
              Use <strong>Open in new tab</strong> to download or open the file with an app on your device.
            </p>
          </div>
        );
    }
  }

  if (typeof document === "undefined") return null;

  return createPortal(
    <AnimatePresence>
      {open ? (
        <motion.div
          key="file-preview-modal"
          className="preview-modal-backdrop"
          role="presentation"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          onMouseDown={handleBackdrop}
        >
          <motion.div
            className="preview-modal-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            initial={{ opacity: 0, scale: 0.96, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 12 }}
            transition={{ type: "spring", stiffness: 400, damping: 32 }}
            onMouseDown={(e) => e.stopPropagation()}
          >
            <header className="preview-modal-header">
              <div className="preview-modal-heading">
                <h2 id={titleId} className="preview-modal-title">
                  {fileName}
                </h2>
                {subtitle ? <p className="preview-modal-subtitle">{subtitle}</p> : null}
              </div>
              <button
                ref={closeBtnRef}
                type="button"
                className="preview-modal-close"
                aria-label="Close preview"
                onClick={onClose}
              >
                ×
              </button>
            </header>
            <div className="preview-modal-body">{body}</div>
            {!hideFooter ? (
              <footer className="preview-modal-footer">
                <a href={fileUrl} target="_blank" rel="noreferrer" className="btn btn-primary">
                  Open in new tab
                </a>
                <button type="button" className="btn btn-secondary" onClick={onClose}>
                  Close
                </button>
              </footer>
            ) : null}
          </motion.div>
        </motion.div>
      ) : null}
    </AnimatePresence>,
    document.body
  );
}

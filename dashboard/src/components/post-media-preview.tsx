"use client";

import { useEffect, useMemo, useState } from "react";
import {
  isDirectImageUrl,
  isNetworkImageUrl,
  sanitizeImageUrl,
} from "@/lib/image-urls";

const clientOgCache = new Map<string, string | null>();

async function fetchOpenGraphImageClient(pageUrl: string): Promise<string | null> {
  if (clientOgCache.has(pageUrl)) {
    return clientOgCache.get(pageUrl) ?? null;
  }
  try {
    const res = await fetch(`/api/link-preview?url=${encodeURIComponent(pageUrl)}`);
    if (!res.ok) {
      clientOgCache.set(pageUrl, null);
      return null;
    }
    const data = (await res.json()) as { imageUrl?: string | null };
    const imageUrl = typeof data.imageUrl === "string" ? data.imageUrl : null;
    clientOgCache.set(pageUrl, imageUrl);
    return imageUrl;
  } catch {
    clientOgCache.set(pageUrl, null);
    return null;
  }
}

type PostMediaPreviewProps = {
  mediaUrl: string | null | undefined;
  
  triggerClassName?: string;
  imageClassName?: string;
  compact?: boolean;
  isVideo?: boolean;
  onOpen?: (displayUrl: string) => void;
};

export function PostMediaPreview({
  mediaUrl,
  triggerClassName,
  imageClassName,
  compact = false,
  isVideo = false,
  onOpen,
}: PostMediaPreviewProps) {
  const source = useMemo(() => sanitizeImageUrl(mediaUrl), [mediaUrl]);
  const [ogUrl, setOgUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [imgBroken, setImgBroken] = useState(false);

  const isDirect = source ? isDirectImageUrl(source) : false;
  const isLink = source ? isNetworkImageUrl(source) && !isDirect : false;

  useEffect(() => {
    setImgBroken(false);
    if (!source || isDirect || !isLink) {
      setOgUrl(null);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setOgUrl(null);
    fetchOpenGraphImageClient(source).then((url) => {
      if (cancelled) return;
      setOgUrl(url);
      setLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [source, isDirect, isLink]);

  const displayUrl = isDirect ? source : ogUrl;

  if (!source) {
    return null;
  }

  const host = (() => {
    try {
      return new URL(source).host;
    } catch {
      return source;
    }
  })();

  const innerContent = (() => {
    if (loading) {
      return (
        <div className={`post-media-preview-loading${compact ? " compact" : ""}`} aria-hidden>
          <span className="post-media-preview-spinner" />
        </div>
      );
    }

    if (displayUrl && !imgBroken) {
      return (
        <img
          src={displayUrl}
          alt=""
          className={imageClassName}
          loading="lazy"
          onError={() => setImgBroken(true)}
        />
      );
    }

    if (isLink) {
      return (
        <div className={`post-media-link-fallback${compact ? " compact" : ""}`}>
          <span className="post-media-link-icon" aria-hidden>
            🔗
          </span>
          {!compact ? (
            <>
              <span className="post-media-link-host">{host}</span>
              <span className="post-media-link-hint">Link preview unavailable</span>
            </>
          ) : null}
        </div>
      );
    }

    return (
      <div className={`post-media-link-fallback${compact ? " compact" : ""}`}>
        <span className="subtle">Preview unavailable</span>
      </div>
    );
  })();

  const canOpen = Boolean(onOpen && displayUrl && !imgBroken);

  const body = (
    <>
      {innerContent}
      {isVideo ? (
        <span className="feed-post-video-badge" aria-hidden>
          Video
        </span>
      ) : null}
    </>
  );

  if (onOpen && canOpen) {
    return (
      <button
        type="button"
        className={triggerClassName ?? "feed-post-media-trigger"}
        onClick={() => onOpen!(displayUrl!)}
        aria-label={isVideo ? "Open video" : "View image full size"}
      >
        {body}
      </button>
    );
  }

  if (triggerClassName) {
    return <div className={triggerClassName}>{body}</div>;
  }

  return <>{body}</>;
}

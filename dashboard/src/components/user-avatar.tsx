"use client";

import { useEffect, useMemo, useState } from "react";
import { isNetworkImageUrl, networkDisplayImageUrl } from "@/lib/image-urls";

type UserAvatarProps = {
  url?: string | null;
  name?: string | null;
  email?: string | null;
  size?: number;
  className?: string;
};

export function initialLetterFrom(name: string | null | undefined, email?: string | null): string {
  const n = (name ?? "").trim();
  if (n.length >= 1) return n[0]!.toUpperCase();
  const e = (email ?? "").trim();
  if (e.length >= 1) return e[0]!.toUpperCase();
  return "U";
}

export function UserAvatar({ url, name, email, size = 40, className = "" }: UserAvatarProps) {
  const [failed, setFailed] = useState(false);
  const label = useMemo(() => initialLetterFrom(name, email), [name, email]);
  const displayUrl = useMemo(
    () => networkDisplayImageUrl(url, Math.max(96, size * 2)),
    [url, size],
  );
  const canShowImage = Boolean(displayUrl && isNetworkImageUrl(displayUrl) && !failed);

  useEffect(() => {
    setFailed(false);
  }, [displayUrl]);

  const style = { width: size, height: size, fontSize: Math.max(10, Math.round(size * 0.5)) };

  if (canShowImage && displayUrl) {
    return (
      <img
        src={displayUrl}
        alt=""
        className={`user-avatar user-avatar--img ${className}`.trim()}
        style={style}
        loading="lazy"
        onError={() => setFailed(true)}
      />
    );
  }

  return (
    <div
      className={`user-avatar user-avatar--placeholder ${className}`.trim()}
      style={style}
      title={name || email || "User"}
      aria-label={name || email || "User"}
    >
      {label}
    </div>
  );
}

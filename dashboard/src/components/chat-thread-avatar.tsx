"use client";

import { UserAvatar } from "@/components/user-avatar";

type ChatThreadAvatarProps = {
  url?: string | null;
  name: string;
  sm?: boolean;
};


export function ChatThreadAvatar({ url, name, sm }: ChatThreadAvatarProps) {
  const size = sm ? 40 : 48;
  return (
    <div className={`chat-thread-avatar${sm ? " chat-thread-avatar--sm" : ""}`} aria-hidden>
      <UserAvatar url={url} name={name} size={size} className="chat-thread-avatar-user" />
    </div>
  );
}

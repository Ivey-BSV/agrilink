"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getOrCreateChat, refreshAuthSessionForChat } from "@/lib/chat";

export default function PlatformChatWithUserPage() {
  const params = useParams();
  const router = useRouter();
  const otherUserId = typeof params.otherUserId === "string" ? params.otherUserId : "";
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!otherUserId) {
      setError("Missing user.");
      return;
    }

    let cancelled = false;

    const run = async () => {
      setError(null);
      await refreshAuthSessionForChat();
      const chatId = await getOrCreateChat(otherUserId);
      if (cancelled) return;
      if (chatId) {
        router.replace(`/platform/chat/${chatId}`);
        return;
      }
      setError("Could not open a conversation. You may need to follow each other, or try again.");
    };

    void run();
    return () => {
      cancelled = true;
    };
  }, [otherUserId, router]);

  return (
    <div className="content-card stack" style={{ gap: 12 }}>
      <p className="subtle">{error ? error : "Starting conversation…"}</p>
      {error ? (
        <Link href="/platform/chat" className="btn btn-secondary">
          Back to messages
        </Link>
      ) : null}
    </div>
  );
}

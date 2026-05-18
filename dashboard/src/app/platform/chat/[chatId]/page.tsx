"use client";

import Link from "next/link";
import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useParams, useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import {
  followUser,
  getAuthUserIdForData,
  loadMessagesForChat,
  markChatAsRead,
  POST_SHARE_TOKEN_PREFIX,
  sendTextMessage,
  type ChatMessageRow,
} from "@/lib/chat";

function extractPostIdFromContent(content: string): string | null {
  const idx = content.indexOf(POST_SHARE_TOKEN_PREFIX);
  if (idx === -1) return null;
  const rest = content.slice(idx + POST_SHARE_TOKEN_PREFIX.length).trim();
  const line = rest.split(/\s/)[0];
  return line || null;
}

function PlatformChatDetailInner() {
  const params = useParams();
  const searchParams = useSearchParams();
  const raw = params.chatId;
  const chatId = typeof raw === "string" ? raw : Array.isArray(raw) ? raw[0] : "";

  const [userId, setUserId] = useState<string | null>(null);
  const [otherUserId, setOtherUserId] = useState<string | null>(null);
  const [otherName, setOtherName] = useState("User");
  const [otherAvatar, setOtherAvatar] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessageRow[]>([]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [followingBack, setFollowingBack] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isRequest, setIsRequest] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);

  const scrollBottom = () => {
    const el = listRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  };

  const refreshMessages = useCallback(async () => {
    if (!chatId) return;
    const rows = await loadMessagesForChat(chatId);
    setMessages(rows);
    requestAnimationFrame(scrollBottom);
  }, [chatId]);

  useEffect(() => {
    let channel: RealtimeChannel | undefined;
    let cancelled = false;

    async function init() {
      setLoading(true);
      setError(null);
      const uid = await getAuthUserIdForData();
      if (!uid || !chatId) {
        setLoading(false);
        return;
      }
      setUserId(uid);

      const { data: chatRow, error: chatErr } = await supabase
        .from("chats")
        .select("user1_id, user2_id")
        .eq("id", chatId)
        .maybeSingle();

      if (chatErr || !chatRow) {
        setError("Conversation not found or you don't have access.");
        setLoading(false);
        return;
      }

      const row = chatRow as { user1_id: string; user2_id: string };
      if (row.user1_id !== uid && row.user2_id !== uid) {
        setError("You're not part of this conversation.");
        setLoading(false);
        return;
      }

      const other = row.user1_id === uid ? row.user2_id : row.user1_id;
      setOtherUserId(other);

      const { data: prof } = await supabase
        .from("user_profiles")
        .select("full_name, username, avatar_url")
        .eq("id", other)
        .maybeSingle();

      if (prof) {
        const p = prof as { full_name: string | null; username: string | null; avatar_url: string | null };
        setOtherName(p.full_name?.trim() || p.username || "User");
        setOtherAvatar(p.avatar_url);
      }

      const rows = await loadMessagesForChat(chatId);
      if (cancelled) return;
      setMessages(rows);

      const [{ data: otherFollows }, { data: iFollow }] = await Promise.all([
        supabase.from("follows").select("id").eq("follower_id", other).eq("following_id", uid).maybeSingle(),
        supabase.from("follows").select("id").eq("follower_id", uid).eq("following_id", other).maybeSingle(),
      ]);

      const hasMessages = rows.length > 0;
      const req = Boolean(hasMessages && otherFollows && !iFollow);
      setIsRequest(req || searchParams.get("request") === "1");

      await markChatAsRead(chatId);
      if (cancelled) return;
      setLoading(false);
      requestAnimationFrame(scrollBottom);

      channel = supabase
        .channel("messages:" + chatId)
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "messages", filter: "chat_id=eq." + chatId },
          (payload) => {
            const row = payload.new as ChatMessageRow;
            setMessages((prev) => {
              if (prev.some((m) => m.id === row.id)) return prev;
              return [...prev, row];
            });
            requestAnimationFrame(scrollBottom);
          },
        )
        .subscribe();
    }

    void init();

    return () => {
      cancelled = true;
      if (channel) supabase.removeChannel(channel);
    };
  }, [chatId, searchParams]);

  useEffect(() => {
    requestAnimationFrame(scrollBottom);
  }, [messages.length]);

  const onSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = draft.trim();
    if (!text || sending || !chatId) return;
    setSending(true);
    setError(null);
    const { error: sendErr } = await sendTextMessage(chatId, text);
    if (sendErr) {
      setError(sendErr);
      setSending(false);
      return;
    }
    setDraft("");
    await refreshMessages();
    setSending(false);
  };

  const onFollowBack = async () => {
    if (!otherUserId || followingBack) return;
    setFollowingBack(true);
    setError(null);
    const { error: fErr } = await followUser(otherUserId);
    if (fErr) {
      setError(fErr);
      setFollowingBack(false);
      return;
    }
    setIsRequest(false);
    setFollowingBack(false);
  };

  const title = useMemo(() => otherName, [otherName]);

  if (!chatId) {
    return (
      <div className="content-card">
        <p className="error">Missing chat id.</p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="content-card">
        <p className="subtle">Opening conversation…</p>
      </div>
    );
  }

  if (error && !otherUserId) {
    return (
      <div className="content-card stack" style={{ gap: 12 }}>
        <p className="error">{error}</p>
        <Link href="/platform/chat" className="btn btn-secondary">
          Back to messages
        </Link>
      </div>
    );
  }

  return (
    <motion.div
      className="content-card stack chat-detail"
      style={{ gap: 0, padding: 0, overflow: "hidden" }}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="chat-detail-top">
        <Link href="/platform/chat" className="chat-detail-back">
          ← Messages
        </Link>
        <div className="chat-detail-peer">
          <div className="chat-thread-avatar chat-thread-avatar--sm" aria-hidden>
            {otherAvatar ? (
              <img src={otherAvatar} alt="" width={40} height={40} />
            ) : (
              <span>{title.trim() ? title[0]!.toUpperCase() : "U"}</span>
            )}
          </div>
          <div>
            <div className="chat-detail-peer-name">{title}</div>
            <div className="subtle" style={{ fontSize: 12 }}>
              Direct message
            </div>
          </div>
        </div>
      </div>

      {isRequest ? (
        <div className="chat-request-banner">
          <p style={{ margin: 0, fontSize: 14 }}>
            <strong>Message request</strong> — this person follows you, but you don&apos;t follow them yet. Follow
            back to move the chat to your main list.
          </p>
          <button type="button" className="btn btn-primary" disabled={followingBack} onClick={() => void onFollowBack()}>
            {followingBack ? "Following…" : "Follow back"}
          </button>
        </div>
      ) : null}

      {error ? <p className="error" style={{ padding: "0 16px" }}>{error}</p> : null}

      <div className="chat-detail-scroll" ref={listRef}>
        <div className="chat-detail-messages">
          {messages.length === 0 ? (
            <p className="subtle" style={{ textAlign: "center", padding: 24 }}>
              No messages yet. Say hello below.
            </p>
          ) : (
            messages.map((m) => {
              const mine = m.sender_id === userId;
              const eventLink = m.event_id ? "/dashboard/events" : null;
              const postFromCol = m.post_id;
              const postFromBody = !postFromCol ? extractPostIdFromContent(m.content) : null;
              const postId = postFromCol || postFromBody;
              const isPostShare =
                Boolean(postId) || m.content.includes(POST_SHARE_TOKEN_PREFIX) || m.content.trim() === "Shared a post";
              const isEventShare = Boolean(m.event_id) || m.content.includes("Shared an event");

              return (
                <div key={m.id} className={"chat-bubble-row" + (mine ? " mine" : "")}>
                  <div className={"chat-bubble" + (mine ? " mine" : "")}>
                    {isEventShare ? (
                      <div className="chat-bubble-special">
                        <span className="subtle">Shared an event</span>
                        {eventLink ? (
                          <Link href={eventLink} className="chat-bubble-link">
                            View events
                          </Link>
                        ) : null}
                      </div>
                    ) : isPostShare ? (
                      <div className="chat-bubble-special">
                        <span className="subtle">Shared a post</span>
                        <Link href="/platform/feed" className="chat-bubble-link">
                          Open feed
                        </Link>
                      </div>
                    ) : (
                      <p className="chat-bubble-text" style={{ margin: 0, whiteSpace: "pre-wrap" }}>
                        {m.content}
                      </p>
                    )}
                    <time className="chat-bubble-time" dateTime={m.created_at}>
                      {new Date(m.created_at).toLocaleString(undefined, {
                        month: "short",
                        day: "numeric",
                        hour: "numeric",
                        minute: "2-digit",
                      })}
                    </time>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      <form className="chat-detail-composer" onSubmit={(e) => void onSend(e)}>
        <input
          className="input"
          placeholder="Write a message…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          disabled={sending}
          aria-label="Message"
        />
        <button type="submit" className="btn btn-primary" disabled={sending || !draft.trim()}>
          {sending ? "Sending…" : "Send"}
        </button>
      </form>
    </motion.div>
  );
}

export default function PlatformChatDetailPage() {
  return (
    <Suspense
      fallback={
        <div className="content-card">
          <p className="subtle">Opening conversation…</p>
        </div>
      }
    >
      <PlatformChatDetailInner />
    </Suspense>
  );
}

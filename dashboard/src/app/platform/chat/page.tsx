"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { ChatThreadAvatar } from "@/components/chat-thread-avatar";
import {
  fetchFollowingWithMeta,
  filterMessageRequests,
  filterRegularChats,
  getAuthUserIdForData,
  isMutualFollowInCache,
  loadChatsForCurrentUser,
  refreshAuthSessionForChat,
  type ChatListEntry,
  type ChatLoadMeta,
} from "@/lib/chat";
import { networkDisplayImageUrl } from "@/lib/image-urls";

type Tab = "messages" | "requests";

type FollowingRow = {
  id: string;
  username: string | null;
  full_name: string | null;
  avatar_url: string | null;
  follow_created_at: string;
};

function formatTimeAgo(iso: string) {
  const t = new Date(iso).getTime();
  const d = Date.now() - t;
  const mins = Math.floor(d / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

type MessageHubRow = { follow: FollowingRow; chat: ChatListEntry | null };

function sortMessageHubRows(rows: MessageHubRow[]): MessageHubRow[] {
  return [...rows].sort((a, b) => {
    const hasA = !!a.chat && (a.chat.messages.length > 0 || (a.chat.lastMessage?.length ?? 0) > 0);
    const hasB = !!b.chat && (b.chat.messages.length > 0 || (b.chat.lastMessage?.length ?? 0) > 0);
    if (hasA && hasB && a.chat && b.chat) {
      return (b.chat.lastMessageTime ?? "").localeCompare(a.chat.lastMessageTime ?? "");
    }
    if (hasA) return -1;
    if (hasB) return 1;
    const fa = a.follow.follow_created_at || "";
    const fb = b.follow.follow_created_at || "";
    return fb.localeCompare(fa);
  });
}

export default function PlatformChatPage() {
  const [tab, setTab] = useState<Tab>("messages");
  const [userId, setUserId] = useState<string | null>(null);
  const [following, setFollowing] = useState<FollowingRow[]>([]);
  const [chats, setChats] = useState<ChatListEntry[]>([]);
  const [followCache, setFollowCache] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [chatsLoadError, setChatsLoadError] = useState<string | null>(null);
  const [loadMeta, setLoadMeta] = useState<ChatLoadMeta | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setChatsLoadError(null);
    setLoadMeta(null);
    await refreshAuthSessionForChat();
    const uid = await getAuthUserIdForData();
    if (!uid) {
      setUserId(null);
      setLoading(false);
      return;
    }
    setUserId(uid);
    try {
      const followList = await fetchFollowingWithMeta(uid);
      const pack = await loadChatsForCurrentUser(
        uid,
        followList.map((f) => f.id),
      );
      setFollowing(followList);
      setChats(pack.chats);
      setFollowCache(pack.followCache);
      setLoadMeta(pack.loadMeta);
      if (pack.chatsError) setChatsLoadError(pack.chatsError);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load messages");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const regularChats = useMemo(() => {
    if (!userId) return [];
    return filterRegularChats(chats, userId, followCache);
  }, [chats, followCache, userId]);

  const messageRequests = useMemo(() => {
    if (!userId) return [];
    return filterMessageRequests(chats, userId, followCache);
  }, [chats, followCache, userId]);

  const messageHubRows = useMemo(() => {
    if (!userId) return [];
    const regularIds = new Set(regularChats.map((c) => c.otherUserId));
    const chatByOther = new Map(chats.map((c) => [c.otherUserId, c] as const));
    const filtered = following.filter(
      (f) => regularIds.has(f.id) || isMutualFollowInCache(followCache, userId, f.id),
    );
    const rows: MessageHubRow[] = filtered.map((follow) => ({
      follow,
      chat: chatByOther.get(follow.id) ?? null,
    }));
    return sortMessageHubRows(rows);
  }, [userId, following, regularChats, followCache, chats]);

  const requestRows = useMemo(() => {
    return messageRequests.map((chat) => {
      const fu = following.find((f) => f.id === chat.otherUserId);
      return {
        chat,
        displayName: fu?.full_name?.trim() || fu?.username || chat.otherName,
        avatar: networkDisplayImageUrl(chat.otherAvatar ?? fu?.avatar_url, 256),
      };
    });
  }, [messageRequests, following]);

  const showDbDiagnostics = useMemo(() => {
    if (!loadMeta) return false;
    if (chatsLoadError) return true;
    if (loadMeta.chatsUser1Error) return true;
    if (loadMeta.chatsUser2Error) return true;
    if (loadMeta.followsReadError) return true;
    if (loadMeta.messagesReadError) return true;
    return false;
  }, [loadMeta, chatsLoadError]);

  if (loading) {
    return (
      <motion.div className="content-card" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <p className="subtle">Loading conversations…</p>
      </motion.div>
    );
  }

  if (!userId) {
    return (
      <motion.div className="content-card stack" style={{ gap: 12 }} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <p className="subtle">Sign in to see your messages.</p>
        <Link href="/signin" className="btn btn-primary">
          Sign in
        </Link>
      </motion.div>
    );
  }

  return (
    <motion.div
      className="content-card stack chat-hub"
      style={{ gap: 0 }}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="chat-hub-header">
        <div>
          <h2 className="section-title" style={{ marginBottom: 6 }}>
            Messages
          </h2>
          <p className="subtle" style={{ margin: 0 }}>
            Chats with people you follow. Requests are from people who follow you but you don&apos;t follow back yet.
          </p>
        </div>
        <button type="button" className="btn btn-secondary" onClick={() => void load()}>
          Refresh
        </button>
      </div>

      {error ? <p className="error" style={{ padding: "0 0 12px" }}>{error}</p> : null}
      {chatsLoadError ? <p className="error" style={{ padding: "0 0 12px" }}>{chatsLoadError}</p> : null}

      {showDbDiagnostics && loadMeta ? (
        <div
          className="chat-load-diagnostics"
          style={{
            margin: "0 0 12px",
            padding: "12px 14px",
            borderRadius: "var(--radius-md)",
            border: "1px solid var(--border-strong)",
            background: "var(--bg-subtle)",
            fontSize: "0.8125rem",
          }}
        >
          <p style={{ margin: "0 0 8px", fontWeight: 600 }}>Supabase / access check</p>
          <ul style={{ margin: "0 0 10px", paddingLeft: "1.1rem", color: "var(--text-secondary)" }}>
            <li>
              Chats query: <strong>{loadMeta.rawChatRows}</strong> row(s); threads built for UI:{" "}
              <strong>{loadMeta.threadsLoaded}</strong>
            </li>
            {loadMeta.chatsUser1Error ? (
              <li className="error" style={{ marginTop: 6 }}>
                <code>chats</code> (as user1): {loadMeta.chatsUser1Error}
              </li>
            ) : null}
            {loadMeta.chatsUser2Error ? (
              <li className="error" style={{ marginTop: 6 }}>
                <code>chats</code> (as user2): {loadMeta.chatsUser2Error}
              </li>
            ) : null}
            {loadMeta.followsReadError ? (
              <li className="error" style={{ marginTop: 6 }}>
                <code>follows</code> read: {loadMeta.followsReadError}
              </li>
            ) : null}
            {loadMeta.messagesReadError ? (
              <li className="error" style={{ marginTop: 6 }}>
                <code>messages</code> read: {loadMeta.messagesReadError}
              </li>
            ) : null}
          </ul>
          <p style={{ margin: 0, color: "var(--text-secondary)" }}>
            If DMs work in the mobile app but this shows zero rows or a permission error, open Supabase → SQL Editor and
            run{" "}
            <code style={{ fontSize: "0.78rem", wordBreak: "break-all" }}>
              supabase/migrations/20260511180000_chat_follows_messages_rls.sql
            </code>{" "}
            and then{" "}
            <code style={{ fontSize: "0.78rem", wordBreak: "break-all" }}>
              supabase/migrations/20260511210000_chat_rls_policies_auth_uid.sql
            </code>
            . Verify the dashboard env points at the same project as the app:{" "}
            <code style={{ fontSize: "0.78rem", wordBreak: "break-all" }}>
              {typeof process !== "undefined" && process.env.NEXT_PUBLIC_SUPABASE_URL
                ? process.env.NEXT_PUBLIC_SUPABASE_URL
                : "(NEXT_PUBLIC_SUPABASE_URL not set)"}
            </code>
          </p>
        </div>
      ) : null}

      <div className="chat-hub-tabs" role="tablist">
        <button type="button" role="tab" className={`chat-hub-tab${tab === "messages" ? " active" : ""}`} onClick={() => setTab("messages")}>
          Messages
        </button>
        <button type="button" role="tab" className={`chat-hub-tab${tab === "requests" ? " active" : ""}`} onClick={() => setTab("requests")}>
          Requests
          {messageRequests.length > 0 ? <span className="chat-hub-tab-badge">{messageRequests.length}</span> : null}
        </button>
      </div>

      {tab === "messages" ? (
        messageHubRows.length === 0 ? (
          <div className="chat-hub-empty">
            <p className="subtle" style={{ margin: 0, fontWeight: 600 }}>
              {messageRequests.length > 0
                ? "No main inbox threads yet"
                : following.length > 0
                  ? "No mutual chats yet"
                  : "No people to chat with"}
            </p>
            <p className="subtle" style={{ margin: "8px 0 0", fontWeight: 400 }}>
              {messageRequests.length > 0
                ? "People you don’t follow back yet appear under Requests. Follow them there to move the chat here."
                : following.length > 0
                  ? "People appear here when you already have a thread with someone you follow, or when someone you follow follows you back. Use Refresh after you both follow each other."
                  : "Follow people from the directory or feed, then open a conversation here."}
            </p>
          </div>
        ) : (
          <ul className="chat-thread-list">
            {messageHubRows.map(({ follow, chat }) => {
              const display = follow.full_name?.trim() || follow.username || chat?.otherName || "User";
              const avatarUrl = networkDisplayImageUrl(follow.avatar_url ?? chat?.otherAvatar, 256);
              const href = chat ? `/platform/chat/${chat.id}` : `/platform/chat/with/${follow.id}`;
              const rowKey = chat?.id ?? `pending-${follow.id}`;

              const hasMessages = !!chat && chat.messages.length > 0;
              const lastFromMe =
                hasMessages && chat ? chat.messages[chat.messages.length - 1]!.sender_id === userId : false;
              const isSeen =
                lastFromMe && hasMessages && chat
                  ? chat.messages[chat.messages.length - 1]!.read_at != null
                  : false;
              const hasUnread = (chat?.unreadCount ?? 0) > 0;
              const subtitle = !chat
                ? "Start a conversation"
                : lastFromMe
                  ? isSeen
                    ? "Seen"
                    : `Sent ${formatTimeAgo(chat.lastMessageTime)}`
                  : hasUnread
                    ? `${chat.unreadCount} new message${chat.unreadCount > 1 ? "s" : ""}`
                    : hasMessages
                      ? chat.lastMessage
                      : "Start a conversation";

              return (
                <li key={rowKey}>
                  <Link href={href} className="chat-thread-row">
                    <ChatThreadAvatar url={avatarUrl} name={display} />
                    <div className="chat-thread-meta">
                      <div className="chat-thread-title-row">
                        <span className="chat-thread-name">{display}</span>
                        {hasUnread ? <span className="chat-thread-dot" aria-label="Unread" /> : null}
                      </div>
                      <div className={`chat-thread-preview${hasUnread ? " unread" : ""}`}>{subtitle}</div>
                    </div>
                    <span className="chat-thread-chevron" aria-hidden>
                      →
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        )
      ) : requestRows.length === 0 ? (
        <div className="chat-hub-empty">
          <p className="subtle" style={{ margin: 0, fontWeight: 600 }}>
            No message requests
          </p>
          <p className="subtle" style={{ margin: "8px 0 0", fontWeight: 400 }}>
            When someone who follows you sends a message and you don&apos;t follow them yet, it appears here. Follow
            them back from the thread to accept.
          </p>
        </div>
      ) : (
        <ul className="chat-thread-list">
          {requestRows.map(({ chat, displayName, avatar }) => {
            const hasUnread = chat.unreadCount > 0;
            return (
              <li key={chat.id}>
                <Link href={`/platform/chat/${chat.id}?request=1`} className="chat-thread-row">
                  <ChatThreadAvatar url={avatar} name={displayName} />
                  <div className="chat-thread-meta">
                    <div className="chat-thread-title-row">
                      <span className="chat-thread-name">{displayName}</span>
                      {hasUnread ? <span className="chat-thread-dot" aria-label="Unread" /> : null}
                    </div>
                    <div className={`chat-thread-preview${hasUnread ? " unread" : ""}`}>
                      {hasUnread
                        ? `${chat.unreadCount} new message${chat.unreadCount > 1 ? "s" : ""}`
                        : chat.lastMessage}
                    </div>
                  </div>
                  <span className="chat-thread-chevron" aria-hidden>
                    →
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </motion.div>
  );
}

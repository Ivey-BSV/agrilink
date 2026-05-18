import { supabase } from "@/lib/supabase";

export const POST_SHARE_TOKEN_PREFIX = "POST_SHARE_ID:";

export async function getAuthUserIdForData(): Promise<string | null> {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (session?.user?.id) return session.user.id;

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (user?.id) return user.id;
  if (error?.message) console.warn("[chat] getAuthUserIdForData getUser:", error.message);
  return null;
}

export async function refreshAuthSessionForChat(): Promise<void> {
  try {
    await supabase.auth.refreshSession();
  } catch {}
}

export type ChatMessageRow = {
  id: string;
  sender_id: string;
  content: string;
  created_at: string;
  read_at: string | null;
  event_id: string | null;
  post_id: string | null;
};

export type ChatListEntry = {
  id: string;
  otherUserId: string;
  otherName: string;
  otherAvatar: string | null;
  lastMessage: string;
  lastMessageTime: string;
  unreadCount: number;
  messages: ChatMessageRow[];
};

export type FollowCache = Record<string, boolean>;

export function isMutualFollowInCache(cache: FollowCache, currentUserId: string, otherUserId: string): boolean {
  return cache[`${currentUserId}_${otherUserId}`] === true;
}

async function getExcludedUserIds(userId: string): Promise<Set<string>> {
  const { data, error } = await supabase
    .from("user_blocks")
    .select("blocker_id, blocked_id")
    .or(`blocker_id.eq.${userId},blocked_id.eq.${userId}`);
  if (error || !data) return new Set();
  const excluded = new Set<string>();
  for (const row of data as { blocker_id: string; blocked_id: string }[]) {
    if (row.blocker_id === userId) excluded.add(row.blocked_id);
    else if (row.blocked_id === userId) excluded.add(row.blocker_id);
  }
  return excluded;
}

const FOLLOW_IN_CHUNK = 80;

async function loadMutualFollowCacheOnce(
  currentUserId: string,
  otherUserIds: string[],
  chunkSize: number,
): Promise<{ cache: FollowCache; hadErrors: boolean }> {
  const cache: FollowCache = {};
  if (otherUserIds.length === 0) return { cache, hadErrors: false };

  const currentFollowsSet = new Set<string>();
  const otherFollowSet = new Set<string>();
  let hadErrors = false;

  for (let i = 0; i < otherUserIds.length; i += chunkSize) {
    const chunk = otherUserIds.slice(i, i + chunkSize);

    const { data: curFollows, error: curErr } = await supabase
      .from("follows")
      .select("following_id")
      .eq("follower_id", currentUserId)
      .in("following_id", chunk);

    const { data: otherFollow, error: othErr } = await supabase
      .from("follows")
      .select("follower_id")
      .eq("following_id", currentUserId)
      .in("follower_id", chunk);

    if (curErr) {
      hadErrors = true;
      console.warn("[chat] follows (current→other) chunk error:", curErr.message);
    }
    if (othErr) {
      hadErrors = true;
      console.warn("[chat] follows (other→current) chunk error:", othErr.message);
    }

    if (!curErr && curFollows) {
      for (const r of curFollows as { following_id: string }[]) {
        currentFollowsSet.add(r.following_id);
      }
    }
    if (!othErr && otherFollow) {
      for (const r of otherFollow as { follower_id: string }[]) {
        otherFollowSet.add(r.follower_id);
      }
    }
  }

  for (const otherUserId of otherUserIds) {
    const cacheKey = `${currentUserId}_${otherUserId}`;
    cache[cacheKey] = currentFollowsSet.has(otherUserId) && otherFollowSet.has(otherUserId);
    cache[`follows_${currentUserId}_${otherUserId}`] = currentFollowsSet.has(otherUserId);
    cache[`follows_${otherUserId}_${currentUserId}`] = otherFollowSet.has(otherUserId);
  }
  return { cache, hadErrors };
}

async function loadMutualFollowCache(currentUserId: string, otherUserIds: string[]): Promise<FollowCache> {
  const unique = [...new Set(otherUserIds)];
  let { cache, hadErrors } = await loadMutualFollowCacheOnce(currentUserId, unique, FOLLOW_IN_CHUNK);

  if (hadErrors) {
    const retry = await loadMutualFollowCacheOnce(currentUserId, unique, unique.length);
    cache = retry.cache;
  }

  return cache;
}

function currentFollowsOther(cache: FollowCache, currentUserId: string, otherUserId: string): boolean {
  return cache[`follows_${currentUserId}_${otherUserId}`] === true;
}

function otherFollowsCurrent(cache: FollowCache, currentUserId: string, otherUserId: string): boolean {
  return cache[`follows_${otherUserId}_${currentUserId}`] === true;
}

export function filterRegularChats(chats: ChatListEntry[], userId: string, cache: FollowCache): ChatListEntry[] {
  return chats.filter((c) => currentFollowsOther(cache, userId, c.otherUserId));
}

export function filterMessageRequests(chats: ChatListEntry[], userId: string, cache: FollowCache): ChatListEntry[] {
  return chats.filter((c) => {
    const hasMessages = c.messages.length > 0 || c.lastMessage.length > 0;
    const isRequest =
      hasMessages && otherFollowsCurrent(cache, userId, c.otherUserId) && !currentFollowsOther(cache, userId, c.otherUserId);
    return isRequest;
  });
}

export async function loadMessagesForChat(chatId: string): Promise<ChatMessageRow[]> {
  const { data, error } = await supabase
    .from("messages")
    .select("id, sender_id, content, created_at, read_at, event_id, post_id")
    .eq("chat_id", chatId)
    .order("created_at", { ascending: true });
  if (error) return [];
  return (data as ChatMessageRow[]) ?? [];
}

export type ChatLoadMeta = {
  rawChatRows: number;
  threadsLoaded: number;
  chatsUser1Error: string | null;
  chatsUser2Error: string | null;
  followsReadError: string | null;
  messagesReadError: string | null;
};

export async function loadChatsForCurrentUser(
  currentUserId: string,
  followCacheUserIds: string[] = [],
): Promise<{
  chats: ChatListEntry[];
  followCache: FollowCache;
  chatsError: string | null;
  loadMeta: ChatLoadMeta;
}> {
  const emptyMeta = (overrides: Partial<ChatLoadMeta> = {}): ChatLoadMeta => ({
    rawChatRows: 0,
    threadsLoaded: 0,
    chatsUser1Error: null,
    chatsUser2Error: null,
    followsReadError: null,
    messagesReadError: null,
    ...overrides,
  });

  if (!currentUserId) return { chats: [], followCache: {}, chatsError: null, loadMeta: emptyMeta() };

  const excluded = await getExcludedUserIds(currentUserId);

  const [resUser1, resUser2] = await Promise.all([
    supabase
      .from("chats")
      .select("*")
      .eq("user1_id", currentUserId)
      .order("updated_at", { ascending: false }),
    supabase
      .from("chats")
      .select("*")
      .eq("user2_id", currentUserId)
      .order("updated_at", { ascending: false }),
  ]);

  const chatsUser1Err = resUser1.error?.message ?? null;
  const chatsUser2Err = resUser2.error?.message ?? null;

  type ChatRow = { id: string; user1_id: string; user2_id: string; updated_at: string };
  const merged = new Map<string, ChatRow>();
  for (const row of (resUser1.data ?? []) as ChatRow[]) {
    merged.set(row.id, row);
  }
  for (const row of (resUser2.data ?? []) as ChatRow[]) {
    merged.set(row.id, row);
  }
  const chatsResponse = [...merged.values()].sort((a, b) =>
    String(b.updated_at).localeCompare(String(a.updated_at)),
  );

  if (chatsResponse.length === 0 && (chatsUser1Err || chatsUser2Err)) {
    return {
      chats: [],
      followCache: {},
      chatsError: [chatsUser1Err, chatsUser2Err].filter(Boolean).join(" · ") || "Could not load chats",
      loadMeta: emptyMeta({ chatsUser1Error: chatsUser1Err, chatsUser2Error: chatsUser2Err }),
    };
  }

  const { error: followsProbeErr } = await supabase
    .from("follows")
    .select("following_id")
    .eq("follower_id", currentUserId)
    .limit(1);

  const { error: messagesProbeErr } = await supabase.from("messages").select("id").limit(1);

  const userIds = new Set<string>();
  for (const row of chatsResponse as { user1_id: string; user2_id: string }[]) {
    userIds.add(row.user1_id);
    userIds.add(row.user2_id);
  }

  const profileById: Record<string, { full_name: string | null; username: string | null; avatar_url: string | null }> =
    {};
  if (userIds.size > 0) {
    const idList = [...userIds];
    for (let i = 0; i < idList.length; i += FOLLOW_IN_CHUNK) {
      const chunk = idList.slice(i, i + FOLLOW_IN_CHUNK);
      const { data: profs, error: pe } = await supabase
        .from("user_profiles")
        .select("id, full_name, username, avatar_url")
        .in("id", chunk);
      if (pe) console.warn("[chat] user_profiles chunk error:", pe.message);
      for (const p of (profs ?? []) as {
        id: string;
        full_name: string | null;
        username: string | null;
        avatar_url: string | null;
      }[]) {
        profileById[p.id] = { full_name: p.full_name, username: p.username, avatar_url: p.avatar_url };
      }
    }
  }

  const fromChatPartners = [...userIds].filter((id) => id !== currentUserId);
  const cacheUserIds = [
    ...new Set([
      ...fromChatPartners,
      ...followCacheUserIds.filter((id) => id && id !== currentUserId),
    ]),
  ];
  const followCache = await loadMutualFollowCache(currentUserId, cacheUserIds);

  const entries: ChatListEntry[] = [];

  for (const row of chatsResponse as {
    id: string;
    user1_id: string;
    user2_id: string;
    updated_at: string;
  }[]) {
    const otherUserId = row.user1_id === currentUserId ? row.user2_id : row.user1_id;
    if (excluded.has(otherUserId)) continue;

    const prof = profileById[otherUserId];
    const otherName = prof?.full_name?.trim() || prof?.username || "User";

    const { data: lastMessageData } = await supabase
      .from("messages")
      .select("content, created_at, sender_id, read_at, event_id")
      .eq("chat_id", row.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    let lastMessage = "";
    let lastMessageTime = row.updated_at as string;
    if (lastMessageData) {
      const lm = lastMessageData as {
        content: string | null;
        created_at: string;
        event_id: string | null;
      };
      if (lm.event_id) lastMessage = "Shared an event";
      else {
        const content = lm.content ?? "";
        lastMessage = content.includes(POST_SHARE_TOKEN_PREFIX) ? "Shared a post" : content;
      }
      lastMessageTime = lm.created_at;
    }

    const { data: unreadRows } = await supabase
      .from("messages")
      .select("id")
      .eq("chat_id", row.id)
      .eq("sender_id", otherUserId)
      .is("read_at", null);

    const unreadCount = (unreadRows as unknown[] | null)?.length ?? 0;
    const messages = await loadMessagesForChat(row.id);

    entries.push({
      id: row.id,
      otherUserId,
      otherName,
      otherAvatar: prof?.avatar_url ?? null,
      lastMessage,
      lastMessageTime,
      unreadCount,
      messages,
    });
  }

  const loadMeta: ChatLoadMeta = {
    rawChatRows: chatsResponse.length,
    threadsLoaded: entries.length,
    chatsUser1Error: chatsUser1Err,
    chatsUser2Error: chatsUser2Err,
    followsReadError: followsProbeErr?.message ?? null,
    messagesReadError: messagesProbeErr?.message ?? null,
  };

  return { chats: entries, followCache, chatsError: null, loadMeta };
}

export async function fetchFollowingWithMeta(currentUserId: string) {
  type Row = {
    id: string;
    username: string | null;
    full_name: string | null;
    avatar_url: string | null;
    follow_created_at: string;
  };

  const { data: followRows, error } = await supabase
    .from("follows")
    .select("following_id, created_at")
    .eq("follower_id", currentUserId)
    .order("created_at", { ascending: false })
    .limit(500);

  if (error || !followRows?.length) return [] as Row[];

  const followList = followRows as { following_id: string; created_at: string }[];
  const followMap = new Map(followList.map((r) => [r.following_id, r.created_at]));
  const ids = followList.map((r) => r.following_id);

  const profById = new Map<string, { username: string | null; full_name: string | null; avatar_url: string | null }>();
  for (let i = 0; i < ids.length; i += FOLLOW_IN_CHUNK) {
    const chunk = ids.slice(i, i + FOLLOW_IN_CHUNK);
    const { data: profs } = await supabase
      .from("user_profiles")
      .select("id, username, full_name, avatar_url")
      .in("id", chunk);
    for (const p of (profs ?? []) as {
      id: string;
      username: string | null;
      full_name: string | null;
      avatar_url: string | null;
    }[]) {
      profById.set(p.id, { username: p.username, full_name: p.full_name, avatar_url: p.avatar_url });
    }
  }

  const list: Row[] = ids.map((id) => {
    const p = profById.get(id);
    return {
      id,
      username: p?.username ?? null,
      full_name: p?.full_name ?? null,
      avatar_url: p?.avatar_url ?? null,
      follow_created_at: followMap.get(id) ?? "",
    };
  });

  list.sort((a, b) => (b.follow_created_at || "").localeCompare(a.follow_created_at || ""));
  return list;
}

export async function getOrCreateChat(otherUserId: string): Promise<string | null> {
  const userId = await getAuthUserIdForData();
  if (!userId) return null;

  const excluded = await getExcludedUserIds(userId);
  if (excluded.has(otherUserId)) return null;

  const [as1, as2] = await Promise.all([
    supabase.from("chats").select("id, user1_id, user2_id").eq("user1_id", userId),
    supabase.from("chats").select("id, user1_id, user2_id").eq("user2_id", userId),
  ]);
  const merged = new Map<string, { id: string; user1_id: string; user2_id: string }>();
  for (const row of (as1.data ?? []) as { id: string; user1_id: string; user2_id: string }[]) {
    merged.set(row.id, row);
  }
  for (const row of (as2.data ?? []) as { id: string; user1_id: string; user2_id: string }[]) {
    merged.set(row.id, row);
  }
  const existing = [...merged.values()];

  for (const row of existing) {
    const { user1_id: u1, user2_id: u2 } = row;
    if ((u1 === userId && u2 === otherUserId) || (u1 === otherUserId && u2 === userId)) {
      return row.id;
    }
  }

  const { data: created, error } = await supabase
    .from("chats")
    .insert({ user1_id: userId, user2_id: otherUserId })
    .select("id")
    .single();

  if (error || !created) return null;
  return (created as { id: string }).id;
}

export async function sendTextMessage(chatId: string, content: string): Promise<{ error: string | null }> {
  const userId = await getAuthUserIdForData();
  if (!userId) return { error: "Not signed in" };

  const { data: chatRow } = await supabase.from("chats").select("user1_id, user2_id").eq("id", chatId).maybeSingle();
  if (chatRow) {
    const u1 = (chatRow as { user1_id: string }).user1_id;
    const u2 = (chatRow as { user2_id: string }).user2_id;
    const other = u1 === userId ? u2 : u1;
    const excluded = await getExcludedUserIds(userId);
    if (excluded.has(other)) return { error: "Cannot message this user" };
  }

  const { error } = await supabase.from("messages").insert({
    chat_id: chatId,
    sender_id: userId,
    content: content.trim(),
  });

  await supabase.from("chats").update({ updated_at: new Date().toISOString() }).eq("id", chatId);

  return { error: error?.message ?? null };
}

export async function markChatAsRead(chatId: string): Promise<void> {
  const userId = await getAuthUserIdForData();
  if (!userId) return;

  const { data: chatRow } = await supabase.from("chats").select("user1_id, user2_id").eq("id", chatId).maybeSingle();
  if (!chatRow) return;
  const u1 = (chatRow as { user1_id: string }).user1_id;
  const u2 = (chatRow as { user2_id: string }).user2_id;
  const otherUserId = u1 === userId ? u2 : u1;

  await supabase
    .from("messages")
    .update({ read_at: new Date().toISOString() })
    .eq("chat_id", chatId)
    .eq("sender_id", otherUserId)
    .is("read_at", null);
}

export async function followUser(targetUserId: string): Promise<{ error: string | null }> {
  const userId = await getAuthUserIdForData();
  if (!userId) return { error: "Not signed in" };

  const { error } = await supabase.from("follows").insert({
    follower_id: userId,
    following_id: targetUserId,
  });
  return { error: error?.message ?? null };
}

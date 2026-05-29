import { supabase } from "@/lib/supabase";

export type PublicProfile = {
  id: string;
  username: string | null;
  full_name: string | null;
  bio: string | null;
  location: string | null;
  farm_type: string | null;
  experience_level: string | null;
  avatar_url: string | null;
  followerCount: number;
  followingCount: number;
  postCount: number;
  isFollowing: boolean;
};

export async function loadPublicProfile(
  userId: string,
  viewerId: string | null
): Promise<{ profile: PublicProfile | null; error: string | null }> {
  const { data, error } = await supabase
    .from("user_profiles")
    .select("id, username, full_name, bio, location, farm_type, experience_level, avatar_url")
    .eq("id", userId)
    .maybeSingle();

  if (error) return { profile: null, error: error.message };
  if (!data) return { profile: null, error: null };

  const [followersRes, followingRes, postsRes, followRes] = await Promise.all([
    supabase.from("follows").select("id", { count: "exact", head: true }).eq("following_id", userId),
    supabase.from("follows").select("id", { count: "exact", head: true }).eq("follower_id", userId),
    supabase.from("posts").select("id", { count: "exact", head: true }).eq("user_id", userId),
    viewerId
      ? supabase
          .from("follows")
          .select("id")
          .eq("follower_id", viewerId)
          .eq("following_id", userId)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);

  const profile: PublicProfile = {
    ...(data as Omit<PublicProfile, "followerCount" | "followingCount" | "postCount" | "isFollowing">),
    followerCount: followersRes.count ?? 0,
    followingCount: followingRes.count ?? 0,
    postCount: postsRes.count ?? 0,
    isFollowing: Boolean(followRes.data),
  };

  return { profile, error: null };
}

export async function getBlockStatus(targetUserId: string): Promise<{
  iBlocked: boolean;
  blockedMe: boolean;
}> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { iBlocked: false, blockedMe: false };

  const [iBlockedRes, blockedMeRes] = await Promise.all([
    supabase
      .from("user_blocks")
      .select("id")
      .eq("blocker_id", user.id)
      .eq("blocked_id", targetUserId)
      .maybeSingle(),
    supabase
      .from("user_blocks")
      .select("id")
      .eq("blocker_id", targetUserId)
      .eq("blocked_id", user.id)
      .maybeSingle(),
  ]);

  return {
    iBlocked: Boolean(iBlockedRes.data),
    blockedMe: Boolean(blockedMeRes.data),
  };
}

export async function followUser(targetUserId: string): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return "Sign in to follow members.";
  const { error } = await supabase.from("follows").insert({
    follower_id: user.id,
    following_id: targetUserId,
  });
  return error?.message ?? null;
}

export async function unfollowUser(targetUserId: string): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return "Sign in to manage follows.";
  const { error } = await supabase
    .from("follows")
    .delete()
    .eq("follower_id", user.id)
    .eq("following_id", targetUserId);
  return error?.message ?? null;
}

export async function blockUser(targetUserId: string): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return "Sign in to block members.";
  if (user.id === targetUserId) return "You cannot block yourself.";

  const { error: blockErr } = await supabase.from("user_blocks").upsert(
    { blocker_id: user.id, blocked_id: targetUserId },
    { onConflict: "blocker_id,blocked_id" }
  );
  if (blockErr) return blockErr.message;

  await supabase.from("follows").delete().eq("follower_id", user.id).eq("following_id", targetUserId);
  await supabase.from("follows").delete().eq("follower_id", targetUserId).eq("following_id", user.id);
  return null;
}

export async function unblockUser(targetUserId: string): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return "Sign in to unblock members.";
  const { error } = await supabase
    .from("user_blocks")
    .delete()
    .eq("blocker_id", user.id)
    .eq("blocked_id", targetUserId);
  return error?.message ?? null;
}

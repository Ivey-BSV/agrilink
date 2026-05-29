"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { loadFarmDetailsFull, type FarmDetailsRow } from "@/lib/farm-details";
import {
  blockUser,
  followUser,
  getBlockStatus,
  loadPublicProfile,
  type PublicProfile,
  unblockUser,
  unfollowUser,
} from "@/lib/profile-social";
import { UserAvatar } from "@/components/user-avatar";
import { ProfilePostGrid } from "@/components/profile-post-grid";
import { PlatformEventList } from "@/components/platform-event-card";
import { FarmDetailsModal } from "@/components/farm-details-modal";

type ProfileTab = "posts" | "events";

type PostRow = {
  id: string;
  title: string | null;
  image_urls: unknown;
};

type EventRow = {
  id: string;
  title: string;
  category: string;
  event_date: string;
  time: string;
  location: string;
  description: string | null;
  image_url: string | null;
};

type PlatformUserProfileViewProps = {
  userId: string;
};

export function PlatformUserProfileView({ userId }: PlatformUserProfileViewProps) {
  const router = useRouter();
  const [viewerId, setViewerId] = useState<string | null>(null);
  const [profile, setProfile] = useState<PublicProfile | null>(null);
  const [tab, setTab] = useState<ProfileTab>("posts");
  const [posts, setPosts] = useState<PostRow[]>([]);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [farmDetails, setFarmDetails] = useState<FarmDetailsRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingTab, setLoadingTab] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [actionBusy, setActionBusy] = useState(false);
  const [blockedMe, setBlockedMe] = useState(false);
  const [iBlocked, setIBlocked] = useState(false);
  const [farmModalOpen, setFarmModalOpen] = useState(false);

  const isOwnProfile = viewerId === userId;

  const reloadProfile = useCallback(async (vid: string | null) => {
    const { profile: p, error: pe } = await loadPublicProfile(userId, vid);
    if (pe) setError(pe);
    else setProfile(p);
    const block = await getBlockStatus(userId);
    setIBlocked(block.iBlocked);
    setBlockedMe(block.blockedMe);
  }, [userId]);

  useEffect(() => {
    let cancelled = false;

    const init = async () => {
      setLoading(true);
      setError(null);
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (cancelled) return;
      const vid = user?.id ?? null;
      setViewerId(vid);

      if (vid === userId) {
        router.replace("/platform/profile");
        return;
      }

      await reloadProfile(vid);
      const { row: farm } = await loadFarmDetailsFull(userId);
      if (!cancelled) setFarmDetails(farm);
      if (!cancelled) setLoading(false);
    };

    void init();
    return () => {
      cancelled = true;
    };
  }, [userId, router, reloadProfile]);

  useEffect(() => {
    if (loading || blockedMe) return;
    if (tab !== "posts") return;
    let cancelled = false;
    const loadPosts = async () => {
      setLoadingTab(true);
      const { data, error: e } = await supabase
        .from("posts")
        .select("id, title, image_urls")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (!cancelled) {
        if (e) setError(e.message);
        else setPosts((data as PostRow[]) ?? []);
        setLoadingTab(false);
      }
    };
    void loadPosts();
    return () => {
      cancelled = true;
    };
  }, [userId, tab, loading, blockedMe]);

  useEffect(() => {
    if (loading || blockedMe) return;
    if (tab !== "events") return;
    let cancelled = false;
    const loadEvents = async () => {
      setLoadingTab(true);
      const { data, error: e } = await supabase
        .from("events")
        .select("id, title, category, event_date, time, location, description, image_url")
        .eq("user_id", userId)
        .order("event_date", { ascending: false });
      if (!cancelled) {
        if (e) setError(e.message);
        else setEvents((data as EventRow[]) ?? []);
        setLoadingTab(false);
      }
    };
    void loadEvents();
    return () => {
      cancelled = true;
    };
  }, [userId, tab, loading, blockedMe]);

  const toggleFollow = async () => {
    if (!profile) return;
    setActionBusy(true);
    setError(null);
    const err = profile.isFollowing ? await unfollowUser(userId) : await followUser(userId);
    if (err) setError(err);
    else {
      setProfile((prev) =>
        prev
          ? {
              ...prev,
              isFollowing: !prev.isFollowing,
              followerCount: prev.isFollowing
                ? Math.max(0, prev.followerCount - 1)
                : prev.followerCount + 1,
            }
          : prev
      );
    }
    setActionBusy(false);
  };

  const toggleBlock = async () => {
    const msg = iBlocked
      ? "Unblock this member? You will see each other's content again."
      : "Block this member? They will not be notified. You will not see each other's posts and listings on main pages.";
    if (!confirm(msg)) return;
    setActionBusy(true);
    setError(null);
    const err = iBlocked ? await unblockUser(userId) : await blockUser(userId);
    if (err) setError(err);
    else {
      setIBlocked(!iBlocked);
      if (!iBlocked) setProfile((p) => (p ? { ...p, isFollowing: false } : p));
    }
    setActionBusy(false);
  };

  if (loading) {
    return (
      <motion.div className="content-card stack" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <p className="subtle">Loading profile…</p>
      </motion.div>
    );
  }

  if (!profile) {
    return (
      <motion.div className="content-card stack" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <Link href="/platform/directory" className="subtle" style={{ textDecoration: "none" }}>
          ← Directory
        </Link>
        <p className="empty">User not found.</p>
        {error ? <p className="error">{error}</p> : null}
      </motion.div>
    );
  }

  const displayName = profile.full_name?.trim() || profile.username || "Farmer";
  const tags = [
    profile.location?.trim() ? { icon: "📍", text: profile.location.trim() } : null,
    profile.farm_type?.trim() ? { icon: "🌾", text: profile.farm_type.trim() } : null,
    profile.experience_level?.trim() ? { icon: "★", text: profile.experience_level.trim() } : null,
  ].filter(Boolean) as { icon: string; text: string }[];

  return (
    <motion.div className="content-card stack platform-user-profile" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div className="platform-profile-toolbar">
        <button type="button" className="btn btn-secondary" onClick={() => router.back()}>
          Back
        </button>
        {!isOwnProfile ? (
          <button
            type="button"
            className={`btn${iBlocked ? " btn-primary" : " btn-danger"}`}
            disabled={actionBusy}
            onClick={() => void toggleBlock()}
          >
            {iBlocked ? "Unblock" : "Block"}
          </button>
        ) : null}
      </div>

      {error ? <p className="error">{error}</p> : null}

      <div className="platform-profile-hero">
        <UserAvatar url={profile.avatar_url} name={displayName} size={88} />
        <div className="platform-profile-hero-main">
          <div className="section-title" style={{ fontSize: "1.35rem" }}>
            {displayName}
          </div>
          {profile.username ? <div className="subtle">@{profile.username}</div> : null}
          {tags.length > 0 ? (
            <div className="platform-profile-tags">
              {tags.map((t) => (
                <span key={t.text} className="pill platform-profile-tag-pill">
                  <span aria-hidden>{t.icon}</span> {t.text}
                </span>
              ))}
            </div>
          ) : null}
          <div className="platform-profile-stats">
            <Link href={`/platform/user/${userId}/followers`} className="platform-profile-stat">
              <strong>{profile.followerCount}</strong> followers
            </Link>
            <Link href={`/platform/user/${userId}/following`} className="platform-profile-stat">
              <strong>{profile.followingCount}</strong> following
            </Link>
            <span className="platform-profile-stat">
              <strong>{profile.postCount}</strong> posts
            </span>
          </div>
          <p className="platform-profile-bio">{profile.bio?.trim() || "No bio available."}</p>
          <div className="platform-profile-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setFarmModalOpen(true)}>
              Farm details
            </button>
            {!isOwnProfile ? (
              <button
                type="button"
                className={`btn${profile.isFollowing ? " btn-secondary" : " btn-primary"}`}
                disabled={actionBusy}
                onClick={() => void toggleFollow()}
              >
                {profile.isFollowing ? "Following" : "Follow"}
              </button>
            ) : null}
            <Link href={`/platform/chat/with/${userId}`} className="btn btn-secondary">
              Message
            </Link>
          </div>
        </div>
      </div>

      {blockedMe ? (
        <div className="platform-profile-unavailable">
          <p className="section-title" style={{ fontSize: "1.1rem" }}>
            Profile unavailable
          </p>
          <p className="subtle">This member has restricted access to their content.</p>
        </div>
      ) : (
        <>
          <div className="platform-profile-tabs" role="tablist" aria-label="Profile sections">
            <button
              type="button"
              role="tab"
              aria-selected={tab === "posts"}
              className={`platform-profile-tab${tab === "posts" ? " active" : ""}`}
              onClick={() => setTab("posts")}
            >
              Posts
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "events"}
              className={`platform-profile-tab${tab === "events" ? " active" : ""}`}
              onClick={() => setTab("events")}
            >
              Events
            </button>
          </div>

          {tab === "posts" ? (
            <div className="platform-profile-panel">
              {loadingTab ? <p className="subtle">Loading posts…</p> : null}
              {!loadingTab && posts.length === 0 ? (
                <p className="empty">This member has not posted anything yet.</p>
              ) : null}
              <ProfilePostGrid posts={posts} />
            </div>
          ) : null}

          {tab === "events" ? (
            <div className="platform-profile-panel">
              <PlatformEventList
                events={events}
                loading={loadingTab}
                emptyMessage="This member has not created any events yet."
              />
            </div>
          ) : null}
        </>
      )}

      <FarmDetailsModal
        open={farmModalOpen}
        onClose={() => setFarmModalOpen(false)}
        farm={farmDetails}
        isOwnProfile={isOwnProfile}
      />
    </motion.div>
  );
}

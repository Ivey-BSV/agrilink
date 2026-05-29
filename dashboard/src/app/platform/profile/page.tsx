"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { UserAvatar } from "@/components/user-avatar";
import { ProfilePostGrid } from "@/components/profile-post-grid";
import { PlatformEventList } from "@/components/platform-event-card";
import { FarmDetailsModal } from "@/components/farm-details-modal";
import { loadFarmDetailsFull, type FarmDetailsRow } from "@/lib/farm-details";
import { loadFarmDetailsSummary, upsertFarmDetailsSummary } from "@/lib/farm-details";

type Profile = {
  id: string;
  username: string | null;
  full_name: string | null;
  bio: string | null;
  location: string | null;
  farm_type: string | null;
  experience_level: string | null;
  avatar_url: string | null;
};

type ProfileTab = "about" | "posts" | "events";

type PostRow = {
  id: string;
  title: string | null;
  content: string | null;
  created_at: string;
  location: string | null;
  image_urls: unknown;
  post_type: string | null;
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
  created_at: string;
};

export default function PlatformProfilePage() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [email, setEmail] = useState<string | null>(null);
  const [tab, setTab] = useState<ProfileTab>("about");
  const [posts, setPosts] = useState<PostRow[]>([]);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingPosts, setLoadingPosts] = useState(false);
  const [loadingEvents, setLoadingEvents] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [farmName, setFarmName] = useState("");
  const [farmOverview, setFarmOverview] = useState("");
  const [followStats, setFollowStats] = useState<{ followers: number; following: number; posts: number } | null>(null);
  const [farmDetails, setFarmDetails] = useState<FarmDetailsRow | null>(null);
  const [farmModalOpen, setFarmModalOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) {
          setError("Not signed in.");
          setLoading(false);
        }
        return;
      }
      if (!cancelled) setEmail(user.email ?? null);

      const { data, error: e } = await supabase
        .from("user_profiles")
        .select("id, username, full_name, bio, location, farm_type, experience_level, avatar_url")
        .eq("id", user.id)
        .single();

      if (cancelled) return;
      if (e) setError(e.message);
      else setProfile(data as Profile);

      if (data && !e) {
        const { row: farm, error: fe } = await loadFarmDetailsSummary(user.id);
        if (!cancelled && !fe && farm) {
          setFarmName(farm.farm_name ?? "");
          setFarmOverview(farm.farm_overview ?? "");
        }

        const [fcRes, fgRes, postsRes, farmFull] = await Promise.all([
          supabase.from("follows").select("id", { count: "exact", head: true }).eq("following_id", user.id),
          supabase.from("follows").select("id", { count: "exact", head: true }).eq("follower_id", user.id),
          supabase.from("posts").select("id", { count: "exact", head: true }).eq("user_id", user.id),
          loadFarmDetailsFull(user.id),
        ]);
        if (!cancelled && !fcRes.error && !fgRes.error) {
          setFollowStats({
            followers: fcRes.count ?? 0,
            following: fgRes.count ?? 0,
            posts: postsRes.count ?? 0,
          });
        }
        if (!cancelled && !farmFull.error) setFarmDetails(farmFull.row);
      }

      setLoading(false);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!profile) return;
    if (tab !== "posts") return;
    let cancelled = false;
    const loadPosts = async () => {
      setLoadingPosts(true);
      const { data, error: pe } = await supabase
        .from("posts")
        .select("id, title, content, image_urls, created_at, location, post_type")
        .eq("user_id", profile.id)
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (pe) setError(pe.message);
      else setPosts((data as PostRow[]) ?? []);
      setLoadingPosts(false);
    };
    void loadPosts();
    return () => {
      cancelled = true;
    };
  }, [profile, tab]);

  useEffect(() => {
    if (!profile) return;
    if (tab !== "events") return;
    let cancelled = false;
    const loadEvents = async () => {
      setLoadingEvents(true);
      const { data, error: ee } = await supabase
        .from("events")
        .select("id, title, category, event_date, time, location, description, image_url, created_at")
        .eq("user_id", profile.id)
        .order("event_date", { ascending: false });
      if (cancelled) return;
      if (ee) setError(ee.message);
      else setEvents((data as EventRow[]) ?? []);
      setLoadingEvents(false);
    };
    void loadEvents();
    return () => {
      cancelled = true;
    };
  }, [profile, tab]);

  const update = (key: keyof Profile, value: string) => {
    setProfile((prev) => (prev ? { ...prev, [key]: value } : prev));
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();
    if (!profile) return;
    setSaving(true);
    setError(null);
    setSuccess(null);

    const { error: e2 } = await supabase
      .from("user_profiles")
      .update({
        full_name: profile.full_name,
        bio: profile.bio,
        location: profile.location,
        farm_type: profile.farm_type,
        experience_level: profile.experience_level,
        avatar_url: profile.avatar_url,
        updated_at: new Date().toISOString(),
      })
      .eq("id", profile.id);

    if (e2) {
      setError(e2.message);
      setSaving(false);
      return;
    }

    const farmNameTrim = farmName.trim();
    const overviewTrim = farmOverview.trim();
    const { error: fe } = await upsertFarmDetailsSummary(profile.id, {
      farm_name: farmNameTrim.length ? farmNameTrim : null,
      farm_overview: overviewTrim.length ? overviewTrim : null,
    });
    if (fe) setError(fe);
    else setSuccess("Profile and farm summary updated.");
    setSaving(false);
  };

  return (
    <motion.div className="content-card stack" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
      <div>
        <h2 className="section-title">My profile</h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Update the name, bio, location, and photo other members see when you join discussions, projects, or events.
        </p>
      </div>

      {loading ? <p className="subtle">Loading profile…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      {profile ? (
        <>
          <div className="platform-profile-hero">
            <UserAvatar url={profile.avatar_url} name={profile.full_name ?? profile.username} email={email} size={88} />
            <div>
              <div className="section-title" style={{ fontSize: "1.3rem" }}>{profile.full_name || profile.username || "Farmer"}</div>
              <div className="subtle">{profile.username ? `@${profile.username}` : email}</div>
              {followStats ? (
                <div className="platform-profile-stats" style={{ marginTop: 10 }}>
                  <Link href="/platform/profile/followers" className="platform-profile-stat">
                    <strong>{followStats.followers}</strong> followers
                  </Link>
                  <Link href="/platform/profile/following" className="platform-profile-stat">
                    <strong>{followStats.following}</strong> following
                  </Link>
                  <span className="platform-profile-stat">
                    <strong>{followStats.posts}</strong> posts
                  </span>
                </div>
              ) : null}
              {profile.bio?.trim() ? <p className="platform-profile-bio">{profile.bio.trim()}</p> : null}
              <div className="platform-profile-actions">
                <button type="button" className="btn btn-secondary" onClick={() => setFarmModalOpen(true)}>
                  Farm details
                </button>
              </div>
            </div>
          </div>

          <div className="platform-profile-tabs" role="tablist" aria-label="Profile sections">
            <button
              type="button"
              role="tab"
              aria-selected={tab === "about"}
              className={`platform-profile-tab${tab === "about" ? " active" : ""}`}
              onClick={() => setTab("about")}
            >
              About
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "posts"}
              className={`platform-profile-tab${tab === "posts" ? " active" : ""}`}
              onClick={() => setTab("posts")}
            >
              My posts
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "events"}
              className={`platform-profile-tab${tab === "events" ? " active" : ""}`}
              onClick={() => setTab("events")}
            >
              My events
            </button>
          </div>

          {tab === "about" ? (
            <form onSubmit={save} className="stack platform-profile-panel">
              <div className="field">
                <label>Full name</label>
                <input value={profile.full_name ?? ""} onChange={(e) => update("full_name", e.target.value)} />
              </div>
              <div className="field">
                <label>Bio</label>
                <textarea rows={4} value={profile.bio ?? ""} onChange={(e) => update("bio", e.target.value)} />
              </div>
              <div className="field">
                <label>Location</label>
                <input value={profile.location ?? ""} onChange={(e) => update("location", e.target.value)} />
              </div>
              <div className="field">
                <label>Farm overview</label>
                <textarea
                  rows={5}
                  value={farmOverview}
                  onChange={(e) => setFarmOverview(e.target.value)}
                  placeholder="Region, land, story—anything that helps others understand your farm."
                />
              </div>
              <div className="field">
                <label>Farm name</label>
                <input value={farmName} onChange={(e) => setFarmName(e.target.value)} placeholder="Optional display name for your farm" />
              </div>
              <div className="field">
                <label>Farm type</label>
                <input value={profile.farm_type ?? ""} onChange={(e) => update("farm_type", e.target.value)} />
              </div>
              <div className="field">
                <label>Experience level</label>
                <input value={profile.experience_level ?? ""} onChange={(e) => update("experience_level", e.target.value)} />
              </div>
              <div className="field">
                <label>Avatar URL</label>
                <input value={profile.avatar_url ?? ""} onChange={(e) => update("avatar_url", e.target.value)} placeholder="https://..." />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end" }}>
                <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? "Saving…" : "Save profile"}</button>
              </div>
            </form>
          ) : null}

          {tab === "posts" ? (
            <div className="platform-profile-panel">
              {loadingPosts ? <p className="subtle">Loading posts…</p> : null}
              {!loadingPosts && posts.length === 0 ? (
                <p className="empty">No posts yet. Start one from the Forums page.</p>
              ) : null}
              <ProfilePostGrid posts={posts} />
            </div>
          ) : null}

          {tab === "events" ? (
            <div className="platform-profile-panel">
              <PlatformEventList
                events={events}
                loading={loadingEvents}
                emptyMessage="No events yet. Create one from Events in the workspace."
              />
            </div>
          ) : null}
          <FarmDetailsModal
            open={farmModalOpen}
            onClose={() => setFarmModalOpen(false)}
            farm={farmDetails}
            isOwnProfile
          />
        </>
      ) : null}
    </motion.div>
  );
}

"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { isVideoMediaUrl } from "@/lib/image-urls";
import { parseImageUrls } from "@/lib/media-urls";
import { PostMediaPreview } from "@/components/post-media-preview";
import { linkifyPlainText } from "@/lib/linkify-plain-text";
import { MotionListItem } from "@/components/motion-list";
import { UserAvatar } from "@/components/user-avatar";
import { ForumTagPicker } from "@/components/forum-tag-picker";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";
import { ONTARIO_COUNTIES } from "@/lib/ontario-counties";

type ContentFilter = "all" | "photos" | "videos";
type SortKey = "newest" | "oldest" | "most_liked" | "most_commented";

type PostRow = {
  id: string;
  user_id: string;
  title: string | null;
  content: string | null;
  location: string | null;
  image_urls: unknown;
  tags: unknown;
  post_type: string | null;
  created_at: string;
};

type ProfileRow = {
  id: string;
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
};

function parseTextArray(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw.map((v) => String(v).trim()).filter((v) => v.length > 0);
  }
  if (typeof raw === "string") {
    try {
      const j = JSON.parse(raw) as unknown;
      if (Array.isArray(j)) return j.map((v) => String(v).trim()).filter((v) => v.length > 0);
    } catch {}
  }
  return [];
}

function isVideoUrl(url: string): boolean {
  const u = url.toLowerCase();
  return (
    u.endsWith(".mp4") ||
    u.endsWith(".mov") ||
    u.endsWith(".avi") ||
    u.endsWith(".mkv") ||
    u.includes("video") ||
    u.includes(".mp4?")
  );
}

function postHasVideo(imageUrls: string[]) {
  return imageUrls.some(isVideoUrl);
}

function postHasPhotoOnly(imageUrls: string[]) {
  if (imageUrls.length === 0) return false;
  return imageUrls.every((u) => !isVideoUrl(u));
}

function displayPostTitle(title: string | null | undefined) {
  const t = (title ?? "").trim();
  if (!t) return null;
  if (t.toLowerCase() === "post") return null;
  return t;
}

async function removePostImages(post: PostRow) {
  const urls = parseImageUrls(post.image_urls);
  for (const imageUrl of urls) {
    try {
      const uri = new URL(imageUrl);
      const pathSegments = uri.pathname.split("/").filter(Boolean);
      const bucketIndex = pathSegments.indexOf("public");
      if (bucketIndex !== -1 && bucketIndex < pathSegments.length - 2) {
        const bucket = pathSegments[bucketIndex + 1];
        const path = pathSegments.slice(bucketIndex + 2).join("/");
        await supabase.storage.from(bucket).remove([path]);
      }
    } catch {
    }
  }
}

export default function PlatformFeedPage() {
  const router = useRouter();
  const { staffAccess, ready: staffReady } = useStaffAccess();
  const isSuper = staffReady && isSuperEffective(staffAccess);

  const [posts, setPosts] = useState<PostRow[]>([]);
  const [profiles, setProfiles] = useState<Record<string, ProfileRow>>({});
  const [commentCounts, setCommentCounts] = useState<Record<string, number>>({});
  const [likeCounts, setLikeCounts] = useState<Record<string, number>>({});
  const [likedByMe, setLikedByMe] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [contentFilter, setContentFilter] = useState<ContentFilter>("all");
  const [sortBy, setSortBy] = useState<SortKey>("newest");
  const [filterTags, setFilterTags] = useState<string[]>([]);
  const [tagsFilterOpen, setTagsFilterOpen] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftBody, setDraftBody] = useState("");
  const [draftLocation, setDraftLocation] = useState("");
  const [draftImageUrl, setDraftImageUrl] = useState("");
  const [draftTags, setDraftTags] = useState<string[]>([]);

  const [editOpen, setEditOpen] = useState(false);
  const [editingPost, setEditingPost] = useState<PostRow | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [editBody, setEditBody] = useState("");
  const [editLocation, setEditLocation] = useState("");
  const [editImageUrl, setEditImageUrl] = useState("");
  const [editTags, setEditTags] = useState<string[]>([]);
  const [savingEdit, setSavingEdit] = useState(false);

  const [imageLightboxUrl, setImageLightboxUrl] = useState<string | null>(null);

  const editCountyOptions = useMemo(() => {
    const t = editLocation.trim();
    if (t && !ONTARIO_COUNTIES.includes(t)) return [t, ...ONTARIO_COUNTIES];
    return ONTARIO_COUNTIES;
  }, [editLocation]);

  useEffect(() => {
    if (!imageLightboxUrl) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setImageLightboxUrl(null);
    };
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [imageLightboxUrl]);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setError(null);
      setLoading(true);

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!cancelled) setCurrentUserId(user?.id ?? null);

      const { data: postData, error: postError } = await supabase
        .from("posts")
        .select("id, user_id, title, content, location, image_urls, tags, post_type, created_at")
        .order("created_at", { ascending: false })
        .limit(80);

      if (cancelled) return;
      if (postError) {
        setError(postError.message);
        setLoading(false);
        return;
      }

      const rows = (postData as PostRow[]) ?? [];
      setPosts(rows);

      const postIds = rows.map((r) => r.id);
      if (postIds.length > 0) {
        const { data: commentsData } = await supabase.from("comments").select("post_id").in("post_id", postIds);
        if (!cancelled) {
          const nextCounts: Record<string, number> = {};
          for (const c of (commentsData as { post_id: string }[] | null) ?? []) {
            nextCounts[c.post_id] = (nextCounts[c.post_id] ?? 0) + 1;
          }
          setCommentCounts(nextCounts);
        }

        const uid = user?.id ?? null;
        const { data: likeData, error: likeErr } = await supabase
          .from("post_likes")
          .select("post_id, user_id")
          .in("post_id", postIds);
        if (!cancelled && !likeErr && likeData) {
          const nextLikes: Record<string, number> = {};
          const nextMine: Record<string, boolean> = {};
          for (const row of likeData as { post_id: string; user_id: string }[]) {
            nextLikes[row.post_id] = (nextLikes[row.post_id] ?? 0) + 1;
            if (uid && row.user_id === uid) nextMine[row.post_id] = true;
          }
          setLikeCounts(nextLikes);
          setLikedByMe(nextMine);
        } else if (!cancelled && likeErr) {
          setLikeCounts({});
          setLikedByMe({});
        }
      } else {
        setCommentCounts({});
        setLikeCounts({});
        setLikedByMe({});
      }

      const userIds = [...new Set(rows.map((r) => r.user_id).filter(Boolean))];
      if (userIds.length === 0) {
        setProfiles({});
        setLoading(false);
        return;
      }

      const { data: profileData, error: profileError } = await supabase
        .from("user_profiles")
        .select("id, full_name, username, avatar_url")
        .in("id", userIds);

      if (cancelled) return;
      if (profileError) {
        setError(profileError.message);
        setLoading(false);
        return;
      }

      const map: Record<string, ProfileRow> = {};
      for (const p of (profileData as ProfileRow[]) ?? []) map[p.id] = p;
      setProfiles(map);
      setLoading(false);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const visiblePosts = useMemo(() => {
    let list = [...posts];

    if (contentFilter === "photos") {
      list = list.filter((p) => {
        const urls = parseImageUrls(p.image_urls);
        return urls.length > 0 && postHasPhotoOnly(urls);
      });
    } else if (contentFilter === "videos") {
      list = list.filter((p) => {
        const urls = parseImageUrls(p.image_urls);
        return postHasVideo(urls);
      });
    }

    if (filterTags.length > 0) {
      const need = new Set(filterTags);
      list = list.filter((p) => {
        const tags = parseTextArray(p.tags);
        return tags.some((t) => need.has(t));
      });
    }

    const sorted = [...list];
    switch (sortBy) {
      case "oldest":
        sorted.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
        break;
      case "most_liked":
        sorted.sort((a, b) => (likeCounts[b.id] ?? 0) - (likeCounts[a.id] ?? 0));
        break;
      case "most_commented":
        sorted.sort((a, b) => (commentCounts[b.id] ?? 0) - (commentCounts[a.id] ?? 0));
        break;
      default:
        sorted.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    }
    return sorted;
  }, [posts, contentFilter, sortBy, filterTags, likeCounts, commentCounts]);

  const createPost = async (e: FormEvent) => {
    e.preventDefault();
    if (!draftBody.trim()) return;
    setCreating(true);
    setError(null);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Sign in required.");
      setCreating(false);
      return;
    }

    const payload = {
      user_id: user.id,
      title: draftTitle.trim() || "Post",
      content: draftBody.trim(),
      post_type: "general" as const,
      tags: draftTags,
      image_urls: draftImageUrl.trim() ? [draftImageUrl.trim()] : [],
      ...(draftLocation.trim() ? { location: draftLocation.trim() } : {}),
    };

    const { data, error: insertError } = await supabase
      .from("posts")
      .insert(payload)
      .select("id, user_id, title, content, location, image_urls, tags, post_type, created_at")
      .single();

    if (insertError) {
      setError(insertError.message);
      setCreating(false);
      return;
    }

    setPosts((prev) => [data as PostRow, ...prev]);
    setCreateOpen(false);
    setDraftTitle("");
    setDraftBody("");
    setDraftLocation("");
    setDraftImageUrl("");
    setDraftTags([]);
    setCreating(false);
  };

  const deletePost = async (post: PostRow) => {
    if (!confirm("Delete this post?")) return;
    setError(null);

    await removePostImages(post);
    await supabase.from("comments").delete().eq("post_id", post.id);
    const { error: dErr } = await supabase.from("posts").delete().eq("id", post.id);
    if (dErr) {
      setError(dErr.message);
      return;
    }

    setPosts((prev) => prev.filter((p) => p.id !== post.id));
    setCommentCounts((prev) => {
      const next = { ...prev };
      delete next[post.id];
      return next;
    });
    setLikeCounts((prev) => {
      const next = { ...prev };
      delete next[post.id];
      return next;
    });
    setLikedByMe((prev) => {
      const next = { ...prev };
      delete next[post.id];
      return next;
    });
  };

  const toggleLike = async (post: PostRow) => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Sign in required.");
      return;
    }

    const liked = !!likedByMe[post.id];
    setError(null);

    if (liked) {
      const { error: delErr } = await supabase.from("post_likes").delete().eq("post_id", post.id).eq("user_id", user.id);
      if (delErr) {
        setError(delErr.message);
        return;
      }
      setLikedByMe((prev) => ({ ...prev, [post.id]: false }));
      setLikeCounts((prev) => ({
        ...prev,
        [post.id]: Math.max(0, (prev[post.id] ?? 1) - 1),
      }));
    } else {
      const { error: insErr } = await supabase.from("post_likes").insert({ post_id: post.id, user_id: user.id });
      if (insErr) {
        setError(insErr.message);
        return;
      }
      setLikedByMe((prev) => ({ ...prev, [post.id]: true }));
      setLikeCounts((prev) => ({
        ...prev,
        [post.id]: (prev[post.id] ?? 0) + 1,
      }));
    }
  };

  const openEdit = (post: PostRow) => {
    setEditingPost(post);
    setEditTitle(post.title ?? "");
    setEditBody(post.content ?? "");
    setEditLocation((post.location ?? "").trim());
    const urls = parseImageUrls(post.image_urls);
    setEditImageUrl(urls[0] ?? "");
    setEditTags(parseTextArray(post.tags));
    setEditOpen(true);
  };

  const saveEdit = async (e: FormEvent) => {
    e.preventDefault();
    if (!editingPost || !editBody.trim()) return;
    setSavingEdit(true);
    setError(null);

    const payload = {
      title: editTitle.trim() || "Post",
      content: editBody.trim(),
      post_type: "general" as const,
      tags: editTags,
      image_urls: editImageUrl.trim() ? [editImageUrl.trim()] : [],
      location: editLocation.trim() || null,
      updated_at: new Date().toISOString(),
    };

    const { data, error: uErr } = await supabase
      .from("posts")
      .update(payload)
      .eq("id", editingPost.id)
      .select("id, user_id, title, content, location, image_urls, tags, post_type, created_at")
      .single();

    if (uErr) {
      setError(uErr.message);
      setSavingEdit(false);
      return;
    }

    const row = data as PostRow;
    setPosts((prev) => prev.map((p) => (p.id === row.id ? row : p)));
    setEditOpen(false);
    setEditingPost(null);
    setSavingEdit(false);
  };

  const closeEdit = () => {
    setEditOpen(false);
    setEditingPost(null);
  };

  return (
    <div className="platform-feed-shell stack" style={{ gap: 14 }}>
      <div className="platform-feed-toolbar">
        <div className="platform-feed-toolbar-inner" style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 10 }}>
          <div className="platform-feed-filters" style={{ flexWrap: "wrap" }}>
            <button
              type="button"
              className={`platform-chip${contentFilter === "all" ? " active" : ""}`}
              onClick={() => setContentFilter("all")}
            >
              All
            </button>
            <button
              type="button"
              className={`platform-chip${contentFilter === "photos" ? " active" : ""}`}
              onClick={() => setContentFilter("photos")}
            >
              Photos
            </button>
            <button
              type="button"
              className={`platform-chip${contentFilter === "videos" ? " active" : ""}`}
              onClick={() => setContentFilter("videos")}
            >
              Videos
            </button>
          </div>
          <div className="platform-feed-sort-row">
            <label className="platform-feed-sort-label">
              Sort
              <select
                className="input platform-feed-sort-select"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortKey)}
              >
                <option value="newest">Newest first</option>
                <option value="oldest">Oldest first</option>
                <option value="most_liked">Most liked</option>
                <option value="most_commented">Most comments</option>
              </select>
            </label>
            <button type="button" className="btn btn-secondary platform-feed-tags-btn" onClick={() => setTagsFilterOpen(true)}>
              Tags{filterTags.length > 0 ? ` (${filterTags.length})` : ""}
            </button>
          </div>
        </div>
        <button
          type="button"
          className="btn btn-primary btn-primary-compact"
          onClick={() => {
            setDraftTags([]);
            setCreateOpen(true);
          }}
        >
          Create New
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading feed…</p> : null}
      {!loading && visiblePosts.length === 0 ? <p className="empty">No posts yet.</p> : null}

      <div className="list">
        {visiblePosts.map((post, index) => {
          const profile = profiles[post.user_id];
          const imageUrls = parseImageUrls(post.image_urls);
          const imageUrl = imageUrls[0] ?? null;
          const isVideo = imageUrl ? isVideoMediaUrl(imageUrl) || isVideoUrl(imageUrl) : false;
          const tags = parseTextArray(post.tags);
          const rawName = profile?.full_name?.trim();
          const uname = profile?.username?.trim();
          const author = rawName || uname || "Farmer";
          const nLikes = likeCounts[post.id] ?? 0;
          const nComments = commentCounts[post.id] ?? 0;
          const mine = currentUserId === post.user_id;
          const canEditPost = mine || isSuper;
          const heading = displayPostTitle(post.title);
          const authorProfileHref = mine ? "/platform/profile" : `/platform/user/${post.user_id}`;

          return (
            <MotionListItem
              key={post.id}
              index={index}
              className="list-item platform-post-card feed-post-item"
            >
              <article className="feed-post">
                <header className="feed-post-header">
                  <Link href={authorProfileHref} className="feed-post-author-link" aria-label={`View ${author}'s profile`}>
                    <UserAvatar url={profile?.avatar_url} name={author} size={44} />
                  </Link>
                  <div className="feed-post-header-main">
                    <div className="feed-post-header-top">
                      <div className="feed-post-identity">
                        <Link href={authorProfileHref} className="feed-post-name feed-post-author-link">
                          {rawName ? rawName : uname ? `@${uname}` : "Farmer"}
                        </Link>
                      </div>
                    </div>
                    <div className="feed-post-meta-line">
                      {rawName && uname ? <span className="feed-post-handle">@{uname}</span> : null}
                      {rawName && uname ? (
                        <span className="feed-post-sep" aria-hidden>
                          ·
                        </span>
                      ) : null}
                      <time className="feed-post-time" dateTime={post.created_at}>
                        {formatDate(post.created_at)}
                      </time>
                    </div>
                  </div>
                </header>

                {heading ? (
                  <h2 className="feed-post-title">
                    <Link href={`/platform/post/${post.id}`} className="feed-post-title-link">
                      {heading}
                    </Link>
                  </h2>
                ) : null}
                <p className="feed-post-body">
                  {post.content?.trim() ? linkifyPlainText(post.content, "inline-link feed-post-link") : "No content."}
                </p>

                {imageUrl ? (
                  <div className="feed-post-media">
                    <PostMediaPreview
                      mediaUrl={imageUrl}
                      triggerClassName="feed-post-media-trigger"
                      imageClassName="feed-post-media-img"
                      isVideo={isVideo}
                      onOpen={() => router.push(`/platform/post/${post.id}`)}
                    />
                  </div>
                ) : null}

                {tags.length > 0 ? (
                  <div className="platform-tag-row feed-post-tags">
                    {tags.map((t) => (
                      <span key={t} className="pill forum-post-tag-pill">
                        #{t}
                      </span>
                    ))}
                  </div>
                ) : null}

                {post.location ? (
                  <p className="feed-post-location">
                    <span className="feed-post-location-label">Location</span> {post.location}
                  </p>
                ) : null}

                <footer className="feed-post-footer">
                  <div className="feed-post-actions">
                    <button
                      type="button"
                      className={`feed-post-action${likedByMe[post.id] ? " active" : ""}`}
                      onClick={() => void toggleLike(post)}
                      aria-pressed={likedByMe[post.id]}
                    >
                      <span className="feed-post-action-label">{likedByMe[post.id] ? "Liked" : "Like"}</span>
                      <span className="feed-post-action-count">{nLikes}</span>
                    </button>
                    <Link href={`/platform/post/${post.id}#comments`} className="feed-post-action">
                      <span className="feed-post-action-label">Comment</span>
                      <span className="feed-post-action-count">{nComments}</span>
                    </Link>
                    {canEditPost ? (
                      <>
                        <button type="button" className="feed-post-action feed-post-action-muted" onClick={() => openEdit(post)}>
                          Edit
                        </button>
                        <button type="button" className="feed-post-action feed-post-action-danger" onClick={() => void deletePost(post)}>
                          Delete
                        </button>
                      </>
                    ) : null}
                  </div>
                </footer>
              </article>
            </MotionListItem>
          );
        })}
      </div>

      {createOpen ? (
        <div className="backdrop active" role="dialog" aria-modal="true">
          <div className="absolute inset-0" onClick={() => setCreateOpen(false)} />
          <div className="modal-content platform-create-modal" style={{ opacity: 1, transform: "none" }}>
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <h3 className="section-title" style={{ fontSize: "1.2rem" }}>Create post</h3>
                <button type="button" className="btn btn-secondary" onClick={() => setCreateOpen(false)}>Close</button>
              </div>
              <form className="stack" onSubmit={createPost}>
                <div className="field">
                  <label>Title</label>
                  <input value={draftTitle} onChange={(e) => setDraftTitle(e.target.value)} placeholder="Short heading" />
                </div>
                <div className="field">
                  <label>Body</label>
                  <textarea rows={4} required value={draftBody} onChange={(e) => setDraftBody(e.target.value)} placeholder="What would you like to share?" />
                </div>
                <div className="field">
                  <label>Tags (optional)</label>
                  <p className="subtle" style={{ marginTop: 0, marginBottom: 8 }}>
                    Same categories as the mobile app. Tap to add or remove.
                  </p>
                  <div style={{ maxHeight: 220, overflowY: "auto", paddingRight: 4 }}>
                    <ForumTagPicker selected={draftTags} onChange={setDraftTags} />
                  </div>
                </div>
                <div className="field">
                  <label htmlFor="feed-create-location">Location (optional)</label>
                  <select
                    id="feed-create-location"
                    className="input"
                    value={draftLocation}
                    onChange={(e) => setDraftLocation(e.target.value)}
                  >
                    <option value="">Select county…</option>
                    {ONTARIO_COUNTIES.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label>Image URL (optional)</label>
                  <input value={draftImageUrl} onChange={(e) => setDraftImageUrl(e.target.value)} placeholder="https://..." />
                </div>
                <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setCreateOpen(false)}>Cancel</button>
                  <button type="submit" className="btn btn-primary" disabled={creating}>{creating ? "Posting…" : "Publish"}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      ) : null}

      {tagsFilterOpen ? (
        <div className="backdrop active" role="dialog" aria-modal="true" aria-labelledby="feed-tags-filter-title">
          <div className="absolute inset-0" onClick={() => setTagsFilterOpen(false)} />
          <div
            className="modal-content platform-create-modal"
            style={{ opacity: 1, transform: "none", maxWidth: 520, width: "min(96vw, 520px)" }}
          >
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
                <h3 id="feed-tags-filter-title" className="section-title" style={{ fontSize: "1.15rem" }}>
                  Filter by tags
                </h3>
                <button type="button" className="btn btn-secondary" onClick={() => setTagsFilterOpen(false)}>
                  Done
                </button>
              </div>
              <p className="subtle" style={{ margin: 0 }}>
                Show posts that include <strong>any</strong> of the tags you select (same list as the mobile Community
                screen).
              </p>
              <div style={{ maxHeight: "min(60vh, 420px)", overflowY: "auto", paddingRight: 4 }}>
                <ForumTagPicker selected={filterTags} onChange={setFilterTags} />
              </div>
              <div style={{ display: "flex", gap: 10, justifyContent: "space-between", flexWrap: "wrap" }}>
                <button type="button" className="btn btn-secondary" onClick={() => setFilterTags([])}>
                  Clear all
                </button>
                <button type="button" className="btn btn-primary" onClick={() => setTagsFilterOpen(false)}>
                  Apply
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {editOpen && editingPost ? (
        <div className="backdrop active" role="dialog" aria-modal="true">
          <div className="absolute inset-0" onClick={closeEdit} />
          <div className="modal-content platform-create-modal" style={{ opacity: 1, transform: "none" }}>
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <h3 className="section-title" style={{ fontSize: "1.2rem" }}>Edit post</h3>
                <button type="button" className="btn btn-secondary" onClick={closeEdit}>Close</button>
              </div>
              <form className="stack" onSubmit={saveEdit}>
                <div className="field">
                  <label>Title</label>
                  <input value={editTitle} onChange={(e) => setEditTitle(e.target.value)} placeholder="Short heading" />
                </div>
                <div className="field">
                  <label>Body</label>
                  <textarea rows={4} required value={editBody} onChange={(e) => setEditBody(e.target.value)} placeholder="What would you like to share?" />
                </div>
                <div className="field">
                  <label>Tags</label>
                  <div style={{ maxHeight: 220, overflowY: "auto", paddingRight: 4 }}>
                    <ForumTagPicker selected={editTags} onChange={setEditTags} />
                  </div>
                </div>
                <div className="field">
                  <label htmlFor="feed-edit-location">Location (optional)</label>
                  <select
                    id="feed-edit-location"
                    className="input"
                    value={editLocation}
                    onChange={(e) => setEditLocation(e.target.value)}
                  >
                    <option value="">No county</option>
                    {editCountyOptions.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label>Image URL (optional)</label>
                  <input value={editImageUrl} onChange={(e) => setEditImageUrl(e.target.value)} placeholder="https://..." />
                </div>
                <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
                  <button type="button" className="btn btn-secondary" onClick={closeEdit}>Cancel</button>
                  <button type="submit" className="btn btn-primary" disabled={savingEdit}>{savingEdit ? "Saving…" : "Save changes"}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      ) : null}

      {imageLightboxUrl ? (
        <div
          className="backdrop active feed-image-lightbox"
          role="dialog"
          aria-modal="true"
          aria-label="Image preview"
          onClick={(e) => {
            if (e.target === e.currentTarget) setImageLightboxUrl(null);
          }}
        >
          <div className="feed-image-lightbox-panel">
            <button
              type="button"
              className="feed-image-lightbox-close btn btn-secondary"
              onClick={() => setImageLightboxUrl(null)}
            >
              Close
            </button>
            <img src={imageLightboxUrl} alt="" className="feed-image-lightbox-img" draggable={false} />
          </div>
        </div>
      ) : null}
    </div>
  );
}

"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { isVideoMediaUrl } from "@/lib/image-urls";
import { parseImageUrls } from "@/lib/media-urls";
import { PostMediaPreview } from "@/components/post-media-preview";
import { linkifyPlainText } from "@/lib/linkify-plain-text";
import { UserAvatar } from "@/components/user-avatar";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";

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

type CommentRow = {
  id: string;
  post_id: string;
  user_id: string;
  content: string;
  created_at: string;
  parent_id: string | null;
};

function parseTextArray(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw.map((v) => String(v).trim()).filter((v) => v.length > 0);
  }
  if (typeof raw === "string") {
    try {
      const j = JSON.parse(raw) as unknown;
      if (Array.isArray(j)) return j.map((v) => String(v).trim()).filter((v) => v.length > 0);
    } catch {
      /* ignore */
    }
  }
  return [];
}

function displayPostTitle(title: string | null | undefined) {
  const t = (title ?? "").trim();
  if (!t) return null;
  if (t.toLowerCase() === "post") return null;
  return t;
}

function isVideoUrl(url: string): boolean {
  return isVideoMediaUrl(url) || url.toLowerCase().includes("video");
}

type PostDetailViewProps = {
  postId: string;
};

export function PostDetailView({ postId }: PostDetailViewProps) {
  const router = useRouter();
  const { staffAccess, ready: staffReady } = useStaffAccess();
  const isSuper = staffReady && isSuperEffective(staffAccess);

  const [post, setPost] = useState<PostRow | null>(null);
  const [author, setAuthor] = useState<ProfileRow | null>(null);
  const [comments, setComments] = useState<CommentRow[]>([]);
  const [commentProfiles, setCommentProfiles] = useState<Record<string, ProfileRow>>({});
  const [likeCount, setLikeCount] = useState(0);
  const [likedByMe, setLikedByMe] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [commentDraft, setCommentDraft] = useState("");
  const [replyingToId, setReplyingToId] = useState<string | null>(null);
  const [commentSubmitting, setCommentSubmitting] = useState(false);
  const [imageLightboxUrl, setImageLightboxUrl] = useState<string | null>(null);

  const mergeProfiles = useCallback((rows: ProfileRow[]) => {
    setCommentProfiles((prev) => {
      const next = { ...prev };
      for (const p of rows) next[p.id] = p;
      return next;
    });
  }, []);

  const loadComments = useCallback(
    async (pid: string) => {
      const { data, error: cErr } = await supabase
        .from("comments")
        .select("id, post_id, user_id, content, created_at, parent_id")
        .eq("post_id", pid)
        .order("created_at", { ascending: true });

      if (cErr) {
        setError(cErr.message);
        return;
      }

      const rows = (data as CommentRow[]) ?? [];
      setComments(rows);

      const needIds = [...new Set(rows.map((r) => r.user_id).filter(Boolean))];
      if (needIds.length > 0) {
        const { data: profs } = await supabase
          .from("user_profiles")
          .select("id, full_name, username, avatar_url")
          .in("id", needIds);
        if (profs?.length) mergeProfiles(profs as ProfileRow[]);
      }
    },
    [mergeProfiles]
  );

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      setError(null);

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!cancelled) setCurrentUserId(user?.id ?? null);

      const { data: postData, error: postErr } = await supabase
        .from("posts")
        .select("id, user_id, title, content, location, image_urls, tags, post_type, created_at")
        .eq("id", postId)
        .maybeSingle();

      if (cancelled) return;
      if (postErr || !postData) {
        setError(postErr?.message ?? "Post not found.");
        setLoading(false);
        return;
      }

      const row = postData as PostRow;
      setPost(row);

      const { data: profileData } = await supabase
        .from("user_profiles")
        .select("id, full_name, username, avatar_url")
        .eq("id", row.user_id)
        .maybeSingle();
      if (!cancelled && profileData) setAuthor(profileData as ProfileRow);

      const { data: likeRows } = await supabase.from("post_likes").select("user_id").eq("post_id", postId);
      if (!cancelled && likeRows) {
        setLikeCount(likeRows.length);
        setLikedByMe(user ? likeRows.some((r) => (r as { user_id: string }).user_id === user.id) : false);
      }

      await loadComments(postId);
      if (!cancelled) setLoading(false);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [postId, loadComments]);

  useEffect(() => {
    if (loading || typeof window === "undefined") return;
    if (window.location.hash === "#comments") {
      document.getElementById("comments")?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [loading]);

  const topLevelComments = useMemo(
    () => comments.filter((c) => !c.parent_id),
    [comments]
  );

  const repliesByParent = useMemo(() => {
    const map = new Map<string, CommentRow[]>();
    for (const c of comments) {
      if (!c.parent_id) continue;
      const list = map.get(c.parent_id) ?? [];
      list.push(c);
      map.set(c.parent_id, list);
    }
    return map;
  }, [comments]);

  const toggleLike = async () => {
    if (!post) return;
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Sign in to like posts.");
      return;
    }

    if (likedByMe) {
      const { error: delErr } = await supabase.from("post_likes").delete().eq("post_id", post.id).eq("user_id", user.id);
      if (delErr) {
        setError(delErr.message);
        return;
      }
      setLikedByMe(false);
      setLikeCount((n) => Math.max(0, n - 1));
    } else {
      const { error: insErr } = await supabase.from("post_likes").insert({ post_id: post.id, user_id: user.id });
      if (insErr) {
        setError(insErr.message);
        return;
      }
      setLikedByMe(true);
      setLikeCount((n) => n + 1);
    }
  };

  const addComment = async (e: FormEvent) => {
    e.preventDefault();
    if (!post || !commentDraft.trim()) return;

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Sign in to comment.");
      return;
    }

    setCommentSubmitting(true);
    const payload: { post_id: string; user_id: string; content: string; parent_id?: string } = {
      post_id: post.id,
      user_id: user.id,
      content: commentDraft.trim(),
    };
    if (replyingToId) payload.parent_id = replyingToId;

    const { error: cErr } = await supabase.from("comments").insert(payload);
    if (cErr) {
      setError(cErr.message);
      setCommentSubmitting(false);
      return;
    }

    setCommentDraft("");
    setReplyingToId(null);
    await loadComments(post.id);
    setCommentSubmitting(false);
  };

  const deleteComment = async (commentId: string) => {
    if (!confirm("Delete this comment?")) return;
    const { error: dErr } = await supabase.from("comments").delete().eq("id", commentId);
    if (dErr) {
      setError(dErr.message);
      return;
    }
    if (post) await loadComments(post.id);
  };

  const renderComment = (c: CommentRow, depth = 0) => {
    const cp = commentProfiles[c.user_id] ?? author;
    const name = cp?.full_name?.trim() || cp?.username || "Farmer";
    const profileHref = currentUserId === c.user_id ? "/platform/profile" : `/platform/user/${c.user_id}`;
    const commentMine = currentUserId === c.user_id;
    const canDelete = isSuper || commentMine;
    const replies = repliesByParent.get(c.id) ?? [];

    return (
      <div key={c.id} className={`post-detail-comment${depth > 0 ? " is-reply" : ""}`}>
        <div className="feed-author-row" style={{ justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
          <Link href={profileHref} className="feed-post-author-link" style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <UserAvatar url={cp?.avatar_url} name={name} size={32} />
            <div>
              <div className="workshop-line-title" style={{ fontSize: "0.84rem" }}>
                {name}
              </div>
              <div className="workshop-line-meta">{formatDate(c.created_at)}</div>
            </div>
          </Link>
          <div style={{ display: "flex", gap: 8 }}>
            {currentUserId ? (
              <button type="button" className="btn btn-secondary" style={{ padding: "4px 10px", fontSize: "0.8rem" }} onClick={() => setReplyingToId(c.id)}>
                Reply
              </button>
            ) : null}
            {canDelete ? (
              <button type="button" className="btn btn-danger" style={{ padding: "4px 10px", fontSize: "0.8rem" }} onClick={() => void deleteComment(c.id)}>
                Delete
              </button>
            ) : null}
          </div>
        </div>
        <div className="post-detail-comment-body">{linkifyPlainText(c.content, "inline-link")}</div>
        {replies.map((r) => renderComment(r, depth + 1))}
      </div>
    );
  };

  if (loading) {
    return (
      <motion.div className="content-card stack" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <p className="subtle">Loading post…</p>
      </motion.div>
    );
  }

  if (!post) {
    return (
      <motion.div className="content-card stack" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <button type="button" className="btn btn-secondary" onClick={() => router.back()}>
          Back
        </button>
        <p className="empty">{error ?? "Post not found."}</p>
      </motion.div>
    );
  }

  const imageUrl = parseImageUrls(post.image_urls)[0] ?? null;
  const isVideo = imageUrl ? isVideoUrl(imageUrl) : false;
  const tags = parseTextArray(post.tags);
  const heading = displayPostTitle(post.title);
  const rawName = author?.full_name?.trim();
  const uname = author?.username?.trim();
  const authorLabel = rawName || uname || "Farmer";
  const authorHref = currentUserId === post.user_id ? "/platform/profile" : `/platform/user/${post.user_id}`;
  const replyingTo = replyingToId ? comments.find((c) => c.id === replyingToId) : null;
  const replyingName = replyingTo
    ? commentProfiles[replyingTo.user_id]?.full_name ||
      commentProfiles[replyingTo.user_id]?.username ||
      "member"
    : null;

  return (
    <motion.div className="content-card stack post-detail-page" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <button type="button" className="btn btn-secondary post-detail-back" onClick={() => router.back()}>
        Back
      </button>

      {error ? <p className="error">{error}</p> : null}

      <article className="feed-post post-detail-article">
        <header className="feed-post-header">
          <Link href={authorHref} className="feed-post-author-link" aria-label={`View ${authorLabel}'s profile`}>
            <UserAvatar url={author?.avatar_url} name={authorLabel} size={48} />
          </Link>
          <div className="feed-post-header-main">
            <Link href={authorHref} className="feed-post-name feed-post-author-link">
              {rawName ? rawName : uname ? `@${uname}` : "Farmer"}
            </Link>
            <div className="feed-post-meta-line">
              <time className="feed-post-time" dateTime={post.created_at}>
                {formatDate(post.created_at)}
              </time>
              {post.location ? (
                <>
                  <span className="feed-post-sep" aria-hidden>
                    ·
                  </span>
                  <span>{post.location}</span>
                </>
              ) : null}
            </div>
          </div>
        </header>

        {heading ? <h1 className="feed-post-title post-detail-title">{heading}</h1> : null}

        {post.content?.trim() ? (
          <p className="feed-post-body">{linkifyPlainText(post.content, "inline-link feed-post-link")}</p>
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

        {imageUrl ? (
          <div className="feed-post-media post-detail-media">
            <PostMediaPreview
              mediaUrl={imageUrl}
              triggerClassName="feed-post-media-trigger"
              imageClassName="feed-post-media-img"
              isVideo={isVideo}
              onOpen={(displayUrl) => setImageLightboxUrl(displayUrl)}
            />
          </div>
        ) : null}

        <footer className="feed-post-footer">
          <div className="feed-post-actions">
            <button
              type="button"
              className={`feed-post-action${likedByMe ? " active" : ""}`}
              onClick={() => void toggleLike()}
              aria-pressed={likedByMe}
            >
              <span className="feed-post-action-label">{likedByMe ? "Liked" : "Like"}</span>
              <span className="feed-post-action-count">{likeCount}</span>
            </button>
            <span className="feed-post-action">
              <span className="feed-post-action-label">Comments</span>
              <span className="feed-post-action-count">{comments.length}</span>
            </span>
          </div>
        </footer>
      </article>

      <section className="post-detail-comments stack" id="comments">
        <h2 className="section-title" style={{ fontSize: "1.1rem" }}>
          Comments
        </h2>

        <form onSubmit={addComment} className="stack post-detail-comment-form">
          {replyingToId && replyingName ? (
            <div className="post-detail-reply-banner">
              <span className="subtle">
                Replying to <strong>{replyingName}</strong>
              </span>
              <button type="button" className="btn btn-secondary" style={{ padding: "2px 8px", fontSize: "0.78rem" }} onClick={() => setReplyingToId(null)}>
                Cancel
              </button>
            </div>
          ) : null}
          <div className="field">
            <label htmlFor="post-detail-comment">Add a comment</label>
            <textarea
              id="post-detail-comment"
              rows={3}
              value={commentDraft}
              onChange={(e) => setCommentDraft(e.target.value)}
              placeholder={replyingToId ? "Write a reply…" : "Share your thoughts…"}
            />
          </div>
          <div style={{ display: "flex", justifyContent: "flex-end" }}>
            <button type="submit" className="btn btn-primary" disabled={commentSubmitting || !commentDraft.trim()}>
              {commentSubmitting ? "Posting…" : replyingToId ? "Post reply" : "Post comment"}
            </button>
          </div>
        </form>

        <div className="platform-comment-list post-detail-comment-list">
          {topLevelComments.length === 0 ? <p className="empty">No comments yet. Be the first.</p> : null}
          {topLevelComments.map((c) => renderComment(c))}
        </div>
      </section>

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
            <button type="button" className="feed-image-lightbox-close btn btn-secondary" onClick={() => setImageLightboxUrl(null)}>
              Close
            </button>
            <img src={imageLightboxUrl} alt="" className="feed-image-lightbox-img" draggable={false} />
          </div>
        </div>
      ) : null}
    </motion.div>
  );
}

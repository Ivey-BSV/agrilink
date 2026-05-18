"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { parseImageUrls } from "@/lib/media-urls";
import { ContentThumbCell } from "@/components/content-thumb-cell";
import { MotionListItem } from "@/components/motion-list";

type PostRow = {
  id: string;
  title: string | null;
  content: string | null;
  created_at: string;
  location: string | null;
  image_urls: unknown;
};

export default function PostsPage() {
  const [items, setItems] = useState<PostRow[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState({ title: "", content: "", location: "" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

      const { data, error: fetchError } = await supabase
        .from("posts")
        .select("id, title, content, image_urls, created_at, location")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });

      if (cancelled) return;
      if (fetchError) setError(fetchError.message);
      setItems((data as PostRow[]) || []);
      setLoading(false);
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const remove = async (id: string) => {
    if (!confirm("Delete this post?")) return;
    const { error: commentsError } = await supabase.from("comments").delete().eq("post_id", id);
    if (commentsError) {
      setError(commentsError.message);
      return;
    }

    const { error: deleteError } = await supabase.from("posts").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (post: PostRow) => {
    setEditingId(post.id);
    setDraft({
      title: post.title ?? "",
      content: post.content ?? "",
      location: post.location ?? "",
    });
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase
      .from("posts")
      .update({
        title: draft.title || "Post",
        content: draft.content,
        location: draft.location || null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", id);

    if (updateError) {
      setError(updateError.message);
      return;
    }

    setItems((prev) =>
      prev.map((p) =>
        p.id === id
          ? {
              ...p,
              title: draft.title,
              content: draft.content,
              location: draft.location || null,
            }
          : p
      )
    );
    setEditingId(null);
  };

  return (
    <motion.div
      className="content-card stack"
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div>
        <h2 className="section-title">My posts</h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          See everything you have published to the community feed, edit text in place, and review the first image shown on each card.
        </p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading posts…</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No posts yet.</p> : null}
      <div className="list">
        {items.map((post, index) => {
          const firstImage = parseImageUrls(post.image_urls)[0] ?? null;
          return (
            <MotionListItem key={post.id} index={index} className="list-item file-list-row">
              {editingId === post.id ? (
                <div className="workshop-thumb-placeholder content-thumb-empty" aria-hidden>
                  Edit
                </div>
              ) : (
                <ContentThumbCell imageUrl={firstImage} />
              )}
              <div className="stack workshop-file-body" style={{ gap: 6 }}>
                {editingId === post.id ? (
                  <>
                    <div className="field">
                      <label>Title</label>
                      <input
                        value={draft.title}
                        onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
                      />
                    </div>
                    <div className="field">
                      <label>Content</label>
                      <textarea
                        rows={3}
                        value={draft.content}
                        onChange={(e) => setDraft((d) => ({ ...d, content: e.target.value }))}
                      />
                    </div>
                    <div className="field">
                      <label>Location</label>
                      <input
                        value={draft.location}
                        onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))}
                      />
                    </div>
                  </>
                ) : (
                  <>
                    <div className="workshop-line-title">{post.title || "Post"}</div>
                    <div className="workshop-line-meta">{post.content || "No content."}</div>
                  </>
                )}
                <div className="workshop-line-meta">
                  {formatDate(post.created_at)}
                  {post.location ? ` · ${post.location}` : ""}
                </div>
              </div>
              <div className="actions">
                {editingId === post.id ? (
                  <>
                    <button type="button" className="btn btn-primary" onClick={() => saveEdit(post.id)}>
                      Save
                    </button>
                    <button type="button" className="btn btn-secondary" onClick={() => setEditingId(null)}>
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <button type="button" className="btn btn-secondary" onClick={() => startEdit(post)}>
                      Edit
                    </button>
                    <button type="button" className="btn btn-danger" onClick={() => remove(post.id)}>
                      Delete
                    </button>
                  </>
                )}
              </div>
            </MotionListItem>
          );
        })}
      </div>
    </motion.div>
  );
}

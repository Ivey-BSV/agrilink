"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { parseImageUrls } from "@/lib/media-urls";
import { ContentThumbCell } from "@/components/content-thumb-cell";
import { MotionListItem } from "@/components/motion-list";
import { PageSectionHeader } from "@/components/page-section-header";

type ListingRow = {
  id: string;
  title: string;
  description: string | null;
  condition: string | null;
  created_at: string;
  image_urls: unknown;
};

export default function ListingsPage() {
  const [items, setItems] = useState<ListingRow[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState({
    title: "",
    description: "",
    condition: "",
  });
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
        .from("marketplace_listings")
        .select("id, title, description, condition, image_urls, created_at")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });

      if (cancelled) return;
      if (fetchError) setError(fetchError.message);
      setItems((data as ListingRow[]) || []);
      setLoading(false);
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const remove = async (id: string) => {
    if (!confirm("Delete this shared asset?")) return;
    const { error: deleteError } = await supabase.from("marketplace_listings").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (item: ListingRow) => {
    setEditingId(item.id);
    setDraft({
      title: item.title,
      description: item.description ?? "",
      condition: item.condition ?? "",
    });
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase
      .from("marketplace_listings")
      .update({
        title: draft.title,
        description: draft.description,
        condition: draft.condition || null,
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
              description: draft.description || null,
              condition: draft.condition || null,
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
      <PageSectionHeader
        title="My shared assets"
        description="Review assets you have listed for the community—title, description, condition, and photo."
      />
      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading shared assets…</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No shared assets yet.</p> : null}
      <div className="list">
        {items.map((item, index) => {
          const firstImage = parseImageUrls(item.image_urls)[0] ?? null;
          return (
            <MotionListItem key={item.id} index={index} className="list-item file-list-row">
              {editingId === item.id ? (
                <div className="workshop-thumb-placeholder content-thumb-empty" aria-hidden>
                  Edit
                </div>
              ) : (
                <ContentThumbCell imageUrl={firstImage} />
              )}
              <div className="stack workshop-file-body" style={{ gap: 6 }}>
                {editingId === item.id ? (
                  <>
                    <div className="field">
                      <label>Title</label>
                      <input
                        value={draft.title}
                        onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
                      />
                    </div>
                    <div className="field">
                      <label>Description</label>
                      <textarea
                        rows={3}
                        value={draft.description}
                        onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value }))}
                        placeholder="List the assets which you'd like to share with the community"
                      />
                    </div>
                    <div className="field">
                      <label>Condition</label>
                      <input
                        value={draft.condition}
                        onChange={(e) => setDraft((d) => ({ ...d, condition: e.target.value }))}
                      />
                    </div>
                  </>
                ) : (
                  <>
                    <div className="workshop-line-title">{item.title}</div>
                    <div className="workshop-line-meta">{item.description || "No description."}</div>
                  </>
                )}
                <div className="workshop-line-meta">
                  {item.condition ? `${item.condition} · ` : ""}
                  {formatDate(item.created_at)}
                </div>
              </div>
              <div className="actions">
                {editingId === item.id ? (
                  <>
                    <button type="button" className="btn btn-primary" onClick={() => saveEdit(item.id)}>
                      Save
                    </button>
                    <button type="button" className="btn btn-secondary" onClick={() => setEditingId(null)}>
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <button type="button" className="btn btn-secondary" onClick={() => startEdit(item)}>
                      Edit
                    </button>
                    <button type="button" className="btn btn-danger" onClick={() => remove(item.id)}>
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

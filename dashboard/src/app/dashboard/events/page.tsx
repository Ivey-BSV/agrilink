"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { formatEventCategory, formatEventDateTimeLine, isEventUpcoming } from "@/lib/event-format";
import { ContentThumbCell } from "@/components/content-thumb-cell";
import { MotionListItem } from "@/components/motion-list";
import { PageSectionHeader } from "@/components/page-section-header";

type EventRow = {
  id: string;
  title: string;
  category: string;
  event_date: string;
  time: string;
  location: string;
  created_at: string;
  description: string | null;
  image_url: string | null;
};

export default function EventsPage() {
  const [items, setItems] = useState<EventRow[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState({
    title: "",
    category: "",
    event_date: "",
    time: "",
    location: "",
  });
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [createDraft, setCreateDraft] = useState({
    title: "",
    category: "Workshop",
    event_date: "",
    time: "09:00",
    location: "",
    description: "",
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      setItems([]);
      setLoading(false);
      return;
    }

    const { data, error: fetchError } = await supabase
      .from("events")
      .select("id, title, category, event_date, time, location, description, image_url, created_at")
      .eq("user_id", user.id)
      .order("event_date", { ascending: false });

    if (fetchError) setError(fetchError.message);
    setItems((data as EventRow[]) || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const createEvent = async (e: FormEvent) => {
    e.preventDefault();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      return;
    }
    if (!createDraft.title.trim() || !createDraft.event_date.trim()) {
      setError("Title and event date are required.");
      return;
    }
    setCreating(true);
    setError(null);
    const { data, error: insErr } = await supabase
      .from("events")
      .insert({
        user_id: user.id,
        title: createDraft.title.trim(),
        category: createDraft.category.trim() || "General",
        description: createDraft.description.trim() || null,
        event_date: createDraft.event_date,
        time: createDraft.time.trim() || "09:00",
        location: createDraft.location.trim() || "TBD",
        max_attendees: 50,
        current_attendees: 0,
        is_co_hosted: false,
        co_host_ids: [],
        tags: [],
      })
      .select("id, title, category, event_date, time, location, description, image_url, created_at")
      .single();

    if (insErr || !data) {
      setError(insErr?.message ?? "Could not create event.");
      setCreating(false);
      return;
    }

    const row = data as EventRow;
    await supabase.from("event_registrations").insert({
      event_id: row.id,
      user_id: user.id,
    });

    setItems((prev) => [row, ...prev]);
    setCreateOpen(false);
    setCreateDraft({
      title: "",
      category: "Workshop",
      event_date: "",
      time: "09:00",
      location: "",
      description: "",
    });
    setCreating(false);
  };

  const remove = async (id: string) => {
    if (!confirm("Delete this event?")) return;

    await supabase.from("event_registrations").delete().eq("event_id", id);

    const { error: deleteError } = await supabase.from("events").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (item: EventRow) => {
    setEditingId(item.id);
    setDraft({
      title: item.title,
      category: item.category,
      event_date: item.event_date,
      time: item.time,
      location: item.location,
    });
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase
      .from("events")
      .update({
        title: draft.title,
        category: draft.category,
        event_date: draft.event_date,
        time: draft.time,
        location: draft.location,
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
              category: draft.category,
              event_date: draft.event_date,
              time: draft.time,
              location: draft.location,
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
        title="My events"
        description="Plan gatherings, set date and place, and add a cover image so members know what to expect and how to join."
        action={
          <button type="button" className="btn btn-primary btn-primary-compact" onClick={() => setCreateOpen(true)}>
            New event
          </button>
        }
      />
      {createOpen ? (
        <div className="content-card stack" style={{ gap: 12 }}>
          <h3 className="section-title" style={{ fontSize: "1.05rem" }}>
            New event
          </h3>
          <form className="stack" style={{ gap: 10 }} onSubmit={(e) => void createEvent(e)}>
            <div className="field">
              <label>Title</label>
              <input
                value={createDraft.title}
                onChange={(e) => setCreateDraft((d) => ({ ...d, title: e.target.value }))}
                required
                disabled={creating}
              />
            </div>
            <div className="field">
              <label>Category</label>
              <input
                value={createDraft.category}
                onChange={(e) => setCreateDraft((d) => ({ ...d, category: e.target.value }))}
                disabled={creating}
              />
            </div>
            <div className="field">
              <label>Date</label>
              <input
                type="date"
                value={createDraft.event_date}
                onChange={(e) => setCreateDraft((d) => ({ ...d, event_date: e.target.value }))}
                required
                disabled={creating}
              />
            </div>
            <div className="field">
              <label>Time</label>
              <input
                value={createDraft.time}
                onChange={(e) => setCreateDraft((d) => ({ ...d, time: e.target.value }))}
                disabled={creating}
              />
            </div>
            <div className="field">
              <label>Location</label>
              <input
                value={createDraft.location}
                onChange={(e) => setCreateDraft((d) => ({ ...d, location: e.target.value }))}
                disabled={creating}
              />
            </div>
            <div className="field">
              <label>Description (optional)</label>
              <textarea
                rows={3}
                value={createDraft.description}
                onChange={(e) => setCreateDraft((d) => ({ ...d, description: e.target.value }))}
                disabled={creating}
              />
            </div>
            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
              <button type="submit" className="btn btn-primary" disabled={creating}>
                {creating ? "Saving…" : "Publish event"}
              </button>
              <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      ) : null}
      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading events…</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No events yet.</p> : null}
      <div className="list">
        {items.map((item, index) => (
          <MotionListItem key={item.id} index={index} className="list-item file-list-row">
            {editingId === item.id ? (
              <div className="workshop-thumb-placeholder content-thumb-empty" aria-hidden>
                Edit
              </div>
            ) : (
              <ContentThumbCell imageUrl={item.image_url} />
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
                    <label>Category</label>
                    <input
                      value={draft.category}
                      onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label>Date</label>
                    <input
                      value={draft.event_date}
                      onChange={(e) => setDraft((d) => ({ ...d, event_date: e.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label>Time</label>
                    <input
                      value={draft.time}
                      onChange={(e) => setDraft((d) => ({ ...d, time: e.target.value }))}
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
                  <div className="workshop-line-title">{item.title}</div>
                  <div className="workshop-line-meta platform-event-inline-meta">
                    <span className={`platform-event-inline-status${isEventUpcoming(item.event_date) ? " is-upcoming" : " is-past"}`}>
                      {isEventUpcoming(item.event_date) ? "Upcoming" : "Past"}
                    </span>
                    <span className="platform-event-inline-sep" aria-hidden>
                      ·
                    </span>
                    <span>{formatEventCategory(item.category)}</span>
                  </div>
                  <div className="workshop-line-meta">{formatEventDateTimeLine(item.event_date, item.time)}</div>
                  {item.location?.trim() ? <div className="workshop-line-meta">{item.location.trim()}</div> : null}
                  {item.description ? (
                    <div className="workshop-line-meta" style={{ maxHeight: 72, overflow: "hidden" }}>
                      {item.description}
                    </div>
                  ) : null}
                </>
              )}
              <div className="workshop-line-meta">Created {formatDate(item.created_at)}</div>
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
        ))}
      </div>
    </motion.div>
  );
}

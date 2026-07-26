"use client";

import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { formatEventDateAbbreviated, toEventDateInputValue } from "@/lib/event-format";
import { insertAuditLog } from "@/lib/audit-log";
import { useStaffAccess } from "@/components/staff-access-context";

type EventRow = {
  id: string;
  user_id: string;
  title: string;
  category: string;
  description: string | null;
  event_date: string;
  time: string;
  location: string;
  max_attendees: number | null;
  current_attendees: number | null;
  virtual_meeting_url: string | null;
  link_url: string | null;
  registration_open: boolean | null;
  latitude: number | null;
  longitude: number | null;
  created_at: string;
};

type RegRow = {
  id: string;
  user_id: string;
  attendance_status: string | null;
  registration_slot_status: string | null;
  waitlist_position: number | null;
};

const attendanceOptions = ["registered", "attended", "no_show", "cancelled"];
const slotOptions = ["confirmed", "waitlist", "cancelled"];

export default function AdminAllEventsPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<EventRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [regsByEvent, setRegsByEvent] = useState<Record<string, RegRow[]>>({});
  const [profiles, setProfiles] = useState<Record<string, { full_name: string | null; username: string | null }>>(
    {},
  );
  const [draft, setDraft] = useState<Partial<EventRow>>({});

  const load = useCallback(async () => {
    const { data, error: qErr } = await supabase
      .from("events")
      .select(
        "id, user_id, title, category, description, event_date, time, location, max_attendees, current_attendees, virtual_meeting_url, link_url, registration_open, latitude, longitude, created_at",
      )
      .order("event_date", { ascending: false })
      .limit(200);
    if (qErr) setError(qErr.message);
    else setRows((data as EventRow[]) || []);
  }, []);

  const loadRegs = useCallback(async (eventId: string, cancelled: () => boolean) => {
    const { data, error: qErr } = await supabase
      .from("event_registrations")
      .select("id, user_id, attendance_status, registration_slot_status, waitlist_position")
      .eq("event_id", eventId);
    if (cancelled()) return;
    if (qErr) {
      setError(qErr.message);
      return;
    }
    const list = (data as RegRow[]) || [];
    setRegsByEvent((prev) => ({ ...prev, [eventId]: list }));
    const ids = [...new Set(list.map((r) => r.user_id))];
    if (ids.length === 0) return;
    const { data: profs } = await supabase
      .from("user_profiles")
      .select("id, full_name, username")
      .in("id", ids);
    if (cancelled()) return;
    const map: Record<string, { full_name: string | null; username: string | null }> = {};
    for (const p of (profs as { id: string; full_name: string | null; username: string | null }[]) || []) {
      map[p.id] = { full_name: p.full_name, username: p.username };
    }
    setProfiles((prev) => ({ ...prev, ...map }));
  }, []);

  useEffect(() => {
    if (!accessReady || !access) return;
    void load();
  }, [accessReady, access, load]);

  useEffect(() => {
    if (!expandedId) return;
    let cancelled = false;
    const t = setTimeout(() => {
      void loadRegs(expandedId, () => cancelled);
    }, 0);
    return () => {
      cancelled = true;
      clearTimeout(t);
    };
  }, [expandedId, loadRegs]);

  if (!accessReady) return <div className="content-card">Loading…</div>;

  const saveEvent = async (row: EventRow) => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const merged: Record<string, unknown> = {
      title: draft.title ?? row.title,
      category: draft.category ?? row.category,
      description: draft.description ?? row.description,
      event_date: toEventDateInputValue((draft.event_date ?? row.event_date) as string),
      time: draft.time ?? row.time,
      location: draft.location ?? row.location,
      max_attendees: draft.max_attendees ?? row.max_attendees,
      virtual_meeting_url: draft.virtual_meeting_url ?? row.virtual_meeting_url,
      link_url: draft.link_url ?? row.link_url,
      registration_open: draft.registration_open ?? row.registration_open,
      latitude: draft.latitude ?? row.latitude,
      longitude: draft.longitude ?? row.longitude,
      updated_at: new Date().toISOString(),
    };
    const { error: uErr } = await supabase.from("events").update(merged).eq("id", row.id);
    if (uErr) {
      setError(uErr.message);
      return;
    }
    if (user) {
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "event_admin_update",
        entityType: "events",
        entityId: row.id,
        metadata: draft,
      });
    }
    const updated: EventRow = {
      ...row,
      title: merged.title as string,
      category: merged.category as string,
      description: (merged.description as string | null) ?? null,
      event_date: merged.event_date as string,
      time: merged.time as string,
      location: merged.location as string,
      max_attendees: (merged.max_attendees as number | null) ?? null,
      current_attendees: row.current_attendees,
      virtual_meeting_url: (merged.virtual_meeting_url as string | null) ?? null,
      link_url: (merged.link_url as string | null) ?? null,
      registration_open: (merged.registration_open as boolean | null) ?? null,
      latitude: (merged.latitude as number | null) ?? null,
      longitude: (merged.longitude as number | null) ?? null,
      created_at: row.created_at,
      user_id: row.user_id,
      id: row.id,
    };
    setRows((prev) => prev.map((r) => (r.id === row.id ? updated : r)));
    setDraft({});
    setExpandedId(null);
  };

  const updateReg = async (eventId: string, reg: RegRow, patch: Partial<RegRow>) => {
    setError(null);
    const { error: uErr } = await supabase
      .from("event_registrations")
      .update({
        attendance_status: patch.attendance_status ?? reg.attendance_status,
        registration_slot_status: patch.registration_slot_status ?? reg.registration_slot_status,
        waitlist_position: patch.waitlist_position !== undefined ? patch.waitlist_position : reg.waitlist_position,
      })
      .eq("id", reg.id);
    if (uErr) {
      setError(uErr.message);
      return;
    }
    setRegsByEvent((prev) => ({
      ...prev,
      [eventId]: (prev[eventId] || []).map((x) => (x.id === reg.id ? { ...x, ...patch } : x)),
    }));
  };

  const exportRegsCsv = (eventId: string) => {
    const list = regsByEvent[eventId] || [];
    const header = ["user_id", "full_name", "username", "attendance_status", "registration_slot_status", "waitlist"];
    const lines = [header.join(",")];
    for (const r of list) {
      const p = profiles[r.user_id];
      lines.push(
        [
          r.user_id,
          JSON.stringify(p?.full_name ?? ""),
          JSON.stringify(p?.username ?? ""),
          r.attendance_status ?? "",
          r.registration_slot_status ?? "",
          r.waitlist_position ?? "",
        ].join(","),
      );
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `event_${eventId}_registrations.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const cancelEventNotify = async (row: EventRow) => {
    if (!confirm(`Mark event cancelled and close registration for "${row.title}"?`)) return;
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("events")
      .update({
        registration_open: false,
        updated_at: new Date().toISOString(),
      })
      .eq("id", row.id);
    if (uErr) {
      setError(uErr.message);
      return;
    }
    if (user) {
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "event_cancelled_staff",
        entityType: "events",
        entityId: row.id,
        metadata: { title: row.title },
      });
    }
    setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, registration_open: false } : r)));
  };

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <h2 style={{ fontSize: 20, margin: 0 }}>All events (staff)</h2>
        <button type="button" className="btn btn-secondary" onClick={() => void load()}>
          Refresh
        </button>
      </div>
      <p className="subtle">
        Edit schedules, capacity, virtual links, and registration. Attendee lists and status updates are saved with each
        event. Automated confirmation emails are not wired up here yet.
      </p>
      {error ? <p className="error">{error}</p> : null}
      <div className="list">
        {rows.map((r) => (
          <div key={r.id} className="list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8, flexWrap: "wrap" }}>
              <div>
                <div style={{ fontWeight: 600 }}>{r.title}</div>
                <div className="subtle">
                  {formatEventDateAbbreviated(r.event_date)} · {r.time} · {r.category}
                </div>
                <div className="subtle">{r.location}</div>
                <div className="subtle">
                  Organizer {r.user_id} · cap {r.max_attendees ?? "—"} · attending {r.current_attendees ?? "—"} ·
                  registration {r.registration_open === false ? "closed" : "open"}
                </div>
              </div>
              <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => {
                    setExpandedId((id) => (id === r.id ? null : r.id));
                    setDraft({ ...r });
                  }}
                >
                  {expandedId === r.id ? "Close editor" : "Edit / attendees"}
                </button>
                <button type="button" className="btn btn-secondary" onClick={() => void cancelEventNotify(r)}>
                  Close registration
                </button>
              </div>
            </div>
            {expandedId === r.id ? (
              <div className="stack" style={{ gap: 10, borderTop: "1px solid var(--border)", paddingTop: 10 }}>
                <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 10 }}>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Title
                    <input
                      className="input"
                      value={draft.title ?? r.title}
                      onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Category
                    <input
                      className="input"
                      value={draft.category ?? r.category}
                      onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Date
                    <input
                      className="input"
                      type="date"
                      value={toEventDateInputValue(draft.event_date ?? r.event_date)}
                      onChange={(e) => setDraft((d) => ({ ...d, event_date: e.target.value }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Time
                    <input
                      className="input"
                      value={draft.time ?? r.time}
                      onChange={(e) => setDraft((d) => ({ ...d, time: e.target.value }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Max attendees
                    <input
                      className="input"
                      type="number"
                      value={draft.max_attendees ?? r.max_attendees ?? ""}
                      onChange={(e) =>
                        setDraft((d) => ({
                          ...d,
                          max_attendees: e.target.value === "" ? null : Number(e.target.value),
                        }))
                      }
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Virtual URL
                    <input
                      className="input"
                      value={draft.virtual_meeting_url ?? r.virtual_meeting_url ?? ""}
                      onChange={(e) => setDraft((d) => ({ ...d, virtual_meeting_url: e.target.value || null }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Event link
                    <input
                      className="input"
                      type="url"
                      placeholder="https://… registration or more info"
                      value={draft.link_url ?? r.link_url ?? ""}
                      onChange={(e) => setDraft((d) => ({ ...d, link_url: e.target.value || null }))}
                    />
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Lat / Long
                    <div style={{ display: "flex", gap: 6 }}>
                      <input
                        className="input"
                        placeholder="lat"
                        value={draft.latitude ?? r.latitude ?? ""}
                        onChange={(e) =>
                          setDraft((d) => ({
                            ...d,
                            latitude: e.target.value === "" ? null : Number(e.target.value),
                          }))
                        }
                      />
                      <input
                        className="input"
                        placeholder="lng"
                        value={draft.longitude ?? r.longitude ?? ""}
                        onChange={(e) =>
                          setDraft((d) => ({
                            ...d,
                            longitude: e.target.value === "" ? null : Number(e.target.value),
                          }))
                        }
                      />
                    </div>
                  </label>
                  <label className="subtle stack" style={{ gap: 4 }}>
                    Registration open
                    <select
                      className="input"
                      value={String(draft.registration_open ?? r.registration_open ?? true)}
                      onChange={(e) => setDraft((d) => ({ ...d, registration_open: e.target.value === "true" }))}
                    >
                      <option value="true">open</option>
                      <option value="false">closed</option>
                    </select>
                  </label>
                </div>
                <label className="subtle stack" style={{ gap: 4 }}>
                  Location
                  <input
                    className="input"
                    value={draft.location ?? r.location}
                    onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))}
                  />
                </label>
                <label className="subtle stack" style={{ gap: 4 }}>
                  Description
                  <textarea
                    className="input"
                    rows={3}
                    value={draft.description ?? r.description ?? ""}
                    onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value || null }))}
                  />
                </label>
                <button type="button" className="btn" onClick={() => void saveEvent(r)}>
                  Save event
                </button>

                <div style={{ fontWeight: 600 }}>Registrations</div>
                <button type="button" className="btn btn-secondary" onClick={() => exportRegsCsv(r.id)}>
                  Export attendees CSV
                </button>
                <div className="list">
                  {(regsByEvent[r.id] || []).map((reg) => (
                    <div key={reg.id} className="list-item">
                      <div className="stack" style={{ gap: 4 }}>
                        <div className="subtle">{reg.user_id}</div>
                        <div>
                          {profiles[reg.user_id]?.full_name || profiles[reg.user_id]?.username || "—"}
                        </div>
                      </div>
                      <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                        <select
                          className="input"
                          value={reg.attendance_status || "registered"}
                          onChange={(e) => void updateReg(r.id, reg, { attendance_status: e.target.value })}
                        >
                          {attendanceOptions.map((o) => (
                            <option key={o} value={o}>
                              {o}
                            </option>
                          ))}
                        </select>
                        <select
                          className="input"
                          value={reg.registration_slot_status || "confirmed"}
                          onChange={(e) => void updateReg(r.id, reg, { registration_slot_status: e.target.value })}
                        >
                          {slotOptions.map((o) => (
                            <option key={o} value={o}>
                              {o}
                            </option>
                          ))}
                        </select>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}

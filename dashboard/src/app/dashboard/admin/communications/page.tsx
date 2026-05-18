"use client";

import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { insertAuditLog } from "@/lib/audit-log";
import { useStaffAccess } from "@/components/staff-access-context";
import { isAdminOrSuperEffective } from "@/lib/staff-profile";

type Campaign = {
  id: string;
  title: string;
  body: string;
  channel: string;
  segment: Record<string, unknown> | null;
  scheduled_for: string | null;
  status: string;
  created_at: string;
};

const channels = ["email", "sms", "push", "in_app"] as const;
const statuses = ["draft", "scheduled", "sending", "sent", "failed", "cancelled"] as const;

export default function AdminCommunicationsPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<Campaign[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Campaign | null>(null);
  const [segmentJson, setSegmentJson] = useState("{}");

  const load = useCallback(async () => {
    const { data, error: qErr } = await supabase
      .from("broadcast_campaigns")
      .select("id, title, body, channel, segment, scheduled_for, status, created_at")
      .order("created_at", { ascending: false })
      .limit(100);
    if (qErr) setError(qErr.message);
    else setRows((data as Campaign[]) || []);
  }, []);

  useEffect(() => {
    if (!accessReady || !access || !isAdminOrSuperEffective(access)) return;
    void load();
  }, [accessReady, access, load]);

  const startNew = () => {
    setEditing({
      id: "",
      title: "",
      body: "",
      channel: "email",
      segment: {},
      scheduled_for: null,
      status: "draft",
      created_at: "",
    });
    setSegmentJson("{}");
  };

  const startEdit = (c: Campaign) => {
    setEditing(c);
    setSegmentJson(JSON.stringify(c.segment ?? {}, null, 2));
  };

  const save = async () => {
    if (!editing) return;
    setError(null);
    let segment: Record<string, unknown> = {};
    try {
      segment = JSON.parse(segmentJson) as Record<string, unknown>;
    } catch {
      setError("Segment must be valid JSON (filters, regions, tiers, etc.).");
      return;
    }
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;

    if (editing.id) {
      const { error: uErr } = await supabase
        .from("broadcast_campaigns")
        .update({
          title: editing.title,
          body: editing.body,
          channel: editing.channel,
          segment,
          scheduled_for: editing.scheduled_for,
          status: editing.status,
          updated_at: new Date().toISOString(),
        })
        .eq("id", editing.id);
      if (uErr) {
        setError(uErr.message);
        return;
      }
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "broadcast_campaign_update",
        entityType: "broadcast_campaigns",
        entityId: editing.id,
        metadata: { status: editing.status },
      });
    } else {
      const { data, error: iErr } = await supabase
        .from("broadcast_campaigns")
        .insert({
          title: editing.title,
          body: editing.body,
          channel: editing.channel,
          segment,
          scheduled_for: editing.scheduled_for,
          status: editing.status,
          created_by: user.id,
        })
        .select("id, title, body, channel, segment, scheduled_for, status, created_at")
        .single();
      if (iErr) {
        setError(iErr.message);
        return;
      }
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "broadcast_campaign_create",
        entityType: "broadcast_campaigns",
        entityId: (data as Campaign).id,
        metadata: {},
      });
    }
    setEditing(null);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm("Delete this campaign draft?")) return;
    setError(null);
    const { error: dErr } = await supabase.from("broadcast_campaigns").delete().eq("id", id);
    if (dErr) setError(dErr.message);
    else await load();
  };

  const logDeliverySample = async (campaignId: string) => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error: e } = await supabase.from("broadcast_delivery_events").insert({
      campaign_id: campaignId,
      recipient_id: user.id,
      status: "simulated",
      detail: { note: "Simulated send — no message was delivered." },
    });
    if (e) setError(e.message);
  };

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!isAdminOrSuperEffective(access)) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>Broadcasts</h2>
        <p className="error">Program admins handle broadcasts.</p>
      </div>
    );
  }

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <h2 style={{ fontSize: 20, margin: 0 }}>Broadcasts</h2>
        <div style={{ display: "flex", gap: 8 }}>
          <button type="button" className="btn btn-secondary" onClick={() => void load()}>
            Refresh
          </button>
          <button type="button" className="btn" onClick={startNew}>
            New draft
          </button>
        </div>
      </div>
      <p className="subtle">
        Draft campaigns and optional audience filters (stored as JSON, for example regions or cohort tags). Sending and
        analytics still need to be connected to your messaging provider outside this screen.
      </p>
      {error ? <p className="error">{error}</p> : null}

      {editing ? (
        <div className="stack" style={{ gap: 10, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
          <div className="field">
            <label>Title</label>
            <input className="input" value={editing.title} onChange={(e) => setEditing({ ...editing, title: e.target.value })} />
          </div>
          <div className="field">
            <label>Body</label>
            <textarea className="input" rows={4} value={editing.body} onChange={(e) => setEditing({ ...editing, body: e.target.value })} />
          </div>
          <div className="field">
            <label>Channel</label>
            <select
              className="input"
              value={editing.channel}
              onChange={(e) => setEditing({ ...editing, channel: e.target.value })}
            >
              {channels.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Status</label>
            <select
              className="input"
              value={editing.status}
              onChange={(e) => setEditing({ ...editing, status: e.target.value })}
            >
              {statuses.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Scheduled for (ISO or empty)</label>
            <input
              className="input"
              value={editing.scheduled_for ?? ""}
              onChange={(e) => setEditing({ ...editing, scheduled_for: e.target.value || null })}
            />
          </div>
          <div className="field">
            <label>Segment JSON</label>
            <textarea className="input" rows={3} value={segmentJson} onChange={(e) => setSegmentJson(e.target.value)} />
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button type="button" className="btn" onClick={() => void save()}>
              Save
            </button>
            <button type="button" className="btn btn-secondary" onClick={() => setEditing(null)}>
              Cancel
            </button>
          </div>
        </div>
      ) : null}

      <div className="list">
        {rows.map((c) => (
          <div key={c.id} className="list-item">
            <div className="stack" style={{ gap: 4 }}>
              <div style={{ fontWeight: 600 }}>{c.title}</div>
              <div className="subtle">
                {c.channel} · {c.status} · {formatDateSafe(c.created_at)}
              </div>
            </div>
            <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <button type="button" className="btn btn-secondary" onClick={() => startEdit(c)}>
                Edit
              </button>
              <button type="button" className="btn btn-secondary" onClick={() => void logDeliverySample(c.id)}>
                Log sample delivery row
              </button>
              <button type="button" className="btn btn-danger" onClick={() => void remove(c.id)}>
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function formatDateSafe(iso: string) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

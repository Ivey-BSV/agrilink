"use client";

import { motion } from "framer-motion";
import { PageSectionHeader } from "@/components/page-section-header";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";

type Row = {
  id: string;
  type: string;
  title: string;
  body: string | null;
  read_at: string | null;
  created_at: string;
};

export default function NotificationsPage() {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error: e } = await supabase
      .from("user_notifications")
      .select("id, type, title, body, read_at, created_at")
      .order("created_at", { ascending: false })
      .limit(100);
    if (e) setError(e.message);
    else setRows((data as Row[]) ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const markRead = async (id: string) => {
    const { error: e } = await supabase
      .from("user_notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("id", id);
    if (e) setError(e.message);
    else void load();
  };

  const markAllRead = async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error: e } = await supabase
      .from("user_notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .is("read_at", null);
    if (e) setError(e.message);
    else void load();
  };

  const unread = rows.filter((r) => !r.read_at).length;

  return (
    <motion.div className="content-card stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <PageSectionHeader
        title="Notifications"
        description="Alerts when something important happens on your account—new activity on posts, projects, polls, and more. Mark items read to keep the list manageable."
        action={
          unread > 0 ? (
            <button type="button" className="btn btn-secondary" onClick={() => void markAllRead()}>
              Mark all read
            </button>
          ) : null
        }
      />
      {loading ? <p className="subtle">Loading…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && rows.length === 0 ? <p className="empty">No notifications yet.</p> : null}
      <ul className="list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {rows.map((r) => (
          <li
            key={r.id}
            className="list-item"
            style={{
              opacity: r.read_at ? 0.85 : 1,
              borderLeft: r.read_at ? undefined : "3px solid var(--primary-green, #2d6a4f)",
              paddingLeft: r.read_at ? undefined : 10,
            }}
          >
            <button
              type="button"
              onClick={() => void markRead(r.id)}
              style={{
                all: "unset",
                cursor: "pointer",
                display: "block",
                width: "100%",
                textAlign: "left",
              }}
            >
              <div style={{ fontWeight: r.read_at ? 500 : 700 }}>{r.title}</div>
              {r.body ? <div className="subtle" style={{ marginTop: 4, fontSize: "0.92rem" }}>{r.body}</div> : null}
              <div className="subtle" style={{ marginTop: 6, fontSize: "0.82rem" }}>
                {formatDate(r.created_at)} · {r.type}
                {!r.read_at ? <span> · Click to mark read</span> : null}
              </div>
            </button>
          </li>
        ))}
      </ul>
    </motion.div>
  );
}

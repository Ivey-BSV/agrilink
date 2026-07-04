"use client";

import { PageSectionHeader } from "@/components/page-section-header";
import { PlatformPageShell } from "@/components/platform-section";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";

type Row = {
  id: string;
  type: string;
  title: string;
  body: string | null;
  read_at: string | null;
  created_at: string;
  data?: Record<string, unknown> | null;
};

const RESOURCE_TYPES = new Set([
  "repository_item_new",
  "repository_folder_new",
  "workshop_item_new",
  "workshop_folder_new",
]);

function resourceHref(type: string, data: Record<string, unknown> | null | undefined): string | null {
  if (!data) return null;
  const folderId = typeof data.folder_id === "string" ? data.folder_id : null;
  const q = folderId ? `?folder=${encodeURIComponent(folderId)}` : "";
  if (type.startsWith("repository_")) return `/dashboard/repository${q}`;
  if (type.startsWith("workshop_")) return `/dashboard/workshops${q}`;
  return null;
}

export default function NotificationsPage() {
  const router = useRouter();
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error: e } = await supabase
      .from("user_notifications")
      .select("id, type, title, body, read_at, created_at, data")
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
    else {
      setRows((prev) =>
        prev.map((r) =>
          r.id === id ? { ...r, read_at: new Date().toISOString() } : r
        )
      );
    }
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

  const openRow = async (row: Row) => {
    if (!row.read_at) await markRead(row.id);
    const href = resourceHref(row.type, row.data ?? null);
    if (href) router.push(href);
  };

  const unread = rows.filter((r) => !r.read_at).length;

  return (
    <PlatformPageShell>
      <PageSectionHeader
        title="Notifications"
        description="Alerts when something important happens on your account—new activity on posts, projects, polls, repository and workshop files, and more."
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
      <ul className="platform-list-rows">
        {rows.map((r) => {
          const href = resourceHref(r.type, r.data ?? null);
          const clickable = !!href;
          return (
            <li
              key={r.id}
              className={`platform-list-row${r.read_at ? " platform-list-row--read" : " platform-list-row--unread"}`}
            >
              <button
                type="button"
                onClick={() => (clickable ? void openRow(r) : void markRead(r.id))}
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
                <div className="platform-meta-row subtle" style={{ marginTop: 6, fontSize: "0.82rem" }}>
                  <span>{formatDate(r.created_at)}</span>
                  {RESOURCE_TYPES.has(r.type) ? <span>Open folder</span> : null}
                  {!r.read_at && !clickable ? <span>Click to mark read</span> : null}
                </div>
              </button>
            </li>
          );
        })}
      </ul>
    </PlatformPageShell>
  );
}

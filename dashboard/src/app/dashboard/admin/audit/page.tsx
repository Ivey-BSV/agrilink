"use client";

import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";

type AuditRow = {
  id: string;
  actor_id: string | null;
  action: string;
  entity_type: string;
  entity_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
};

export default function AdminAuditPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data, error: qErr } = await supabase
      .from("audit_logs")
      .select("id, actor_id, action, entity_type, entity_id, metadata, created_at")
      .order("created_at", { ascending: false })
      .limit(200);
    if (qErr) setError(qErr.message);
    else setRows((data as AuditRow[]) || []);
  }, []);

  useEffect(() => {
    if (!accessReady || !access || !isSuperEffective(access)) return;
    void load();
  }, [accessReady, access, load]);

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!isSuperEffective(access)) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>Audit log</h2>
        <p className="error">Only super admins can read the audit log.</p>
      </div>
    );
  }

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <h2 style={{ fontSize: 20, margin: 0 }}>Audit log</h2>
        <button type="button" className="btn btn-secondary" onClick={() => void load()}>
          Refresh
        </button>
      </div>
      {error ? <p className="error">{error}</p> : null}
      <div className="list">
        {rows.map((r) => (
          <div key={r.id} className="list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: 6 }}>
            <div style={{ fontWeight: 600 }}>{r.action}</div>
            <div className="subtle">
              {r.entity_type} {r.entity_id ? `· ${r.entity_id}` : ""}
            </div>
            <div className="subtle">Actor {r.actor_id || "—"}</div>
            <div className="subtle">{new Date(r.created_at).toLocaleString()}</div>
            {r.metadata && Object.keys(r.metadata).length > 0 ? (
              <pre className="subtle" style={{ fontSize: 11, overflow: "auto", margin: 0 }}>
                {JSON.stringify(r.metadata, null, 2)}
              </pre>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}

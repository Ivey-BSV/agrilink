"use client";

import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { insertAuditLog } from "@/lib/audit-log";
import { useStaffAccess } from "@/components/staff-access-context";
import { fetchUploaderLabelByUserIds } from "@/lib/document-owner-profiles";

type DocKind = "repository" | "workshop";

type QueueRow = {
  kind: DocKind;
  id: string;
  title: string;
  file_name: string;
  user_id: string;
  approval_status: string | null;
  created_at: string;
};

export default function AdminDocumentsQueuePage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<QueueRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [ownerLabels, setOwnerLabels] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    const [repo, ws] = await Promise.all([
      supabase
        .from("knowledge_repository_documents")
        .select("id, title, file_name, user_id, approval_status, created_at")
        .eq("approval_status", "pending")
        .order("created_at", { ascending: false })
        .limit(80),
      supabase
        .from("workshop_documents")
        .select("id, title, file_name, user_id, approval_status, created_at")
        .eq("approval_status", "pending")
        .order("created_at", { ascending: false })
        .limit(80),
    ]);
    if (repo.error || ws.error) {
      setError(repo.error?.message || ws.error?.message || "Load failed");
      return;
    }
    const merged: QueueRow[] = [
      ...((repo.data || []) as Omit<QueueRow, "kind">[]).map((r) => ({ ...r, kind: "repository" as const })),
      ...((ws.data || []) as Omit<QueueRow, "kind">[]).map((r) => ({ ...r, kind: "workshop" as const })),
    ].sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
    setRows(merged);
    if (merged.length > 0) {
      const labels = await fetchUploaderLabelByUserIds(
        supabase,
        merged.map((r) => r.user_id)
      );
      setOwnerLabels((prev) => ({ ...prev, ...labels }));
    }
  }, []);

  useEffect(() => {
    if (!accessReady || !access) return;
    void load();
  }, [accessReady, access, load]);

  const setDecision = async (row: QueueRow, status: "approved" | "rejected") => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;

    const table =
      row.kind === "repository" ? "knowledge_repository_documents" : "workshop_documents";
    const { error: uErr } = await supabase
      .from(table)
      .update({
        approval_status: status,
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq("id", row.id);

    if (uErr) {
      setError(uErr.message);
      return;
    }

    await insertAuditLog(supabase, {
      actorId: user.id,
      action: `document_${status}`,
      entityType: table,
      entityId: row.id,
    });

    setRows((prev) => prev.filter((r) => r.id !== row.id));
  };

  if (!accessReady) return <div className="content-card">Loading…</div>;

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <h2 style={{ fontSize: 20, margin: 0 }}>Upload approvals</h2>
        <button type="button" className="btn btn-secondary" onClick={() => void load()}>
          Refresh
        </button>
      </div>
      <p className="subtle">
        Knowledge base and workshop files that are still waiting for a decision.
      </p>
      {error ? <p className="error">{error}</p> : null}
      {rows.length === 0 ? <p className="subtle">No pending documents.</p> : null}
      <div className="list">
        {rows.map((r) => (
          <div key={`${r.kind}-${r.id}`} className="list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8, flexWrap: "wrap" }}>
              <div>
                <span className="pill">{r.kind}</span>{" "}
                <strong>{r.title}</strong>
                <div className="subtle">{r.file_name}</div>
                <div className="subtle">Owner {ownerLabels[r.user_id] ?? "…"}</div>
              </div>
              <div className="actions" style={{ display: "flex", gap: 8 }}>
                <button type="button" className="btn" onClick={() => void setDecision(r, "approved")}>
                  Approve
                </button>
                <button type="button" className="btn btn-secondary" onClick={() => void setDecision(r, "rejected")}>
                  Reject
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

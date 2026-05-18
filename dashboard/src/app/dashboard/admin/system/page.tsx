"use client";

import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { runAdminOperation } from "@/lib/admin-operations";
import { insertAuditLog } from "@/lib/audit-log";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";

type SettingRow = {
  key: string;
  value: Record<string, unknown>;
  updated_at: string;
};

export default function AdminSystemPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [settings, setSettings] = useState<SettingRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [newKey, setNewKey] = useState("");
  const [editKey, setEditKey] = useState<string | null>(null);
  const [editJson, setEditJson] = useState("{}");

  const loadSettings = useCallback(async () => {
    const { data, error: qErr } = await supabase.from("app_settings").select("key, value, updated_at").order("key");
    if (qErr) setError(qErr.message);
    else setSettings((data as SettingRow[]) || []);
  }, []);

  useEffect(() => {
    if (!accessReady || !access || !isSuperEffective(access)) return;
    void loadSettings();
  }, [accessReady, access, loadSettings]);

  const saveSetting = async (key: string, raw: string) => {
    setError(null);
    let value: Record<string, unknown>;
    try {
      value = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      setError("Value must be valid JSON.");
      return;
    }
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error: uErr } = await supabase.from("app_settings").upsert(
      {
        key,
        value,
        updated_by: user.id,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "key" },
    );
    if (uErr) {
      setError(uErr.message);
      return;
    }
    await insertAuditLog(supabase, {
      actorId: user.id,
      action: "app_settings_upsert",
      entityType: "app_settings",
      entityId: key,
      metadata: {},
    });
    setEditKey(null);
    await loadSettings();
  };

  const fullExport = async () => {
    setError(null);
    setInfo(null);
    try {
      const res = await runAdminOperation<{ data: Record<string, unknown[]>; errors: Record<string, string> }>({
        action: "multi_table_export",
        limit: 3000,
      });
      const blob = new Blob([JSON.stringify(res, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `full_export_${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      setInfo("Export downloaded (service-role snapshot).");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!isSuperEffective(access)) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>System & export</h2>
        <p className="error">Reserved for super admins.</p>
      </div>
    );
  }

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <h2 style={{ fontSize: 20 }}>System configuration & export</h2>
      <p className="subtle">
        Program-wide settings are stored as JSON. Prefer keeping API keys in your hosting provider&apos;s secret store,
        not in plain text here. The full database export runs through the same secure admin service as other sensitive
        actions.
      </p>
      {error ? <p className="error">{error}</p> : null}
      {info ? <p className="success">{info}</p> : null}

      <button type="button" className="btn" onClick={() => void fullExport()}>
        Download multi-table JSON export
      </button>

      <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
        <div style={{ fontWeight: 600 }}>Add setting key</div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input className="input" placeholder="e.g. notification_templates" value={newKey} onChange={(e) => setNewKey(e.target.value)} />
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => {
              const k = newKey.trim();
              if (!k) return;
              setEditKey(k);
              setEditJson("{}");
              setNewKey("");
            }}
          >
            Start editing new key
          </button>
        </div>
      </div>

      <div className="list">
        {settings.map((s) => (
          <div key={s.key} className="list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: 8 }}>
            <div style={{ fontWeight: 600 }}>{s.key}</div>
            <div className="subtle">Updated {new Date(s.updated_at).toLocaleString()}</div>
            {editKey === s.key ? (
              <>
                <textarea className="input" rows={6} value={editJson} onChange={(e) => setEditJson(e.target.value)} />
                <div style={{ display: "flex", gap: 8 }}>
                  <button type="button" className="btn" onClick={() => void saveSetting(s.key, editJson)}>
                    Save
                  </button>
                  <button type="button" className="btn btn-secondary" onClick={() => setEditKey(null)}>
                    Cancel
                  </button>
                </div>
              </>
            ) : (
              <>
                <pre className="subtle" style={{ fontSize: 11, overflow: "auto" }}>
                  {JSON.stringify(s.value, null, 2)}
                </pre>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => {
                    setEditKey(s.key);
                    setEditJson(JSON.stringify(s.value ?? {}, null, 2));
                  }}
                >
                  Edit JSON
                </button>
              </>
            )}
          </div>
        ))}
      </div>

      {editKey && !settings.find((s) => s.key === editKey) ? (
        <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
          <div style={{ fontWeight: 600 }}>New key: {editKey}</div>
          <textarea className="input" rows={6} value={editJson} onChange={(e) => setEditJson(e.target.value)} />
          <button type="button" className="btn" onClick={() => void saveSetting(editKey, editJson)}>
            Save new setting
          </button>
        </div>
      ) : null}
    </div>
  );
}

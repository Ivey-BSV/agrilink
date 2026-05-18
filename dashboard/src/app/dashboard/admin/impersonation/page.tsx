"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";
import { getImpersonatedUserId, setImpersonatedUserId } from "@/lib/impersonation";

export default function AdminImpersonationPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [draft, setDraft] = useState("");
  const [current, setCurrent] = useState<string | null>(() =>
    typeof window === "undefined" ? null : getImpersonatedUserId(),
  );
  const [targetPreview, setTargetPreview] = useState<string | null>(null);

  useEffect(() => {
    const onChange = () => setCurrent(getImpersonatedUserId());
    window.addEventListener("agrilink_impersonation_changed", onChange);
    return () => window.removeEventListener("agrilink_impersonation_changed", onChange);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      const id = getImpersonatedUserId();
      if (!id) {
        if (!cancelled) setTargetPreview(null);
        return;
      }
      const { data } = await supabase
        .from("user_profiles")
        .select("full_name, username, access_tier, registration_status, account_kind, app_role")
        .eq("id", id)
        .maybeSingle();
      if (cancelled) return;
      if (!data) {
        setTargetPreview("Profile not found for this id.");
        return;
      }
      setTargetPreview(
        `${(data as { full_name?: string }).full_name || "—"} (@${(data as { username?: string }).username || "—"}) · access tier ${(data as { access_tier?: string }).access_tier || "—"} · registration ${(data as { registration_status?: string }).registration_status || "—"} · account ${(data as { account_kind?: string }).account_kind || "—"} · staff role ${(data as { app_role?: string }).app_role || "—"}`,
      );
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, [current]);

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!isSuperEffective(access)) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>Impersonation testing</h2>
        <p className="error">Super admin only.</p>
      </div>
    );
  }

  return (
    <div className="content-card stack" style={{ gap: 12 }}>
      <h2 style={{ fontSize: 20 }}>Impersonation testing (read)</h2>
      <p className="subtle">
        This is a lightweight preview: a target user id is saved in this browser only. It does not log you in as them
        or change your real session.
      </p>
      <p className="subtle">
        Current target: {current || "none"}
      </p>
      {targetPreview ? <p className="subtle">Preview: {targetPreview}</p> : null}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, alignItems: "center" }}>
        <input
          className="input"
          placeholder="Farmer user UUID"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          style={{ minWidth: 260, flex: 1 }}
        />
        <button type="button" className="btn" onClick={() => setImpersonatedUserId(draft.trim() || null)}>
          Save target
        </button>
        <button type="button" className="btn btn-secondary" onClick={() => setImpersonatedUserId(null)}>
          Clear
        </button>
      </div>
    </div>
  );
}

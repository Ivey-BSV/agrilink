"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { insertAuditLog } from "@/lib/audit-log";
import { runAdminOperation } from "@/lib/admin-operations";
import { resolveUserProfileId } from "@/lib/admin-resolve-user";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective, type AppRole } from "@/lib/staff-profile";

type StaffRow = {
  id: string;
  username: string | null;
  full_name: string | null;
  app_role: string | null;
  account_kind: string | null;
  created_at: string | null;
};

const roles: AppRole[] = ["moderator", "admin", "super_admin"];

type StaffSort = "created_desc" | "created_asc" | "name_asc" | "name_desc" | "role_asc";

export default function AdminStaffPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<StaffRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [promoteInput, setPromoteInput] = useState("");
  const [promoteRole, setPromoteRole] = useState<AppRole>("moderator");
  const [promoteBusy, setPromoteBusy] = useState(false);

  const [listSearch, setListSearch] = useState("");
  const [listSort, setListSort] = useState<StaffSort>("created_desc");

  const [createEmail, setCreateEmail] = useState("");
  const [createPassword, setCreatePassword] = useState("");
  const [createName, setCreateName] = useState("");
  const [createRole, setCreateRole] = useState<AppRole>("moderator");

  const [revokeInput, setRevokeInput] = useState("");
  const [pwdTargetInput, setPwdTargetInput] = useState("");
  const [pwdNew, setPwdNew] = useState("");
  const [deleteInput, setDeleteInput] = useState("");

  const load = useCallback(async () => {
    const { data, error: qErr } = await supabase
      .from("user_profiles")
      .select("id, username, full_name, app_role, account_kind, created_at")
      .eq("account_kind", "staff")
      .order("created_at", { ascending: false })
      .limit(200);
    if (qErr) setError(qErr.message);
    else setRows((data as StaffRow[]) || []);
  }, []);

  useEffect(() => {
    if (!accessReady || !access || !isSuperEffective(access)) return;
    void load();
  }, [accessReady, access, load]);

  const filteredSortedStaff = useMemo(() => {
    const q = listSearch.trim().toLowerCase();
    let list = rows;
    if (q) {
      list = rows.filter((r) => {
        const id = r.id.toLowerCase();
        const un = (r.username ?? "").toLowerCase();
        const fn = (r.full_name ?? "").toLowerCase();
        const role = (r.app_role ?? "").toLowerCase();
        return id.includes(q) || un.includes(q) || fn.includes(q) || role.includes(q);
      });
    }
    const nameKey = (r: StaffRow) => (r.full_name || r.username || "").toLowerCase();
    const sorted = [...list];
    switch (listSort) {
      case "created_asc":
        sorted.sort((a, b) => (a.created_at || "").localeCompare(b.created_at || ""));
        break;
      case "created_desc":
        sorted.sort((a, b) => (b.created_at || "").localeCompare(a.created_at || ""));
        break;
      case "name_asc":
        sorted.sort((a, b) => nameKey(a).localeCompare(nameKey(b)));
        break;
      case "name_desc":
        sorted.sort((a, b) => nameKey(b).localeCompare(nameKey(a)));
        break;
      case "role_asc":
        sorted.sort((a, b) => (a.app_role || "").localeCompare(b.app_role || ""));
        break;
      default:
        break;
    }
    return sorted;
  }, [rows, listSearch, listSort]);

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!isSuperEffective(access)) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>Staff</h2>
        <p className="error">Only super admins manage staff roles.</p>
      </div>
    );
  }

  const updateStaff = async (row: StaffRow, app_role: AppRole) => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("user_profiles")
      .update({ app_role, account_kind: "staff" })
      .eq("id", row.id);
    if (uErr) {
      setError(uErr.message);
      return;
    }
    if (user) {
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "staff_role_change",
        entityType: "user_profiles",
        entityId: row.id,
        metadata: { app_role },
      });
    }
    setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, app_role } : r)));
  };

  const promoteExistingUser = async () => {
    setError(null);
    setInfo(null);
    setPromoteBusy(true);
    const resolved = await resolveUserProfileId(supabase, promoteInput);
    if ("error" in resolved) {
      setError(resolved.error);
      setPromoteBusy(false);
      return;
    }
    const id = resolved.id;
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("user_profiles")
      .update({ app_role: promoteRole, account_kind: "staff" })
      .eq("id", id);
    if (uErr) {
      setError(uErr.message);
      setPromoteBusy(false);
      return;
    }
    if (user) {
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "staff_promote",
        entityType: "user_profiles",
        entityId: id,
        metadata: { app_role: promoteRole },
      });
    }
    setInfo("User promoted to staff with the selected role.");
    setPromoteInput("");
    setPromoteBusy(false);
    await load();
  };

  const createStaffAccount = async () => {
    setError(null);
    setInfo(null);
    try {
      await runAdminOperation({
        action: "create_staff",
        email: createEmail.trim(),
        password: createPassword,
        app_role: createRole,
        full_name: createName.trim() || undefined,
      });
      setInfo("Staff account created. They can sign in with the email and password you set.");
      setCreateEmail("");
      setCreatePassword("");
      setCreateName("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const revokeStaff = async () => {
    setError(null);
    setInfo(null);
    const resolved = await resolveUserProfileId(supabase, revokeInput);
    if ("error" in resolved) {
      setError(resolved.error);
      return;
    }
    try {
      await runAdminOperation({
        action: "revoke_staff_access",
        target_user_id: resolved.id,
      });
      setInfo("Staff access revoked (profile set to farmer / end_user). Auth user still exists.");
      setRevokeInput("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const resetPassword = async () => {
    setError(null);
    setInfo(null);
    const resolved = await resolveUserProfileId(supabase, pwdTargetInput);
    if ("error" in resolved) {
      setError(resolved.error);
      return;
    }
    try {
      await runAdminOperation({
        action: "update_user_password",
        target_user_id: resolved.id,
        new_password: pwdNew,
      });
      setInfo("Password updated.");
      setPwdNew("");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const deleteUserHard = async () => {
    const resolved = await resolveUserProfileId(supabase, deleteInput);
    if ("error" in resolved) {
      setError(resolved.error);
      return;
    }
    const id = resolved.id;
    if (!confirm(`Permanently delete this user and all related data? This cannot be undone.`)) return;
    setError(null);
    setInfo(null);
    try {
      await runAdminOperation({ action: "delete_auth_user", target_user_id: id });
      setInfo("User and related rows removed.");
      setDeleteInput("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  return (
    <div className="content-card stack" style={{ gap: 16 }}>
      <h2 style={{ fontSize: 20, margin: 0 }}>Staff</h2>
      <p className="subtle">
        Promote existing accounts to staff roles, then adjust roles in the list below. Creating accounts, resetting
        passwords, and permanently deleting users run through the secure admin service when it is enabled for your
        deployment.
      </p>
      {error ? <p className="error">{error}</p> : null}
      {info ? <p className="success">{info}</p> : null}

      <section className="admin-console-primary stack" style={{ gap: 12, padding: 16, border: "1px solid var(--border)", borderRadius: 12, background: "var(--bg-subtle)" }}>
        <div style={{ fontWeight: 700, fontSize: "1.05rem" }}>Promote to staff</div>
        <p className="subtle" style={{ margin: 0 }}>
          Enter the person&apos;s <strong>account ID</strong> (from their profile or your user directory) or their{" "}
          <strong>username</strong> (with or without @). They will be marked as staff and given the role you choose.
        </p>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10, alignItems: "flex-end" }}>
          <label className="stack" style={{ gap: 6, flex: "1 1 280px", minWidth: 0 }}>
            <span className="subtle" style={{ fontWeight: 600 }}>
              User id or username
            </span>
            <input
              className="input"
              placeholder="8f3b… or jane_farmer"
              value={promoteInput}
              onChange={(e) => setPromoteInput(e.target.value)}
              autoComplete="off"
            />
          </label>
          <label className="stack" style={{ gap: 6 }}>
            <span className="subtle" style={{ fontWeight: 600 }}>
              Role
            </span>
            <select className="input" value={promoteRole} onChange={(e) => setPromoteRole(e.target.value as AppRole)}>
              {roles.map((r) => (
                <option key={r} value={r}>
                  {r}
                </option>
              ))}
            </select>
          </label>
          <button type="button" className="btn" disabled={promoteBusy} onClick={() => void promoteExistingUser()}>
            {promoteBusy ? "Saving…" : "Promote"}
          </button>
        </div>
      </section>

      <section className="stack" style={{ gap: 10 }}>
        <div style={{ fontWeight: 700 }}>Current staff ({filteredSortedStaff.length})</div>
        <div className="admin-console-toolbar" style={{ display: "flex", flexWrap: "wrap", gap: 10, alignItems: "center" }}>
          <input
            className="input"
            placeholder="Search name, @username, id, or role…"
            value={listSearch}
            onChange={(e) => setListSearch(e.target.value)}
            style={{ flex: "1 1 220px", minWidth: 0 }}
            aria-label="Search staff list"
          />
          <label className="subtle" style={{ display: "flex", alignItems: "center", gap: 8 }}>
            Sort
            <select className="input" value={listSort} onChange={(e) => setListSort(e.target.value as StaffSort)}>
              <option value="created_desc">Newest first</option>
              <option value="created_asc">Oldest first</option>
              <option value="name_asc">Name A–Z</option>
              <option value="name_desc">Name Z–A</option>
              <option value="role_asc">Role A–Z</option>
            </select>
          </label>
          <button type="button" className="btn btn-secondary" onClick={() => void load()}>
            Refresh
          </button>
        </div>

        <div className="list">
          {filteredSortedStaff.length === 0 ? (
            <p className="subtle">No staff match your search.</p>
          ) : (
            filteredSortedStaff.map((r) => (
              <div key={r.id} className="list-item">
                <div className="stack" style={{ gap: 4 }}>
                  <div style={{ fontWeight: 600 }}>{r.full_name || "Unnamed"}</div>
                  <div className="subtle">@{r.username || "—"}</div>
                  <div className="subtle" style={{ fontSize: "0.8rem", wordBreak: "break-all" }}>
                    {r.id}
                  </div>
                </div>
                <div className="actions">
                  <select
                    className="input"
                    value={(r.app_role as AppRole) || "moderator"}
                    onChange={(e) => void updateStaff(r, e.target.value as AppRole)}
                    aria-label={`Role for ${r.username || r.id}`}
                  >
                    {roles.map((role) => (
                      <option key={role} value={role}>
                        {role}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      <details className="admin-console-secondary" style={{ border: "1px solid var(--border)", borderRadius: 10, padding: "8px 12px" }}>
        <summary style={{ cursor: "pointer", fontWeight: 600, padding: "6px 0" }}>Other staff tools</summary>
        <div className="stack" style={{ gap: 14, paddingTop: 12 }}>
          <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
            <div style={{ fontWeight: 600 }}>Create staff (Auth + profile)</div>
            <div className="field">
              <label>Email</label>
              <input className="input" value={createEmail} onChange={(e) => setCreateEmail(e.target.value)} />
            </div>
            <div className="field">
              <label>Initial password (min 8)</label>
              <input
                type="password"
                className="input"
                value={createPassword}
                onChange={(e) => setCreatePassword(e.target.value)}
              />
            </div>
            <div className="field">
              <label>Full name</label>
              <input className="input" value={createName} onChange={(e) => setCreateName(e.target.value)} />
            </div>
            <div className="field">
              <label>Role</label>
              <select className="input" value={createRole} onChange={(e) => setCreateRole(e.target.value as AppRole)}>
                {roles.map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </select>
            </div>
            <button type="button" className="btn btn-secondary" onClick={() => void createStaffAccount()}>
              Create staff account
            </button>
          </div>

          <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
            <div style={{ fontWeight: 600 }}>Revoke staff access (keeps Auth user)</div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              <input
                className="input"
                placeholder="User id or username"
                value={revokeInput}
                onChange={(e) => setRevokeInput(e.target.value)}
                style={{ minWidth: 260, flex: 1 }}
              />
              <button type="button" className="btn btn-secondary" onClick={() => void revokeStaff()}>
                Revoke
              </button>
            </div>
          </div>

          <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
            <div style={{ fontWeight: 600 }}>Reset user password</div>
            <input
              className="input"
              placeholder="User id or username"
              value={pwdTargetInput}
              onChange={(e) => setPwdTargetInput(e.target.value)}
            />
            <input
              type="password"
              className="input"
              placeholder="New password (min 8)"
              value={pwdNew}
              onChange={(e) => setPwdNew(e.target.value)}
            />
            <button type="button" className="btn btn-secondary" onClick={() => void resetPassword()}>
              Set password
            </button>
          </div>

          <div className="stack" style={{ gap: 8, padding: 12, border: "1px solid var(--border)", borderRadius: 10 }}>
            <div style={{ fontWeight: 600 }}>Delete user completely (purge + Auth)</div>
            <input
              className="input"
              placeholder="User id or username"
              value={deleteInput}
              onChange={(e) => setDeleteInput(e.target.value)}
            />
            <button type="button" className="btn btn-secondary" onClick={() => void deleteUserHard()}>
              Delete user
            </button>
          </div>
        </div>
      </details>
    </div>
  );
}

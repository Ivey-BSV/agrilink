"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { insertAuditLog } from "@/lib/audit-log";
import { useStaffAccess } from "@/components/staff-access-context";
import { isAdminOrSuperEffective } from "@/lib/staff-profile";

type FarmerRow = {
  id: string;
  username: string | null;
  full_name: string | null;
  bio: string | null;
  location: string | null;
  farm_type: string | null;
  experience_level: string | null;
  registration_status: string | null;
  access_tier: string | null;
  acreage: number | null;
  crop_types: string | null;
  practice_stage: string | null;
  created_at: string | null;
};

const registrationOptions = ["pending", "approved", "denied", "suspended", "archived", "active"];

type FarmerSort = "created_desc" | "created_asc" | "name_asc" | "name_desc" | "reg_asc" | "location_asc";

export default function AdminFarmersPage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [rows, setRows] = useState<FarmerRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const [listSearch, setListSearch] = useState("");
  const [listSort, setListSort] = useState<FarmerSort>("created_desc");

  const canWrite = isAdminOrSuperEffective(access);

  const load = useCallback(async () => {
    const { data, error: qErr } = await supabase
      .from("user_profiles")
      .select(
        "id, username, full_name, bio, location, farm_type, experience_level, registration_status, access_tier, account_kind, acreage, crop_types, practice_stage, created_at",
      )
      .eq("account_kind", "farmer")
      .order("created_at", { ascending: false })
      .limit(500);

    if (qErr) {
      setError(qErr.message);
      return;
    }
    setRows((data as FarmerRow[]) || []);
  }, []);

  const filteredSortedFarmers = useMemo(() => {
    const q = listSearch.trim().toLowerCase();
    let list = rows;
    if (q) {
      list = rows.filter((r) => {
        const hay = [
          r.id,
          r.username,
          r.full_name,
          r.location,
          r.farm_type,
          r.registration_status,
          r.access_tier,
          r.experience_level,
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        return hay.includes(q);
      });
    }
    const nameKey = (r: FarmerRow) => (r.full_name || r.username || "").toLowerCase();
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
      case "reg_asc":
        sorted.sort((a, b) =>
          (a.registration_status || "").localeCompare(b.registration_status || ""),
        );
        break;
      case "location_asc":
        sorted.sort((a, b) => (a.location || "").localeCompare(b.location || ""));
        break;
      default:
        break;
    }
    return sorted;
  }, [rows, listSearch, listSort]);

  useEffect(() => {
    if (!accessReady || !access || !canWrite) return;
    void load();
  }, [accessReady, access, canWrite, load]);

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!canWrite) {
    return (
      <div className="content-card stack">
        <h2 style={{ fontSize: 20 }}>Farmers</h2>
        <p className="error">Only program admins and super admins can change farmer records.</p>
      </div>
    );
  }

  const saveRow = async (row: FarmerRow, patch: Partial<FarmerRow>) => {
    setBusyId(row.id);
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("user_profiles")
      .update({
        registration_status: patch.registration_status ?? row.registration_status,
        access_tier: patch.access_tier !== undefined ? patch.access_tier : row.access_tier,
        full_name: patch.full_name !== undefined ? patch.full_name : row.full_name,
        bio: patch.bio !== undefined ? patch.bio : row.bio,
        location: patch.location !== undefined ? patch.location : row.location,
        farm_type: patch.farm_type !== undefined ? patch.farm_type : row.farm_type,
        experience_level: patch.experience_level !== undefined ? patch.experience_level : row.experience_level,
        acreage: patch.acreage !== undefined ? patch.acreage : row.acreage,
        crop_types: patch.crop_types !== undefined ? patch.crop_types : row.crop_types,
        practice_stage: patch.practice_stage !== undefined ? patch.practice_stage : row.practice_stage,
      })
      .eq("id", row.id);
    if (uErr) {
      setError(uErr.message);
      setBusyId(null);
      return;
    }
    if (user) {
      await insertAuditLog(supabase, {
        actorId: user.id,
        action: "farmer_profile_update",
        entityType: "user_profiles",
        entityId: row.id,
        metadata: patch,
      });
    }
    setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, ...patch } : r)));
    setBusyId(null);
  };


  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <h2 style={{ fontSize: 20, margin: 0 }}>Farmers</h2>
        <button type="button" className="btn btn-secondary" onClick={() => void load()}>
          Refresh
        </button>
      </div>
      <p className="subtle">
        Approve registrations, assign tiers, and edit farm profiles for existing accounts—including acreage, crop types,
        and practice stage when you collect that information.
      </p>
      {error ? <p className="error">{error}</p> : null}

      <div className="admin-console-toolbar stack" style={{ gap: 10 }}>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10, alignItems: "center" }}>
          <input
            className="input"
            placeholder="Search name, @username, id, location, farm type, status, tier…"
            value={listSearch}
            onChange={(e) => setListSearch(e.target.value)}
            style={{ flex: "1 1 240px", minWidth: 0 }}
            aria-label="Search farmers"
          />
          <label className="subtle" style={{ display: "flex", alignItems: "center", gap: 8 }}>
            Sort
            <select className="input" value={listSort} onChange={(e) => setListSort(e.target.value as FarmerSort)}>
              <option value="created_desc">Newest first</option>
              <option value="created_asc">Oldest first</option>
              <option value="name_asc">Name A–Z</option>
              <option value="name_desc">Name Z–A</option>
              <option value="reg_asc">Registration status A–Z</option>
              <option value="location_asc">Location A–Z</option>
            </select>
          </label>
        </div>
        <p className="subtle" style={{ margin: 0 }}>
          Showing {filteredSortedFarmers.length} of {rows.length} farmers
        </p>
      </div>

      <div className="list">
        {filteredSortedFarmers.map((r) => (
          <div key={r.id} className="list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: 10 }}>
            <div className="stack" style={{ gap: 4 }}>
              <div style={{ fontWeight: 600 }}>{r.full_name || "Unnamed"}</div>
              <div className="subtle">@{r.username || "—"}</div>
              <div className="subtle">{r.id}</div>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 10 }}>
              <label className="subtle stack" style={{ gap: 4 }}>
                Registration
                <select
                  className="input"
                  value={r.registration_status || "active"}
                  disabled={busyId === r.id}
                  onChange={(e) => void saveRow(r, { registration_status: e.target.value })}
                >
                  {registrationOptions.map((opt) => (
                    <option key={opt} value={opt}>
                      {opt}
                    </option>
                  ))}
                </select>
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Access tier
                <input
                  key={`tier-${r.id}-${r.access_tier ?? ""}`}
                  className="input"
                  defaultValue={r.access_tier || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.access_tier || "")) void saveRow(r, { access_tier: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Full name
                <input
                  key={`fn-${r.id}-${r.full_name ?? ""}`}
                  className="input"
                  defaultValue={r.full_name || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.full_name || "")) void saveRow(r, { full_name: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Location
                <input
                  key={`loc-${r.id}-${r.location ?? ""}`}
                  className="input"
                  defaultValue={r.location || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.location || "")) void saveRow(r, { location: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Farm type
                <input
                  key={`ft-${r.id}-${r.farm_type ?? ""}`}
                  className="input"
                  defaultValue={r.farm_type || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.farm_type || "")) void saveRow(r, { farm_type: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Experience
                <input
                  key={`ex-${r.id}-${r.experience_level ?? ""}`}
                  className="input"
                  defaultValue={r.experience_level || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.experience_level || "")) void saveRow(r, { experience_level: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Acreage
                <input
                  key={`ac-${r.id}-${r.acreage ?? ""}`}
                  className="input"
                  type="number"
                  step="any"
                  defaultValue={r.acreage ?? ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const raw = e.target.value.trim();
                    if (raw === "") {
                      if (r.acreage != null) void saveRow(r, { acreage: null });
                      return;
                    }
                    const n = Number(raw);
                    if (!Number.isFinite(n)) return;
                    if (n !== r.acreage) void saveRow(r, { acreage: n });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Crop types
                <input
                  key={`ct-${r.id}-${r.crop_types ?? ""}`}
                  className="input"
                  defaultValue={r.crop_types || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.crop_types || "")) void saveRow(r, { crop_types: v });
                  }}
                />
              </label>
              <label className="subtle stack" style={{ gap: 4 }}>
                Practice stage
                <input
                  key={`ps-${r.id}-${r.practice_stage ?? ""}`}
                  className="input"
                  defaultValue={r.practice_stage || ""}
                  disabled={busyId === r.id}
                  onBlur={(e) => {
                    const v = e.target.value.trim() || null;
                    if (v !== (r.practice_stage || "")) void saveRow(r, { practice_stage: v });
                  }}
                />
              </label>
            </div>
            <label className="subtle stack" style={{ gap: 4 }}>
              Bio
              <textarea
                key={`bio-${r.id}-${(r.bio ?? "").slice(0, 20)}`}
                className="input"
                rows={2}
                defaultValue={r.bio || ""}
                disabled={busyId === r.id}
                onBlur={(e) => {
                  const v = e.target.value.trim() || null;
                  if (v !== (r.bio || "")) void saveRow(r, { bio: v });
                }}
              />
            </label>
          </div>
        ))}
      </div>
    </div>
  );
}

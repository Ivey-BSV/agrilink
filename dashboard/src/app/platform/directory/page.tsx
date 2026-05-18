"use client";

import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { UserAvatar } from "@/components/user-avatar";
import { MotionListItem } from "@/components/motion-list";

type FarmProfile = {
  id: string;
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
  location: string | null;
  farm_type: string | null;
  bio: string | null;
};

export default function PlatformDirectoryPage() {
  const [rows, setRows] = useState<FarmProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const { data, error: e } = await supabase
        .from("user_profiles")
        .select("id, full_name, username, avatar_url, location, farm_type, bio")
        .order("created_at", { ascending: false })
        .limit(200);
      if (cancelled) return;
      if (e) setError(e.message);
      else setRows((data as FarmProfile[]) ?? []);
      setLoading(false);
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((r) =>
      [r.full_name, r.username, r.location, r.farm_type, r.bio].some((v) => (v ?? "").toLowerCase().includes(q))
    );
  }, [rows, query]);

  return (
    <motion.div className="content-card stack" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
      <p className="subtle" style={{ marginBottom: 12 }}>
        Search members by name, region, farm type, or a short bio to find people you may want to connect with.
      </p>
      <div className="field" style={{ maxWidth: 430 }}>
        <label htmlFor="directory-search">Search</label>
        <input id="directory-search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Name, location, farm type…" />
      </div>

      <div className="platform-tag-row">
        <span className="pill">{rows.length} profiles</span>
        <span className="pill">{filtered.length} shown</span>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading directory…</p> : null}
      {!loading && filtered.length === 0 ? <p className="empty">No matching profiles.</p> : null}

      <div className="list">
        {filtered.map((row, index) => (
          <MotionListItem key={row.id} index={index} className="list-item farm-directory-card platform-directory-card">
            <div className="feed-author-row">
              <UserAvatar url={row.avatar_url} name={row.full_name ?? row.username} size={54} />
              <div className="stack" style={{ gap: 4 }}>
                <div className="workshop-line-title">{row.full_name || row.username || "Farmer"}</div>
                <div className="workshop-line-meta">
                  {[row.location, row.farm_type].filter(Boolean).join(" · ") || "No location/farm type yet."}
                </div>
                {row.bio ? <div className="subtle">{row.bio}</div> : null}
              </div>
            </div>
          </MotionListItem>
        ))}
      </div>
    </motion.div>
  );
}

"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { UserAvatar } from "@/components/user-avatar";

type Row = {
  id: string;
  username: string | null;
  full_name: string | null;
  avatar_url: string | null;
};

type ProfileFollowListPageProps = {
  title: string;
  description: string;
  emptyMessage: string;
  followColumn: "follower_id" | "following_id";
  filterColumn: "following_id" | "follower_id";
};

export function ProfileFollowListPage({
  title,
  description,
  emptyMessage,
  followColumn,
  filterColumn,
}: ProfileFollowListPageProps) {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) {
          setError("Not signed in.");
          setLoading(false);
        }
        return;
      }

      const { data: followRows, error: fe } = await supabase
        .from("follows")
        .select(`${followColumn}, created_at`)
        .eq(filterColumn, user.id)
        .order("created_at", { ascending: false })
        .limit(200);

      if (cancelled) return;
      if (fe) {
        setError(fe.message);
        setLoading(false);
        return;
      }

      const ids =
        (followRows as Record<string, string>[] | null)?.map((r) => r[followColumn]) ?? [];
      if (ids.length === 0) {
        setRows([]);
        setLoading(false);
        return;
      }

      const { data: profs, error: pe } = await supabase
        .from("user_profiles")
        .select("id, username, full_name, avatar_url")
        .in("id", ids);

      if (cancelled) return;
      if (pe) setError(pe.message);

      const byId = new Map((profs as Row[] | null)?.map((p) => [p.id, p]) ?? []);
      setRows(ids.map((id) => byId.get(id) ?? { id, username: null, full_name: null, avatar_url: null }));
      setLoading(false);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [followColumn, filterColumn]);

  return (
    <motion.div
      className="content-card stack"
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="stack" style={{ gap: 4 }}>
        <Link href="/platform/profile" className="subtle" style={{ textDecoration: "none" }}>
          ← My profile
        </Link>
        <h2 className="section-title">{title}</h2>
        <p className="subtle" style={{ margin: 0 }}>
          {description}
        </p>
      </div>

      {loading ? <p className="subtle">Loading…</p> : null}
      {error ? <p className="error">{error}</p> : null}

      {!loading && rows.length === 0 ? <p className="empty">{emptyMessage}</p> : null}

      <ul className="list" style={{ margin: 0, padding: 0, listStyle: "none" }}>
        {rows.map((r) => {
          const name = r.full_name?.trim() || r.username || "Member";
          return (
            <li key={r.id} className="list-item" style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <UserAvatar url={r.avatar_url} name={name} email={null} size={44} />
              <div className="stack" style={{ gap: 2, minWidth: 0 }}>
                <div style={{ fontWeight: 600 }}>{name}</div>
                {r.username ? <div className="subtle">@{r.username}</div> : null}
              </div>
              <Link
                href={`/platform/chat/with/${r.id}`}
                className="btn btn-secondary"
                style={{ marginLeft: "auto", flexShrink: 0 }}
              >
                Message
              </Link>
            </li>
          );
        })}
      </ul>
    </motion.div>
  );
}

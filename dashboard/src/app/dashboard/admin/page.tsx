"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useStaffAccess } from "@/components/staff-access-context";
import { isAdminOrSuperEffective, isSuperEffective } from "@/lib/staff-profile";

type NullableCount = number | null;

type TopPoster = {
  userId: string;
  count: number;
  username: string | null;
  fullName: string | null;
};

type LoadState = {
  farmers: NullableCount;
  posts: NullableCount;
  postsLast7d: NullableCount;
  comments: NullableCount;
  events: NullableCount;
  polls: NullableCount;
  listings: NullableCount;
  goals: NullableCount;
  postLikes: NullableCount;
  topPosters: TopPoster[] | null;
};

const emptyState = (): LoadState => ({
  farmers: null,
  posts: null,
  postsLast7d: null,
  comments: null,
  events: null,
  polls: null,
  listings: null,
  goals: null,
  postLikes: null,
  topPosters: null,
});

function formatCount(n: NullableCount): string {
  if (n === null) return "—";
  return n.toLocaleString();
}

export default function AdminConsoleHomePage() {
  const { staffAccess: access, ready: accessReady } = useStaffAccess();
  const [loading, setLoading] = useState(true);
  const [metrics, setMetrics] = useState<LoadState>(() => emptyState());

  const admin = isAdminOrSuperEffective(access);
  const sup = isSuperEffective(access);

  const load = useCallback(async () => {
    setLoading(true);
    const since7 = new Date();
    since7.setDate(since7.getDate() - 7);
    const sinceIso = since7.toISOString();

    const countExact = async (
      table: string,
      filters: { eq?: [string, string][]; gte?: [string, string] } = {},
    ): Promise<NullableCount> => {
      let q = supabase.from(table).select("*", { count: "exact", head: true });
      for (const [col, val] of filters.eq ?? []) {
        q = q.eq(col, val);
      }
      if (filters.gte) {
        const [col, val] = filters.gte;
        q = q.gte(col, val);
      }
      const { count, error: cErr } = await q;
      if (cErr) return null;
      return count ?? 0;
    };

    const [farmers, posts, postsLast7d, comments, events, polls, listings, goals, postLikes] = await Promise.all([
      countExact("user_profiles", { eq: [["account_kind", "farmer"]] }),
      countExact("posts"),
      countExact("posts", { gte: ["created_at", sinceIso] }),
      countExact("comments"),
      countExact("events"),
      countExact("polls"),
      countExact("marketplace_listings"),
      countExact("goals"),
      countExact("post_likes"),
    ]);

    let topPosters: TopPoster[] | null = null;
    const { data: postRows, error: postsSampleErr } = await supabase
      .from("posts")
      .select("user_id")
      .limit(4000);
    if (!postsSampleErr && postRows?.length) {
      const tally = new Map<string, number>();
      for (const row of postRows as { user_id: string }[]) {
        const uid = row.user_id;
        tally.set(uid, (tally.get(uid) ?? 0) + 1);
      }
      const sorted = [...tally.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
      const ids = sorted.map(([id]) => id);
      const { data: profs, error: profErr } = await supabase
        .from("user_profiles")
        .select("id, username, full_name")
        .in("id", ids);
      if (!profErr && profs) {
        const byId = new Map((profs as { id: string; username: string | null; full_name: string | null }[]).map((p) => [p.id, p]));
        topPosters = sorted.map(([userId, count]) => {
          const p = byId.get(userId);
          return {
            userId,
            count,
            username: p?.username ?? null,
            fullName: p?.full_name ?? null,
          };
        });
      } else {
        topPosters = sorted.map(([userId, count]) => ({ userId, count, username: null, fullName: null }));
      }
    } else if (postsSampleErr) {
      topPosters = null;
    }

    setMetrics({
      farmers,
      posts,
      postsLast7d,
      comments,
      events,
      polls,
      listings,
      goals,
      postLikes,
      topPosters,
    });
    setLoading(false);
  }, []);

  useEffect(() => {
    if (!accessReady || !access) return;
    void load();
  }, [accessReady, access, load]);

  if (!accessReady) return <div className="content-card">Loading…</div>;
  if (!access) return null;

  return (
    <div className="content-card stack admin-console-home" style={{ gap: 18 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 16, flexWrap: "wrap" }}>
        <div>
          <h2 className="section-title" style={{ marginBottom: 6 }}>
            Admin console
          </h2>
          <p className="subtle" style={{ margin: 0, maxWidth: 640 }}>
            Snapshot of community activity and catalog volume. If a number shows as an em dash, your account may not
            have permission to load that metric.
          </p>
        </div>
        <button type="button" className="btn btn-secondary" disabled={loading} onClick={() => void load()}>
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </div>

      <p className="subtle" style={{ margin: 0 }}>
        Signed in as <strong>{access.appRole.replace(/_/g, " ")}</strong>.
        {!admin ? " Program admin tools (e.g. farmers) appear when your role includes them." : ""}
        {!sup ? " Platform (staff, audit, system) unlocks for super admins." : ""}
      </p>

      <section className="admin-analytics-stat-grid" aria-label="Key metrics">
        {admin ? (
          <div className="admin-stat-card">
            <div className="admin-stat-label">Farmer profiles</div>
            <div className="admin-stat-value">{formatCount(metrics.farmers)}</div>
            <div className="admin-stat-foot">Farmer accounts only</div>
          </div>
        ) : null}
        <div className="admin-stat-card">
          <div className="admin-stat-label">Feed posts</div>
          <div className="admin-stat-value">{formatCount(metrics.posts)}</div>
          <div className="admin-stat-foot">Last 7 days: {formatCount(metrics.postsLast7d)}</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Comments</div>
          <div className="admin-stat-value">{formatCount(metrics.comments)}</div>
          <div className="admin-stat-foot">On feed posts</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Post likes</div>
          <div className="admin-stat-value">{formatCount(metrics.postLikes)}</div>
          <div className="admin-stat-foot">Engagement</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Events</div>
          <div className="admin-stat-value">{formatCount(metrics.events)}</div>
          <div className="admin-stat-foot">All rows</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Polls</div>
          <div className="admin-stat-value">{formatCount(metrics.polls)}</div>
          <div className="admin-stat-foot">Active + past</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Marketplace listings</div>
          <div className="admin-stat-value">{formatCount(metrics.listings)}</div>
          <div className="admin-stat-foot">Exchange hub</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Goals</div>
          <div className="admin-stat-value">{formatCount(metrics.goals)}</div>
          <div className="admin-stat-foot">Farm + community projects</div>
        </div>
      </section>

      <div className="admin-analytics-two-col">
        <section className="content-card stack" style={{ gap: 10, padding: 16 }}>
          <h3 style={{ fontSize: 16, margin: 0 }}>Top posters (sample)</h3>
          <p className="subtle" style={{ margin: 0 }}>
            Built from up to 4,000 recent post rows, then grouped by author. For full moderation, use the feed tools.
          </p>
          {metrics.topPosters && metrics.topPosters.length > 0 ? (
            <ul className="admin-top-poster-list">
              {metrics.topPosters.map((row, i) => (
                <li key={row.userId}>
                  <span className="admin-top-rank">{i + 1}</span>
                  <span>
                    <strong>{row.fullName || row.username || row.userId.slice(0, 8)}</strong>
                    {row.username ? <span className="subtle"> @{row.username}</span> : null}
                  </span>
                  <span className="admin-top-count">{row.count}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="subtle">{loading ? "Loading…" : "No sample data or posts are not readable for this session."}</p>
          )}
        </section>

        <section className="content-card stack" style={{ gap: 10, padding: 16 }}>
          <h3 style={{ fontSize: 16, margin: 0 }}>Jump to tools</h3>
          <p className="subtle" style={{ margin: 0 }}>Shortcuts for the tools you use often.</p>
          <ul className="admin-quick-links">
            {admin ? (
              <li>
                <Link href="/dashboard/admin/farmers">Farmers</Link>
                <span className="subtle"> — profiles and access</span>
              </li>
            ) : null}
            <li>
              <Link href="/dashboard/admin/events">All events</Link>
              <span className="subtle"> — edit any organizer&apos;s event</span>
            </li>
            {sup ? (
              <>
                <li>
                  <Link href="/dashboard/admin/staff">Staff access</Link>
                </li>
                <li>
                  <Link href="/dashboard/admin/audit">Audit log</Link>
                </li>
                <li>
                  <Link href="/dashboard/admin/system">System &amp; export</Link>
                </li>
              </>
            ) : null}
          </ul>
          <p className="subtle" style={{ margin: 0, fontSize: 12 }}>
            Member-facing pages (feed, listings, workshops) live under{" "}
            <Link href="/dashboard">Dashboard</Link>.
          </p>
        </section>
      </div>
    </div>
  );
}

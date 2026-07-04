"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  deletePollById,
  getMyVotesForPoll,
  getPollDetail,
  getPollVoteCounts,
  getPollVotersForSuperAdmin,
  replacePollOptionsKeepingPoll,
  submitPollVote,
  updatePollRecord,
  type PollDetail,
  type PollVoterRow,
} from "@/lib/polls";
import { formatRelativeTime } from "@/lib/format";
import { useMemberFacingStaffAccess } from "@/hooks/use-member-facing-staff-access";
import {
  PlatformMetaRow,
  PlatformPageShell,
  PlatformSectionCard,
  PlatformSectionIntro,
} from "@/components/platform-section";

type SuperAdminTab = "breakdown" | "manage";

export default function PollDetailPage() {
  const params = useParams();
  const pollId = typeof params.pollId === "string" ? params.pollId : "";
  const { isSuper } = useMemberFacingStaffAccess();

  const [poll, setPoll] = useState<PollDetail | null>(null);
  const [voteCounts, setVoteCounts] = useState<Record<string, number>>({});
  const [totalVotes, setTotalVotes] = useState(0);
  const [voters, setVoters] = useState<PollVoterRow[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [superAdminTab, setSuperAdminTab] = useState<SuperAdminTab>("breakdown");

  const [adminTitle, setAdminTitle] = useState("");
  const [adminDesc, setAdminDesc] = useState("");
  const [adminStatus, setAdminStatus] = useState<"active" | "closed">("active");
  const [adminMulti, setAdminMulti] = useState(false);
  const [adminCloses, setAdminCloses] = useState("");
  const [adminOptionLines, setAdminOptionLines] = useState("");
  const [adminBusy, setAdminBusy] = useState(false);

  const load = useCallback(async () => {
    if (!pollId) return;
    setLoading(true);
    setError(null);
    const { poll: p, error: pe } = await getPollDetail(pollId);
    setPoll(p);
    if (pe) setError(pe);

    const { counts, total, error: countError } = await getPollVoteCounts(pollId);
    if (countError) setError(countError);
    setVoteCounts(counts);
    setTotalVotes(total);

    const { optionIds, error: ve } = await getMyVotesForPoll(pollId);
    if (ve) setError(ve);
    setSelected(new Set(optionIds));

    if (isSuper) {
      const { rows, error: voterError } = await getPollVotersForSuperAdmin(pollId);
      if (voterError) setError(voterError);
      setVoters(rows);
    } else {
      setVoters([]);
    }

    setLoading(false);
  }, [pollId, isSuper]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!poll || !isSuper) return;
    setAdminTitle(poll.title);
    setAdminDesc(poll.description ?? "");
    setAdminStatus(poll.status === "closed" ? "closed" : "active");
    setAdminMulti(poll.allows_multiple);
    setAdminCloses(poll.closes_at ? poll.closes_at.slice(0, 16) : "");
    setAdminOptionLines(poll.poll_options.map((o) => o.label).join("\n"));
  }, [poll, isSuper]);

  const optionLabelById = useMemo(() => {
    const map = new Map<string, string>();
    for (const option of poll?.poll_options ?? []) {
      map.set(option.id, option.label);
    }
    return map;
  }, [poll?.poll_options]);

  const voterRowsForTable = useMemo(() => {
    return [...voters].sort((a, b) => {
      const labelA = optionLabelById.get(a.option_id) ?? "";
      const labelB = optionLabelById.get(b.option_id) ?? "";
      const byOption = labelA.localeCompare(labelB);
      if (byOption !== 0) return byOption;
      return voterLabel(a).localeCompare(voterLabel(b));
    });
  }, [voters, optionLabelById]);

  const toggle = (id: string) => {
    if (!poll || poll.status !== "active") return;
    if (poll.closes_at) {
      const end = new Date(poll.closes_at);
      if (!Number.isNaN(end.getTime()) && end.getTime() <= Date.now()) return;
    }
    if (!poll.allows_multiple) {
      setSelected(new Set([id]));
      return;
    }
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const onSave = async () => {
    if (!pollId) return;
    setSaving(true);
    setOk(null);
    setError(null);
    const { error: e } = await submitPollVote(pollId, [...selected]);
    setSaving(false);
    if (e) setError(e);
    else setOk("Vote saved.");
    await load();
  };

  const onSaveAdminMeta = async () => {
    if (!pollId || !isSuper) return;
    setAdminBusy(true);
    setError(null);
    setOk(null);
    const closesIso = adminCloses.trim() ? new Date(adminCloses.trim()).toISOString() : null;
    const { error: e } = await updatePollRecord(pollId, {
      title: adminTitle,
      description: adminDesc.trim() || null,
      status: adminStatus,
      allows_multiple: adminMulti,
      closes_at: closesIso,
    });
    setAdminBusy(false);
    if (e) setError(e);
    else setOk("Poll settings updated.");
    await load();
  };

  const onReplaceOptions = async () => {
    if (!pollId || !isSuper) return;
    const labels = adminOptionLines.split("\n").map((s) => s.trim()).filter(Boolean);
    if (labels.length < 2) {
      setError("Enter at least two option lines.");
      return;
    }
    if (!confirm("Replace all options and clear votes? This cannot be undone.")) return;
    setAdminBusy(true);
    setError(null);
    setOk(null);
    const { error: e } = await replacePollOptionsKeepingPoll(pollId, labels);
    setAdminBusy(false);
    if (e) setError(e);
    else setOk("Options replaced and votes cleared.");
    await load();
  };

  const onDeletePoll = async () => {
    if (!pollId || !isSuper) return;
    if (!confirm("Delete this poll entirely?")) return;
    setAdminBusy(true);
    setError(null);
    const { error: e } = await deletePollById(pollId);
    setAdminBusy(false);
    if (e) {
      setError(e);
      return;
    }
    window.location.href = "/platform/collaboration/polls";
  };

  if (!pollId) {
    return (
      <div className="content-card">
        <p className="subtle">Invalid poll.</p>
        <Link href="/platform/collaboration/polls" className="btn btn-secondary" style={{ marginTop: 12 }}>
          Back to polls
        </Link>
      </div>
    );
  }

  if (loading) return <p className="subtle content-card">Loading poll…</p>;
  if (error && !poll) {
    return (
      <div className="content-card stack" style={{ gap: 12 }}>
        <p className="error">{error}</p>
        <Link href="/platform/collaboration/polls" className="btn btn-secondary">
          Back to polls
        </Link>
      </div>
    );
  }
  if (!poll) return null;

  const ended =
    poll.status === "closed" ||
    (poll.closes_at ? new Date(poll.closes_at).getTime() <= Date.now() : false);

  return (
    <PlatformPageShell variant="stack">
      <PlatformSectionCard>
        <Link href="/platform/collaboration/polls" className="btn btn-secondary" style={{ alignSelf: "flex-start" }}>
          ← All polls
        </Link>
        <h2 className="section-title" style={{ margin: 0 }}>
          {poll.title}
        </h2>
        {poll.description ? <p style={{ margin: 0, lineHeight: 1.55 }}>{poll.description}</p> : null}
        <PlatformMetaRow>
          <span className="pill">{poll.allows_multiple ? "Multiple answers" : "Single answer"}</span>
          <span className="pill">{ended ? "Closed" : "Open"}</span>
          <span className="subtle">{totalVotes} total vote{totalVotes === 1 ? "" : "s"}</span>
        </PlatformMetaRow>
        {ok ? <p className="success">{ok}</p> : null}
        {error ? <p className="error">{error}</p> : null}
      </PlatformSectionCard>

      <PlatformSectionCard>
        <PlatformSectionIntro
          title="Results"
          description="Vote totals everyone can see. Individual choices stay private."
        />
        <ul className="poll-results-list">
          {poll.poll_options.map((o) => {
            const count = voteCounts[o.id] ?? 0;
            const pct = totalVotes > 0 ? Math.round((100 * count) / totalVotes) : 0;
            return (
              <li key={o.id} className="poll-result-row">
                <div className="poll-result-row-head">
                  <span className="poll-result-label">{o.label}</span>
                  <span className="poll-result-meta">
                    {count} · {pct}%
                  </span>
                </div>
                <span className="poll-option-result-bar" aria-hidden>
                  <span className="poll-option-result-bar-fill" style={{ width: `${pct}%` }} />
                </span>
              </li>
            );
          })}
        </ul>
      </PlatformSectionCard>

      {!ended ? (
        <PlatformSectionCard>
          <PlatformSectionIntro
            title="Your vote"
            description={poll.allows_multiple ? "Pick one or more answers, then save." : "Pick one answer, then save."}
          />
          <ul className="projects-milestone-list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
            {poll.poll_options.map((o) => (
              <li key={o.id} className="projects-milestone-row">
                <label className="projects-milestone-label" style={{ cursor: saving ? "default" : "pointer" }}>
                  <input
                    type={poll.allows_multiple ? "checkbox" : "radio"}
                    name={poll.allows_multiple ? undefined : `poll-${poll.id}`}
                    checked={selected.has(o.id)}
                    disabled={saving}
                    onChange={() => toggle(o.id)}
                  />
                  <span>{o.label}</span>
                </label>
              </li>
            ))}
          </ul>
          <button type="button" className="btn btn-primary" disabled={saving} onClick={() => void onSave()}>
            {saving ? "Saving…" : "Save vote"}
          </button>
        </PlatformSectionCard>
      ) : null}

      {isSuper ? (
        <PlatformSectionCard className="platform-staff-panel poll-admin-panel">
          <PlatformSectionIntro
            title="Super admin"
            description="Extra tools for reviewing responses and managing this poll."
            action={<span className="pill platform-staff-badge poll-admin-badge">Staff only</span>}
          />

          <div className="platform-profile-tabs poll-admin-tabs" role="tablist" aria-label="Super admin sections">
            <button
              type="button"
              role="tab"
              aria-selected={superAdminTab === "breakdown"}
              className={`platform-profile-tab${superAdminTab === "breakdown" ? " active" : ""}`}
              onClick={() => setSuperAdminTab("breakdown")}
            >
              Who voted
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={superAdminTab === "manage"}
              className={`platform-profile-tab${superAdminTab === "manage" ? " active" : ""}`}
              onClick={() => setSuperAdminTab("manage")}
            >
              Manage poll
            </button>
          </div>

          {superAdminTab === "breakdown" ? (
            <div className="platform-staff-tab-panel poll-admin-tab-panel" role="tabpanel">
              {voters.length === 0 ? (
                <p className="empty" style={{ margin: 0 }}>
                  No votes recorded yet.
                </p>
              ) : (
                <div className="platform-data-table-wrap poll-voter-table-wrap">
                  <table className="platform-data-table poll-voter-table">
                    <thead>
                      <tr>
                        <th scope="col">Member</th>
                        <th scope="col">Voted for</th>
                        <th scope="col">When</th>
                      </tr>
                    </thead>
                    <tbody>
                      {voterRowsForTable.map((row) => (
                        <tr key={`${row.user_id}-${row.option_id}-${row.created_at}`}>
                          <td>
                            <Link href={`/platform/user/${row.user_id}`} className="platform-data-table-link poll-voter-link">
                              {voterLabel(row)}
                            </Link>
                          </td>
                          <td>{optionLabelById.get(row.option_id) ?? "—"}</td>
                          <td className="subtle">{formatRelativeTime(row.created_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          ) : (
            <div className="platform-staff-tab-panel poll-admin-tab-panel stack" style={{ gap: 12 }} role="tabpanel">
              <p className="subtle" style={{ margin: 0 }}>
                Edit poll settings or replace answer choices. Replacing options clears all votes.
              </p>
              <div className="field">
                <label>Title</label>
                <input value={adminTitle} onChange={(e) => setAdminTitle(e.target.value)} disabled={adminBusy} />
              </div>
              <div className="field">
                <label>Description</label>
                <textarea rows={3} value={adminDesc} onChange={(e) => setAdminDesc(e.target.value)} disabled={adminBusy} />
              </div>
              <div className="field">
                <label>Status</label>
                <select value={adminStatus} onChange={(e) => setAdminStatus(e.target.value as "active" | "closed")} disabled={adminBusy}>
                  <option value="active">Active</option>
                  <option value="closed">Closed</option>
                </select>
              </div>
              <div className="field">
                <label>
                  <input type="checkbox" checked={adminMulti} onChange={(e) => setAdminMulti(e.target.checked)} disabled={adminBusy} />{" "}
                  Allow multiple selections
                </label>
              </div>
              <div className="field">
                <label>Closes at (optional, local)</label>
                <input type="datetime-local" value={adminCloses} onChange={(e) => setAdminCloses(e.target.value)} disabled={adminBusy} />
              </div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                <button type="button" className="btn btn-primary" disabled={adminBusy} onClick={() => void onSaveAdminMeta()}>
                  {adminBusy ? "Saving…" : "Save settings"}
                </button>
              </div>
              <div className="field">
                <label>Answer options (one per line)</label>
                <textarea
                  rows={6}
                  value={adminOptionLines}
                  onChange={(e) => setAdminOptionLines(e.target.value)}
                  disabled={adminBusy}
                  placeholder={"Option A\nOption B"}
                />
              </div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                <button type="button" className="btn btn-secondary" disabled={adminBusy} onClick={() => void onReplaceOptions()}>
                  Replace options &amp; clear votes
                </button>
                <button type="button" className="btn btn-danger" disabled={adminBusy} onClick={() => void onDeletePoll()}>
                  Delete poll
                </button>
              </div>
            </div>
          )}
        </PlatformSectionCard>
      ) : null}
    </PlatformPageShell>
  );
}

function voterLabel(row: PollVoterRow): string {
  const name = row.full_name?.trim();
  const username = row.username?.trim();
  if (name && username) return `${name} (@${username})`;
  if (name) return name;
  if (username) return `@${username}`;
  return "Member";
}

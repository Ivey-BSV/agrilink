"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { motion } from "framer-motion";
import { useCallback, useEffect, useState } from "react";
import {
  deletePollById,
  getMyVotesForPoll,
  getPollDetail,
  replacePollOptionsKeepingPoll,
  submitPollVote,
  updatePollRecord,
  type PollDetail,
} from "@/lib/polls";
import { useMemberFacingStaffAccess } from "@/hooks/use-member-facing-staff-access";

export default function PollDetailPage() {
  const params = useParams();
  const pollId = typeof params.pollId === "string" ? params.pollId : "";
  const { isSuper } = useMemberFacingStaffAccess();

  const [poll, setPoll] = useState<PollDetail | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

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
    const { optionIds, error: ve } = await getMyVotesForPoll(pollId);
    if (ve) setError(ve);
    setSelected(new Set(optionIds));
    setLoading(false);
  }, [pollId]);

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
    <motion.div className="stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div className="content-card stack" style={{ gap: 12 }}>
        <Link href="/platform/collaboration/polls" className="btn btn-secondary" style={{ alignSelf: "flex-start" }}>
          ← All polls
        </Link>
        <h2 className="section-title" style={{ margin: 0 }}>
          {poll.title}
        </h2>
        {poll.description ? <p style={{ margin: 0, lineHeight: 1.55 }}>{poll.description}</p> : null}
        <p className="subtle" style={{ margin: 0 }}>
          {poll.allows_multiple ? "Select one or more answers." : "Select one answer."}
          {ended ? " This poll is closed." : ""}
        </p>
        {ok ? <p className="success">{ok}</p> : null}
        {error ? <p className="error">{error}</p> : null}
      </div>

      <div className="content-card stack" style={{ gap: 10 }}>
        <h3 className="section-title" style={{ fontSize: "1.05rem" }}>
          Options
        </h3>
        <ul className="projects-milestone-list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {poll.poll_options.map((o) => (
            <li key={o.id} className="projects-milestone-row">
              <label className="projects-milestone-label" style={{ cursor: ended ? "default" : "pointer" }}>
                <input
                  type={poll.allows_multiple ? "checkbox" : "radio"}
                  name={poll.allows_multiple ? undefined : `poll-${poll.id}`}
                  checked={selected.has(o.id)}
                  disabled={ended || saving}
                  onChange={() => toggle(o.id)}
                />
                <span>{o.label}</span>
              </label>
            </li>
          ))}
        </ul>
        {!ended ? (
          <button type="button" className="btn btn-primary" disabled={saving} onClick={() => void onSave()}>
            {saving ? "Saving…" : "Save vote"}
          </button>
        ) : null}
      </div>

      {isSuper ? (
        <div className="content-card stack" style={{ gap: 12 }}>
          <h3 className="section-title" style={{ fontSize: "1.05rem", margin: 0 }}>
            Super admin
          </h3>
          <p className="subtle" style={{ margin: 0 }}>
            Use these tools when you need to fix wording, replace answer choices, close a poll, or remove it. Replacing answers clears existing votes.
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
      ) : null}
    </motion.div>
  );
}

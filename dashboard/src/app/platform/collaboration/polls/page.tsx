"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useState } from "react";
import { PageSectionHeader } from "@/components/page-section-header";
import { PlatformMetaRow, PlatformPageShell } from "@/components/platform-section";
import { formatDate } from "@/lib/format";
import { createPollWithOptions, listPollsForWeb, type PollListRow } from "@/lib/polls";
import { supabase } from "@/lib/supabase";

export default function PlatformPollsPage() {
  const router = useRouter();
  const [rows, setRows] = useState<PollListRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [signedIn, setSignedIn] = useState(false);

  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [cTitle, setCTitle] = useState("");
  const [cDesc, setCDesc] = useState("");
  const [cMulti, setCMulti] = useState(false);
  const [cCloses, setCCloses] = useState("");
  const [cOptions, setCOptions] = useState("Yes\nNo\nMaybe");

  const reload = async () => {
    setLoading(true);
    const { rows: r, error: e } = await listPollsForWeb();
    if (e) setError(e);
    else setError(null);
    setRows(r);
    setLoading(false);
  };

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!cancelled) setSignedIn(!!user);
      await reload();
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  const onCreate = async (e: FormEvent) => {
    e.preventDefault();
    setCreating(true);
    setError(null);
    const labels = cOptions.split("\n").map((s) => s.trim()).filter(Boolean);
    const closesIso = cCloses.trim() ? new Date(cCloses.trim()).toISOString() : null;
    const { pollId, error: ce } = await createPollWithOptions({
      title: cTitle,
      description: cDesc.trim() || null,
      allows_multiple: cMulti,
      closes_at: closesIso,
      optionLabels: labels,
    });
    setCreating(false);
    if (ce || !pollId) {
      setError(ce || "Could not create poll.");
      return;
    }
    setCreateOpen(false);
    setCTitle("");
    setCDesc("");
    setCMulti(false);
    setCCloses("");
    setCOptions("Yes\nNo\nMaybe");
    await reload();
    router.push(`/platform/collaboration/polls/${pollId}`);
  };

  return (
    <PlatformPageShell>
      <PageSectionHeader
        title="Polls"
        description="Run quick surveys: create a poll, collect votes while it is open, and review results when it closes. Anyone signed in can start a poll; organizers can edit or close their own."
        action={
          signedIn ? (
            <button type="button" className="btn btn-primary btn-primary-compact" onClick={() => setCreateOpen(true)}>
              New poll
            </button>
          ) : null
        }
      />
      {loading ? <p className="subtle">Loading polls…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && rows.length === 0 ? <p className="empty">No polls yet.</p> : null}
      <ul className="platform-list-rows">
        {rows.map((p) => {
          const optCount = Array.isArray(p.poll_options) ? p.poll_options.length : 0;
          const closed = p.status === "closed";
          return (
            <li key={p.id} className="platform-list-row">
              <Link href={`/platform/collaboration/polls/${p.id}`} className="workshop-line-title">
                {p.title}
              </Link>
              {p.description ? <span className="subtle" style={{ fontSize: "0.9rem" }}>{p.description}</span> : null}
              <PlatformMetaRow>
                <span className="pill">{closed ? "Closed" : "Active"}</span>
                <span className="subtle">{optCount} option{optCount === 1 ? "" : "s"}</span>
                <span className="subtle">{formatDate(p.created_at)}</span>
              </PlatformMetaRow>
            </li>
          );
        })}
      </ul>

      {createOpen ? (
        <div className="backdrop active" role="dialog" aria-modal="true">
          <div className="absolute inset-0" onClick={() => !creating && setCreateOpen(false)} />
          <div className="modal-content platform-create-modal" style={{ opacity: 1, transform: "none" }}>
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <h3 className="section-title" style={{ fontSize: "1.2rem" }}>
                  New poll
                </h3>
                <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                  Close
                </button>
              </div>
              <form className="stack" onSubmit={(e) => void onCreate(e)}>
                <div className="field">
                  <label>Title</label>
                  <input value={cTitle} onChange={(e) => setCTitle(e.target.value)} required disabled={creating} />
                </div>
                <div className="field">
                  <label>Description (optional)</label>
                  <textarea rows={2} value={cDesc} onChange={(e) => setCDesc(e.target.value)} disabled={creating} />
                </div>
                <div className="field">
                  <label>
                    <input type="checkbox" checked={cMulti} onChange={(e) => setCMulti(e.target.checked)} disabled={creating} /> Allow multiple answers
                  </label>
                </div>
                <div className="field">
                  <label>Closes at (optional)</label>
                  <input type="datetime-local" value={cCloses} onChange={(e) => setCCloses(e.target.value)} disabled={creating} />
                </div>
                <div className="field">
                  <label>Options (one per line, at least two)</label>
                  <textarea rows={5} value={cOptions} onChange={(e) => setCOptions(e.target.value)} required disabled={creating} />
                </div>
                <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
                  <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={creating}>
                    {creating ? "Creating…" : "Create poll"}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      ) : null}
    </PlatformPageShell>
  );
}

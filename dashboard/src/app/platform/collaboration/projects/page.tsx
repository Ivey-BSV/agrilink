"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { FormEvent, useCallback, useEffect, useState } from "react";
import {
  formatGoalDeadlineLabel,
  joinCommunityProject,
  leaveCommunityProject,
  createCommunityGoal,
  createFarmProject,
  loadCommunityProjectsForList,
  loadFarmProjectsForList,
  type GoalForList,
} from "@/lib/goals";

type TabId = "community" | "farm";

function ProgressBar({ value }: { value: number }) {
  const pct = Math.round(value * 100);
  return (
    <div className="projects-progress-wrap" aria-label={`Progress ${pct}%`}>
      <div className="projects-progress-track">
        <div className="projects-progress-fill" style={{ width: `${pct}%` }} />
      </div>
      <span className="projects-progress-label subtle">{pct}%</span>
    </div>
  );
}

function GoalCard({
  goal,
  tab,
  busyId,
  onJoinLeave,
}: {
  goal: GoalForList;
  tab: TabId;
  busyId: string | null;
  onJoinLeave: (goalId: string, action: "join" | "leave") => void;
}) {
  const deadline = formatGoalDeadlineLabel(goal.deadline_date);
  const completed = goal.status === "completed";

  return (
    <div className="content-card projects-goal-card">
      <div className="projects-goal-card-head">
        <div className="stack" style={{ gap: 6, minWidth: 0 }}>
          <div className="projects-goal-title-row">
            <span className={`projects-type-pill projects-type-pill--${tab}`}>
              {tab === "community" ? "Community" : "Farm"}
            </span>
            {completed ? (
              <span className="projects-type-pill projects-type-pill--done">Completed</span>
            ) : null}
          </div>
          <h3 className="section-title" style={{ fontSize: "1.05rem", margin: 0 }}>
            {goal.title || "Untitled project"}
          </h3>
          {goal.description ? (
            <p className="subtle projects-goal-desc">{goal.description}</p>
          ) : null}
        </div>
      </div>

      <ProgressBar value={goal.progress} />

      <div className="projects-goal-meta subtle">
        <span>Due {deadline}</span>
        {tab === "community" ? (
          <span>
            {goal.participantsCount} participant{goal.participantsCount === 1 ? "" : "s"}
            {goal.isJoined ? " · You’re in" : ""}
          </span>
        ) : (
          <span>Your farm project</span>
        )}
        <span>By {goal.authorName}</span>
      </div>

      <div className="projects-goal-actions">
        {tab === "community" ? (
          <button
            type="button"
            className="btn btn-secondary"
            disabled={busyId === goal.id || completed}
            onClick={() => onJoinLeave(goal.id, goal.isJoined ? "leave" : "join")}
          >
            {busyId === goal.id ? "…" : goal.isJoined ? "Leave project" : "Join project"}
          </button>
        ) : null}
        <Link href={`/platform/collaboration/projects/${goal.id}`} className="btn btn-primary btn-primary-compact">
          Open
        </Link>
      </div>
    </div>
  );
}

export default function CollaborationProjectsPage() {
  const router = useRouter();
  const [tab, setTab] = useState<TabId>("community");
  const [community, setCommunity] = useState<GoalForList[]>([]);
  const [farm, setFarm] = useState<GoalForList[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const [createOpen, setCreateOpen] = useState(false);
  const [createKind, setCreateKind] = useState<TabId>("community");
  const [creating, setCreating] = useState(false);
  const [newTitle, setNewTitle] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [newDeadline, setNewDeadline] = useState("");
  const [farmMilestoneLines, setFarmMilestoneLines] = useState("First milestone");

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    const [c, f] = await Promise.all([loadCommunityProjectsForList(), loadFarmProjectsForList()]);
    const err = c.error || f.error;
    if (err) setError(err);
    setCommunity(c.goals);
    setFarm(f.goals);
    setLoading(false);
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const onCreateCommunity = async (e: FormEvent) => {
    e.preventDefault();
    setCreating(true);
    setError(null);
    const { goalId, error: ce } = await createCommunityGoal({
      title: newTitle,
      description: newDesc.trim() || null,
      deadline_date: newDeadline,
    });
    setCreating(false);
    if (ce || !goalId) {
      setError(ce || "Could not create project.");
      return;
    }
    setCreateOpen(false);
    setNewTitle("");
    setNewDesc("");
    setNewDeadline("");
    await reload();
    router.push(`/platform/collaboration/projects/${goalId}`);
  };

  const onCreateFarm = async (e: FormEvent) => {
    e.preventDefault();
    setCreating(true);
    setError(null);
    const lines = farmMilestoneLines.split("\n").map((s) => s.trim()).filter(Boolean);
    const { goalId, error: fe } = await createFarmProject({
      title: newTitle,
      description: newDesc.trim() || null,
      deadline_date: newDeadline,
      milestoneLines: lines,
    });
    setCreating(false);
    if (fe || !goalId) {
      setError(fe || "Could not create project.");
      return;
    }
    setCreateOpen(false);
    setNewTitle("");
    setNewDesc("");
    setNewDeadline("");
    setFarmMilestoneLines("First milestone");
    await reload();
    router.push(`/platform/collaboration/projects/${goalId}`);
  };

  const openCreateModal = () => {
    setCreateKind(tab);
    setNewTitle("");
    setNewDesc("");
    setNewDeadline("");
    setFarmMilestoneLines("First milestone");
    setCreateOpen(true);
  };

  const onJoinLeave = async (goalId: string, action: "join" | "leave") => {
    setBusyId(goalId);
    const fn = action === "join" ? joinCommunityProject : leaveCommunityProject;
    const { error: e } = await fn(goalId);
    setBusyId(null);
    if (e) {
      setError(e);
      return;
    }
    await reload();
  };

  const list = tab === "community" ? community : farm;

  return (
    <motion.div
      className="stack"
      style={{ gap: 16 }}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="content-card stack" style={{ gap: 14 }}>
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            gap: 12,
            alignItems: "flex-start",
            justifyContent: "space-between",
          }}
        >
          <div className="stack" style={{ flex: "1 1 12rem", minWidth: 0, gap: 8 }}>
            <h2 className="section-title" style={{ margin: 0 }}>
              Projects
            </h2>
            <p className="subtle" style={{ margin: 0 }}>
              Community projects are open for others to join; farm projects stay on your account with milestones you check off over time. Start either kind here, then open a project to manage members and progress.
            </p>
          </div>
          <button
            type="button"
            className="btn btn-primary btn-primary-compact"
            style={{ flexShrink: 0 }}
            onClick={() => openCreateModal()}
          >
            {tab === "community" ? "New community project" : "New farm project"}
          </button>
        </div>
        <div className="platform-profile-tabs" role="tablist" aria-label="Project type">
          <button
            type="button"
            role="tab"
            aria-selected={tab === "community"}
            className={`platform-profile-tab${tab === "community" ? " active" : ""}`}
            onClick={() => setTab("community")}
          >
            Community projects
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={tab === "farm"}
            className={`platform-profile-tab${tab === "farm" ? " active" : ""}`}
            onClick={() => setTab("farm")}
          >
            Farm projects
          </button>
        </div>
      </div>

      {error ? (
        <div className="content-card">
          <p className="subtle" style={{ color: "var(--danger, #b91c1c)" }}>
            {error}
          </p>
          <button type="button" className="btn btn-secondary" style={{ marginTop: 12 }} onClick={() => void reload()}>
            Retry
          </button>
        </div>
      ) : null}

      {loading ? (
        <p className="subtle content-card">Loading projects…</p>
      ) : !error && list.length === 0 ? (
        <div className="content-card stack" style={{ gap: 8 }}>
          <p className="section-title" style={{ fontSize: "1.05rem" }}>
            {tab === "community" ? "No community projects yet" : "No farm projects yet"}
          </p>
          <p className="subtle">
            {tab === "community"
              ? "Use New community project above to start a shared goal others can join."
              : "Use New farm project above to set a private goal on your account, then add milestones on the project page."}
          </p>
        </div>
      ) : (
        <div className="stack" style={{ gap: 12 }}>
          {list.map((g) => (
            <GoalCard key={g.id} goal={g} tab={tab} busyId={busyId} onJoinLeave={onJoinLeave} />
          ))}
        </div>
      )}

      {!loading ? (
        <p className="subtle" style={{ fontSize: "0.82rem", paddingLeft: 4 }}>
          Open any project to update milestones, track completion, join or leave community efforts, and mark the whole project done when you are finished.
        </p>
      ) : null}

      {createOpen ? (
        <div className="backdrop active" role="dialog" aria-modal="true">
          <div className="absolute inset-0" onClick={() => !creating && setCreateOpen(false)} />
          <div className="modal-content platform-create-modal" style={{ opacity: 1, transform: "none" }}>
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <h3 className="section-title" style={{ fontSize: "1.2rem" }}>
                  {createKind === "community" ? "New community project" : "New farm project"}
                </h3>
                <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                  Close
                </button>
              </div>
              {createKind === "community" ? (
                <form className="stack" onSubmit={(e) => void onCreateCommunity(e)}>
                  <div className="field">
                    <label>Title</label>
                    <input value={newTitle} onChange={(e) => setNewTitle(e.target.value)} required disabled={creating} />
                  </div>
                  <div className="field">
                    <label>Description (optional)</label>
                    <textarea rows={3} value={newDesc} onChange={(e) => setNewDesc(e.target.value)} disabled={creating} />
                  </div>
                  <div className="field">
                    <label>Deadline</label>
                    <input type="date" value={newDeadline} onChange={(e) => setNewDeadline(e.target.value)} required disabled={creating} />
                  </div>
                  <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
                    <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                      Cancel
                    </button>
                    <button type="submit" className="btn btn-primary" disabled={creating}>
                      {creating ? "Creating…" : "Create & open"}
                    </button>
                  </div>
                </form>
              ) : (
                <form className="stack" onSubmit={(e) => void onCreateFarm(e)}>
                  <div className="field">
                    <label>Title</label>
                    <input value={newTitle} onChange={(e) => setNewTitle(e.target.value)} required disabled={creating} />
                  </div>
                  <div className="field">
                    <label>Description (optional)</label>
                    <textarea rows={3} value={newDesc} onChange={(e) => setNewDesc(e.target.value)} disabled={creating} />
                  </div>
                  <div className="field">
                    <label>Deadline</label>
                    <input type="date" value={newDeadline} onChange={(e) => setNewDeadline(e.target.value)} required disabled={creating} />
                  </div>
                  <div className="field">
                    <label>Milestones (one per line, at least one)</label>
                    <textarea
                      rows={5}
                      value={farmMilestoneLines}
                      onChange={(e) => setFarmMilestoneLines(e.target.value)}
                      required
                      disabled={creating}
                    />
                  </div>
                  <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
                    <button type="button" className="btn btn-secondary" disabled={creating} onClick={() => setCreateOpen(false)}>
                      Cancel
                    </button>
                    <button type="submit" className="btn btn-primary" disabled={creating}>
                      {creating ? "Creating…" : "Create & open"}
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>
      ) : null}
    </motion.div>
  );
}

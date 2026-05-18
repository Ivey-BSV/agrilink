"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import {
  formatGoalDeadlineLabel,
  joinCommunityProject,
  leaveCommunityProject,
  loadGoalDetail,
  setGoalCompletion,
  setMilestoneCompleted,
  deleteCommunityGoalAsSuperAdmin,
  type GoalDetail,
  type GoalMilestone,
} from "@/lib/goals";
import { ProjectGoalFiles } from "@/components/project-goal-files";
import { UserAvatar } from "@/components/user-avatar";
import { useStaffAccess } from "@/components/staff-access-context";
import { isSuperEffective } from "@/lib/staff-profile";

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

const CIRCLE_ROLE_LABELS: Record<string, string> = {
  leader: "Leader",
  secretary: "Secretary",
  delegate: "Delegate",
  facilitator: "Facilitator",
};

export default function ProjectDetailPage() {
  const params = useParams();
  const router = useRouter();
  const goalId = typeof params.goalId === "string" ? params.goalId : "";
  const { staffAccess, ready: staffReady } = useStaffAccess();
  const isSuper = staffReady && isSuperEffective(staffAccess);

  const [goal, setGoal] = useState<GoalDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!goalId) return;
    setLoading(true);
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    setCurrentUserId(user?.id ?? null);
    const { goal: g, error: e } = await loadGoalDetail(goalId);
    setGoal(g);
    setError(e);
    setLoading(false);
  }, [goalId]);

  useEffect(() => {
    void load();
  }, [load]);

  const isCommunity = goal?.goal_type === "community";
  const isOwner = goal != null && currentUserId != null && goal.authorUserId === currentUserId;
  const canToggleMilestones = goal != null && (isCommunity ? goal.isJoined === true || isOwner : isOwner);

  const onMilestoneChange = async (m: GoalMilestone, completed: boolean) => {
    if (!canToggleMilestones || goal?.status === "completed") return;
    setBusy(true);
    const { error: e } = await setMilestoneCompleted(m.id, completed);
    setBusy(false);
    if (e) {
      setError(e);
      return;
    }
    await load();
  };

  const onJoinLeave = async (action: "join" | "leave") => {
    if (!goalId) return;
    setBusy(true);
    const fn = action === "join" ? joinCommunityProject : leaveCommunityProject;
    const { error: e } = await fn(goalId);
    setBusy(false);
    if (e) {
      setError(e);
      return;
    }
    await load();
  };

  const onToggleComplete = async (completed: boolean) => {
    if (!goalId) return;
    setBusy(true);
    const { error: e } = await setGoalCompletion(goalId, completed);
    setBusy(false);
    if (e) {
      setError(e);
      return;
    }
    await load();
  };

  const onSuperDeleteCommunity = async () => {
    if (!goalId || !isSuper || !goal || goal.goal_type !== "community") return;
    if (!confirm(`Permanently delete this community project ("${goal.title}")? This cannot be undone.`)) return;
    setBusy(true);
    setError(null);
    const { error: e } = await deleteCommunityGoalAsSuperAdmin(goalId);
    setBusy(false);
    if (e) {
      setError(e);
      return;
    }
    router.push("/platform/collaboration/projects");
  };

  if (!goalId) {
    return (
      <div className="content-card">
        <p className="subtle">Invalid project.</p>
        <Link href="/platform/collaboration/projects" className="btn btn-secondary" style={{ marginTop: 12 }}>
          Back to projects
        </Link>
      </div>
    );
  }

  if (loading) {
    return <p className="subtle content-card">Loading project…</p>;
  }

  if (error || !goal) {
    return (
      <div className="content-card stack" style={{ gap: 12 }}>
        <p className="subtle" style={{ color: "var(--danger, #b91c1c)" }}>
          {error || "Project not found."}
        </p>
        <Link href="/platform/collaboration/projects" className="btn btn-secondary">
          Back to projects
        </Link>
      </div>
    );
  }

  const deadline = formatGoalDeadlineLabel(goal.deadline_date);
  const completed = goal.status === "completed";

  return (
    <motion.div className="stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div className="content-card stack" style={{ gap: 12 }}>
        <button type="button" className="btn btn-secondary" style={{ alignSelf: "flex-start" }} onClick={() => router.push("/platform/collaboration/projects")}>
          ← All projects
        </button>

        <div className="projects-goal-title-row">
          <span className={`projects-type-pill projects-type-pill--${isCommunity ? "community" : "farm"}`}>
            {isCommunity ? "Community project" : "Farm project"}
          </span>
          {completed ? <span className="projects-type-pill projects-type-pill--done">Completed</span> : null}
        </div>

        <h2 className="section-title" style={{ margin: 0 }}>
          {goal.title}
        </h2>
        <p className="subtle">Due {deadline}</p>
        {isCommunity ? (
          <p className="subtle">
            {goal.participantsCount} participant{goal.participantsCount === 1 ? "" : "s"} · Started by {goal.authorName}
            {goal.isJoined ? " · You’re in" : ""}
          </p>
        ) : (
          <p className="subtle">Private milestones for your farm that only you manage and mark complete.</p>
        )}

        <ProgressBar value={goal.progress} />

        {goal.description ? (
          <div className="stack" style={{ gap: 8 }}>
            <h3 className="section-title" style={{ fontSize: "1.05rem", margin: 0 }}>
              About this project
            </h3>
            <p style={{ lineHeight: 1.55, margin: 0 }}>{goal.description}</p>
          </div>
        ) : null}

        {isCommunity && goal.participants && goal.participants.length > 0 ? (
          <div className="stack" style={{ gap: 10 }}>
            <h3 className="section-title" style={{ fontSize: "1.05rem", margin: 0 }}>
              Participants
            </h3>
            <ul className="projects-milestone-list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
              {goal.participants.map((p) => (
                <li
                  key={p.userId}
                  className="projects-milestone-row"
                  style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}
                >
                  <UserAvatar url={p.avatarUrl ?? undefined} name={p.displayName} size={40} />
                  <div style={{ flex: "1 1 140px", minWidth: 0 }}>
                    <div style={{ fontWeight: 600 }}>
                      {p.displayName}
                      {p.isCreator ? (
                        <span className="subtle" style={{ fontWeight: 400, marginLeft: 8 }}>
                          Creator
                        </span>
                      ) : null}
                    </div>
                    <div className="subtle" style={{ fontSize: "0.9rem" }}>
                      {p.contributionPct}% milestones done
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {isCommunity && !completed ? (
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {goal.isJoined ? (
              <button type="button" className="btn btn-secondary" disabled={busy} onClick={() => void onJoinLeave("leave")}>
                Leave project
              </button>
            ) : (
              <button type="button" className="btn btn-primary" disabled={busy} onClick={() => void onJoinLeave("join")}>
                Join project
              </button>
            )}
          </div>
        ) : null}

        {!completed && (isOwner || (isCommunity && goal.isJoined)) ? (
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            <button type="button" className="btn btn-primary" disabled={busy} onClick={() => void onToggleComplete(true)}>
              Mark project complete
            </button>
          </div>
        ) : null}

        {completed && isOwner ? (
          <button type="button" className="btn btn-secondary" disabled={busy} onClick={() => void onToggleComplete(false)}>
            Mark incomplete
          </button>
        ) : null}
      </div>

      <ProjectGoalFiles
        goalId={goalId}
        canUpload={isOwner || (isCommunity === true && goal.isJoined === true)}
        completed={completed}
      />

      {isCommunity && goal.circleRoles && goal.circleRoles.length > 0 ? (
        <div className="content-card stack" style={{ gap: 12 }}>
          <h3 className="section-title" style={{ fontSize: "1.1rem" }}>
            Circle roles
          </h3>
          <p className="subtle" style={{ margin: 0 }}>
            Governing seats for this community project (assign or claim seats in the mobile app).
          </p>
          <ul className="projects-milestone-list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
            {goal.circleRoles.map((seat) => (
              <li
                key={seat.role}
                className="projects-milestone-row"
                style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}
              >
                <span style={{ fontWeight: 600 }}>{CIRCLE_ROLE_LABELS[seat.role] ?? seat.role}</span>
                <span className="subtle">{seat.memberName ?? (seat.userId ? "Member" : "Vacant")}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {isSuper && isCommunity ? (
        <div className="content-card stack" style={{ gap: 12 }}>
          <h3 className="section-title" style={{ fontSize: "1.05rem", margin: 0 }}>
            Super admin
          </h3>
          <p className="subtle" style={{ margin: 0 }}>
            Permanently remove this community project. Only super admins see this option.
          </p>
          <button type="button" className="btn btn-danger" disabled={busy} onClick={() => void onSuperDeleteCommunity()}>
            Delete community project
          </button>
        </div>
      ) : null}

      <div className="content-card stack" style={{ gap: 14 }}>
        <h3 className="section-title" style={{ fontSize: "1.1rem" }}>
          Milestones
        </h3>
        {!canToggleMilestones && !completed ? (
          <p className="subtle">
            {isCommunity
              ? "Join this community project to check off milestones (same as the mobile app)."
              : "Only the project owner can update milestones here."}
          </p>
        ) : null}
        {goal.milestones.length === 0 ? (
          <p className="subtle">No milestones yet.</p>
        ) : (
          <ul className="projects-milestone-list">
            {goal.milestones.map((m) => (
              <li key={m.id} className="projects-milestone-row">
                <label className="projects-milestone-label">
                  <input
                    type="checkbox"
                    checked={m.completed === true}
                    disabled={busy || completed || !canToggleMilestones}
                    onChange={(ev) => void onMilestoneChange(m, ev.target.checked)}
                  />
                  <span>
                    <strong>{m.title}</strong>
                    {m.description ? <span className="subtle"> — {m.description}</span> : null}
                  </span>
                </label>
              </li>
            ))}
          </ul>
        )}
      </div>
    </motion.div>
  );
}

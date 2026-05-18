import { supabase } from "@/lib/supabase";
import { extractStoragePathFromPublicUrl } from "@/lib/storage";
import { getEffectiveStaffAccess, isSuperEffective } from "@/lib/staff-profile";

const COMMUNITY_LIST_SELECT = `
  *,
  user_profiles!goals_user_id_fkey (
    username,
    full_name,
    avatar_url
  ),
  goal_milestones (
    id,
    title,
    description,
    completed,
    completed_at,
    position,
    created_at
  ),
  community_goal_participants (
    user_id,
    user_profiles!community_goal_participants_user_id_fkey (
      username,
      full_name,
      avatar_url
    )
  )
`;

const FARM_SELECT = `
  *,
  user_profiles!goals_user_id_fkey (
    username,
    full_name,
    avatar_url
  ),
  goal_milestones (
    id,
    title,
    description,
    completed,
    completed_at,
    position,
    created_at
  )
`;


export type GoalMilestone = {
  id: string;
  title: string;
  description: string | null;
  completed: boolean | null;
  completed_at: string | null;
  position: number | null;
  created_at?: string | null;
};

export type CircleRoleSeat = {
  role: string;
  userId: string | null;
  memberName: string | null;
};

export type GoalParticipant = {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  contributionPct: number;
  isCreator: boolean;
};

export type GoalForList = {
  id: string;
  title: string;
  description: string | null;
  goal_type: string;
  status: string | null;
  deadline_date: string;
  progress: number;
  authorName: string;
  authorUserId: string;
  participantsCount: number;
  milestones: GoalMilestone[];
  isJoined?: boolean;
};

export type GoalDetail = GoalForList & {
  circleRoles?: CircleRoleSeat[];
  participants?: GoalParticipant[];
};

function profileName(p: { full_name?: string | null; username?: string | null } | null | undefined): string {
  if (!p) return "Unknown";
  const n = (p.full_name || p.username || "").trim();
  return n || "Unknown";
}

function sortMilestones(m: GoalMilestone[]): GoalMilestone[] {
  return [...m].sort((a, b) => {
    const ap = a.position ?? 0;
    const bp = b.position ?? 0;
    if (ap !== bp) return ap - bp;
    return (a.created_at ?? "").localeCompare(b.created_at ?? "");
  });
}

export function calcProgress(milestones: GoalMilestone[]): number {
  if (milestones.length === 0) return 0;
  const done = milestones.filter((x) => x.completed === true).length;
  return done / milestones.length;
}

function readProfile(goal: Record<string, unknown>): { name: string } {
  const up = goal.user_profiles;
  if (up && typeof up === "object" && !Array.isArray(up)) {
    return { name: profileName(up as { full_name?: string | null; username?: string | null }) };
  }
  return { name: "Unknown" };
}

async function fetchCircleRolesForGoal(goalId: string): Promise<CircleRoleSeat[]> {
  const { data, error } = await supabase
    .from("community_goal_circle_roles")
    .select("role, user_id, user_profiles(username, full_name)" as never)
    .eq("goal_id", goalId);
  if (error || !data) return [];
  const rows = data as unknown as {
    role: string;
    user_id: string | null;
    user_profiles: { username?: string | null; full_name?: string | null } | null;
  }[];
  const order = ["leader", "secretary", "delegate", "facilitator"] as const;
  const byRole = new Map<string, CircleRoleSeat>();
  for (const raw of rows) {
    const up = raw.user_profiles;
    let memberName: string | null = null;
    if (up && typeof up === "object") {
      memberName = profileName(up);
      if (memberName === "Unknown") memberName = null;
    }
    byRole.set(raw.role, {
      role: raw.role,
      userId: raw.user_id != null ? String(raw.user_id) : null,
      memberName,
    });
  }
  return order.map((role) => byRole.get(role) ?? { role, userId: null, memberName: null });
}

async function fetchMilestoneContributionsByUser(goalId: string): Promise<Record<string, number>> {
  const { data: ms, error } = await supabase.from("goal_milestones").select("id").eq("goal_id", goalId);
  if (error || !ms?.length) return {};
  const ids = ms.map((m) => String((m as { id: string }).id));
  const { data: comps, error: cErr } = await supabase.from("milestone_completions").select("user_id").in("milestone_id", ids);
  if (cErr || !comps) return {};
  const counts: Record<string, number> = {};
  for (const c of comps as { user_id: string }[]) {
    counts[c.user_id] = (counts[c.user_id] ?? 0) + 1;
  }
  return counts;
}

function buildCommunityParticipants(
  row: Record<string, unknown>,
  authorUserId: string,
  milestonesCount: number,
  contributions: Record<string, number>,
): GoalParticipant[] {
  const raw = Array.isArray(row.community_goal_participants)
    ? (row.community_goal_participants as Record<string, unknown>[])
    : [];
  const items: GoalParticipant[] = raw.map((p) => {
    const userId = String(p.user_id ?? "");
    const up = p.user_profiles as
      | { full_name?: string | null; username?: string | null; avatar_url?: string | null }
      | undefined;
    const displayName = profileName(up);
    const done = contributions[userId] ?? 0;
    const pct = milestonesCount > 0 ? Math.round((done / milestonesCount) * 100) : 0;
    return {
      userId,
      displayName,
      avatarUrl: (up?.avatar_url as string | null | undefined) ?? null,
      contributionPct: Math.min(100, Math.max(0, pct)),
      isCreator: userId === authorUserId,
    };
  });
  items.sort((a, b) => {
    if (b.contributionPct !== a.contributionPct) return b.contributionPct - a.contributionPct;
    if (a.isCreator !== b.isCreator) return a.isCreator ? -1 : 1;
    return a.displayName.localeCompare(b.displayName);
  });
  return items;
}

export function formatGoalForList(
  goal: Record<string, unknown>,
  opts?: { isJoined?: boolean }
): GoalForList {
  const rawMilestones = Array.isArray(goal.goal_milestones)
    ? (goal.goal_milestones as GoalMilestone[])
    : [];
  const milestones = sortMilestones(rawMilestones);
  const progress = calcProgress(milestones);
  const { name } = readProfile(goal);
  const participants = Array.isArray(goal.community_goal_participants)
    ? (goal.community_goal_participants as unknown[]).length
    : 0;

  return {
    id: String(goal.id ?? ""),
    title: String(goal.title ?? ""),
    description: goal.description != null ? String(goal.description) : null,
    goal_type: String(goal.goal_type ?? ""),
    status: goal.status != null ? String(goal.status) : null,
    deadline_date: String(goal.deadline_date ?? ""),
    progress,
    authorName: name,
    authorUserId: String(goal.user_id ?? ""),
    participantsCount: participants,
    milestones,
    isJoined: opts?.isJoined,
  };
}

async function fetchJoinedCommunityGoalIds(userId: string): Promise<Set<string>> {
  const { data, error } = await supabase
    .from("community_goal_participants")
    .select("goal_id")
    .eq("user_id", userId);
  if (error || !data) return new Set();
  return new Set(data.map((r) => String((r as { goal_id: string }).goal_id)));
}

export async function loadCommunityProjectsForList(): Promise<{
  goals: GoalForList[];
  error: string | null;
}> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { goals: [], error: "Not signed in." };

  const { data, error } = await supabase
    .from("goals")
    .select(COMMUNITY_LIST_SELECT as never)
    .eq("goal_type", "community")
    .order("created_at", { ascending: false });

  if (error) return { goals: [], error: error.message };

  const joined = await fetchJoinedCommunityGoalIds(user.id);
  const rows = (data ?? []) as unknown as Record<string, unknown>[];
  const goals = rows.map((g) =>
    formatGoalForList(g, { isJoined: joined.has(String(g.id)) })
  );
  return { goals, error: null };
}

export async function loadFarmProjectsForList(): Promise<{
  goals: GoalForList[];
  error: string | null;
}> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { goals: [], error: "Not signed in." };

  const { data, error } = await supabase
    .from("goals")
    .select(FARM_SELECT as never)
    .eq("user_id", user.id)
    .eq("goal_type", "personal")
    .order("created_at", { ascending: false });

  if (error) return { goals: [], error: error.message };
  const rows = (data ?? []) as unknown as Record<string, unknown>[];
  return { goals: rows.map((g) => formatGoalForList(g)), error: null };
}

export async function joinCommunityProject(goalId: string): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in." };
  const { error } = await supabase.from("community_goal_participants").insert({
    goal_id: goalId,
    user_id: user.id,
  });
  return { error: error?.message ?? null };
}

export async function leaveCommunityProject(goalId: string): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in." };
  const { error } = await supabase
    .from("community_goal_participants")
    .delete()
    .eq("goal_id", goalId)
    .eq("user_id", user.id);
  return { error: error?.message ?? null };
}

export async function loadGoalDetail(goalId: string): Promise<{
  goal: GoalDetail | null;
  error: string | null;
}> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { goal: null, error: "Not signed in." };

  const { data: head, error: he } = await supabase.from("goals").select("goal_type, user_id").eq("id", goalId).maybeSingle();
  if (he) return { goal: null, error: he.message };
  if (!head) return { goal: null, error: "Project not found." };
  const headRow = head as { goal_type?: string; user_id?: string };
  const typeEarly = String(headRow.goal_type ?? "");
  if (typeEarly === "personal" && String(headRow.user_id) !== user.id) {
    const access = await getEffectiveStaffAccess(user.id, user.email ?? undefined);
    if (!isSuperEffective(access)) {
      return { goal: null, error: "You can only open your own farm projects here." };
    }
  }

  const detailSelect = typeEarly === "community" ? COMMUNITY_LIST_SELECT : FARM_SELECT;
  const { data, error } = await supabase.from("goals").select(detailSelect as never).eq("id", goalId).maybeSingle();

  if (error) return { goal: null, error: error.message };
  if (!data) return { goal: null, error: "Project not found." };

  const row = data as unknown as Record<string, unknown>;
  const type = String(row.goal_type ?? "");

  const joined = type === "community" ? (await fetchJoinedCommunityGoalIds(user.id)).has(goalId) : false;
  const formatted = formatGoalForList(row, { isJoined: joined });
  const contributions = await fetchMilestoneContributionsByUser(goalId);
  const circleRoles = type === "community" ? await fetchCircleRolesForGoal(goalId) : undefined;
  const participants =
    type === "community"
      ? buildCommunityParticipants(row, formatted.authorUserId, formatted.milestones.length, contributions)
      : undefined;

  const goal: GoalDetail =
    type === "community"
      ? {
          ...formatted,
          circleRoles: circleRoles ?? [],
          participants: participants ?? [],
        }
      : { ...formatted };
  return { goal, error: null };
}

export async function setMilestoneCompleted(
  milestoneId: string,
  completed: boolean
): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in." };

  const { error: upErr } = await supabase
    .from("goal_milestones")
    .update({
      completed,
      completed_at: completed ? new Date().toISOString() : null,
    })
    .eq("id", milestoneId);

  if (upErr) return { error: upErr.message };

  if (completed) {
    await supabase.from("milestone_completions").delete().eq("milestone_id", milestoneId).eq("user_id", user.id);
    const { error: insErr } = await supabase.from("milestone_completions").insert({
      milestone_id: milestoneId,
      user_id: user.id,
      completed_at: new Date().toISOString(),
    });
    if (insErr) return { error: insErr.message };
  } else {
    const { error: delErr } = await supabase
      .from("milestone_completions")
      .delete()
      .eq("milestone_id", milestoneId)
      .eq("user_id", user.id);
    if (delErr) return { error: delErr.message };
  }

  return { error: null };
}

export async function setGoalCompletion(goalId: string, completed: boolean): Promise<{ error: string | null }> {
  const { error } = await supabase
    .from("goals")
    .update({
      status: completed ? "completed" : "active",
      updated_at: new Date().toISOString(),
    })
    .eq("id", goalId);
  return { error: error?.message ?? null };
}

export function formatGoalDeadlineLabel(deadlineDate: string): string {
  const d = new Date(deadlineDate);
  if (Number.isNaN(d.getTime())) return deadlineDate;
  return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
}

export async function createCommunityGoal(input: {
  title: string;
  description?: string | null;
  deadline_date: string;
}): Promise<{ goalId: string | null; error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { goalId: null, error: "Not signed in." };
  const title = input.title.trim();
  if (!title) return { goalId: null, error: "Title is required." };
  const deadline = input.deadline_date.trim();
  if (!deadline) return { goalId: null, error: "Deadline is required." };

  const { data, error } = await supabase
    .from("goals")
    .insert({
      user_id: user.id,
      goal_type: "community",
      title,
      description: input.description?.trim() || null,
      deadline_date: deadline,
      status: "active",
    })
    .select("id")
    .single();

  if (error || !data) return { goalId: null, error: error?.message ?? "Could not create project." };
  return { goalId: String((data as { id: string }).id), error: null };
}

export async function createFarmProject(input: {
  title: string;
  description?: string | null;
  deadline_date: string;
  milestoneLines: string[];
}): Promise<{ goalId: string | null; error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { goalId: null, error: "Not signed in." };
  const title = input.title.trim();
  if (!title) return { goalId: null, error: "Title is required." };
  const deadline = input.deadline_date.trim();
  if (!deadline) return { goalId: null, error: "Deadline is required." };
  const labels = input.milestoneLines.map((s) => s.trim()).filter(Boolean);
  if (labels.length === 0) return { goalId: null, error: "Add at least one milestone (one per line)." };

  const { data, error } = await supabase
    .from("goals")
    .insert({
      user_id: user.id,
      goal_type: "personal",
      title,
      description: input.description?.trim() || null,
      deadline_date: deadline,
      status: "active",
    })
    .select("id")
    .single();

  if (error || !data) return { goalId: null, error: error?.message ?? "Could not create project." };
  const goalId = String((data as { id: string }).id);

  const rows = labels.map((label, i) => ({
    goal_id: goalId,
    title: label,
    description: "",
    completed: false,
    position: i,
  }));
  const { error: mErr } = await supabase.from("goal_milestones").insert(rows);
  if (mErr) {
    await supabase.from("goals").delete().eq("id", goalId);
    return { goalId: null, error: mErr.message };
  }
  return { goalId, error: null };
}

export async function deleteCommunityGoalAsSuperAdmin(goalId: string): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in." };
  const access = await getEffectiveStaffAccess(user.id, user.email ?? undefined);
  if (!isSuperEffective(access)) {
    return { error: "Only super admins can delete another member's community project here." };
  }

  const { data: row, error: he } = await supabase.from("goals").select("id, goal_type").eq("id", goalId).maybeSingle();
  if (he) return { error: he.message };
  if (!row) return { error: "Project not found." };
  if (String((row as { goal_type?: string }).goal_type) !== "community") {
    return { error: "This action only applies to community projects." };
  }

  const { data: docs, error: dErr } = await supabase.from("goal_documents").select("file_url").eq("goal_id", goalId);
  if (!dErr && docs?.length) {
    for (const d of docs as { file_url: string }[]) {
      const storagePath = extractStoragePathFromPublicUrl(d.file_url, "goal-repository");
      if (storagePath) {
        await supabase.storage.from("goal-repository").remove([storagePath]);
      }
    }
  }

  const { error } = await supabase.from("goals").delete().eq("id", goalId);
  return { error: error?.message ?? null };
}

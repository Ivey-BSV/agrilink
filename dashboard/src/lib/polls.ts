import { supabase } from "@/lib/supabase";

export type PollOptionRow = { id: string; label: string; position: number | null };
export type PollListRow = {
  id: string;
  title: string;
  description: string | null;
  status: string;
  allows_multiple: boolean;
  closes_at: string | null;
  created_at: string;
  poll_options?: { id: string }[] | null;
};

export type PollDetail = {
  id: string;
  title: string;
  description: string | null;
  status: string;
  allows_multiple: boolean;
  closes_at: string | null;
  created_by: string;
  poll_options: PollOptionRow[];
};

export async function listPollsForWeb(): Promise<{ rows: PollListRow[]; error: string | null }> {
  const { data, error } = await supabase
    .from("polls")
    .select(
      `
      id, title, description, status, allows_multiple, closes_at, created_at,
      poll_options ( id )
    `
    )
    .order("created_at", { ascending: false });
  if (error) return { rows: [], error: error.message };
  const rows = (data ?? []) as unknown as PollListRow[];
  return { rows, error: null };
}

export async function getPollDetail(pollId: string): Promise<{ poll: PollDetail | null; error: string | null }> {
  const { data, error } = await supabase
    .from("polls")
    .select(
      `
      id, title, description, status, allows_multiple, closes_at, created_by,
      poll_options ( id, label, position )
    `
    )
    .eq("id", pollId)
    .maybeSingle();
  if (error) return { poll: null, error: error.message };
  if (!data) return { poll: null, error: "Poll not found." };
  const row = data as Record<string, unknown>;
  const opts = Array.isArray(row.poll_options) ? row.poll_options : [];
  const poll: PollDetail = {
    id: String(row.id),
    title: String(row.title ?? ""),
    description: row.description != null ? String(row.description) : null,
    status: String(row.status ?? "active"),
    allows_multiple: Boolean(row.allows_multiple),
    closes_at: row.closes_at != null ? String(row.closes_at) : null,
    created_by: String(row.created_by ?? ""),
    poll_options: opts
      .map((o) => ({
        id: String((o as { id: string }).id),
        label: String((o as { label: string }).label),
        position: (o as { position?: number | null }).position ?? null,
      }))
      .sort((a, b) => (a.position ?? 0) - (b.position ?? 0)),
  };
  return { poll, error: null };
}

export async function getMyVotesForPoll(pollId: string): Promise<{ optionIds: string[]; error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { optionIds: [], error: "Not signed in." };
  const { data, error } = await supabase.from("poll_votes").select("option_id").eq("poll_id", pollId).eq("user_id", user.id);
  if (error) return { optionIds: [], error: error.message };
  return { optionIds: (data ?? []).map((r) => String((r as { option_id: string }).option_id)), error: null };
}

export async function submitPollVote(pollId: string, optionIds: string[]): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in." };

  const { poll, error: pe } = await getPollDetail(pollId);
  if (pe || !poll) return { error: pe || "Poll not found." };
  if (poll.status !== "active") return { error: "This poll is closed." };
  if (poll.closes_at) {
    const end = new Date(poll.closes_at);
    if (!Number.isNaN(end.getTime()) && end.getTime() <= Date.now()) return { error: "This poll has ended." };
  }
  const valid = new Set(poll.poll_options.map((o) => o.id));
  for (const id of optionIds) {
    if (!valid.has(id)) return { error: "Invalid option." };
  }
  if (!poll.allows_multiple && optionIds.length > 1) return { error: "This poll only allows one answer." };

  const { error: delErr } = await supabase.from("poll_votes").delete().eq("poll_id", pollId).eq("user_id", user.id);
  if (delErr) return { error: delErr.message };

  if (optionIds.length === 0) return { error: null };

  const rows = optionIds.map((option_id) => ({
    poll_id: pollId,
    user_id: user.id,
    option_id,
  }));
  const { error: insErr } = await supabase.from("poll_votes").insert(rows);
  return { error: insErr?.message ?? null };
}

export type PollAdminPatch = {
  title?: string;
  description?: string | null;
  status?: "active" | "closed";
  allows_multiple?: boolean;
  closes_at?: string | null;
};

export async function createPollWithOptions(input: {
  title: string;
  description?: string | null;
  allows_multiple: boolean;
  closes_at?: string | null;
  optionLabels: string[];
}): Promise<{ pollId: string | null; error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { pollId: null, error: "Not signed in." };

  const labels = input.optionLabels.map((s) => s.trim()).filter(Boolean);
  if (labels.length < 2) return { pollId: null, error: "Add at least two answer options." };

  const { data: pollRow, error: insPoll } = await supabase
    .from("polls")
    .insert({
      created_by: user.id,
      title: input.title.trim(),
      description: input.description?.trim() || null,
      allows_multiple: input.allows_multiple,
      status: "active",
      closes_at: input.closes_at?.trim() || null,
    })
    .select("id")
    .single();

  if (insPoll || !pollRow) return { pollId: null, error: insPoll?.message ?? "Could not create poll." };

  const pollId = String((pollRow as { id: string }).id);
  const optionRows = labels.map((label, i) => ({
    poll_id: pollId,
    label,
    position: i,
  }));
  const { error: optErr } = await supabase.from("poll_options").insert(optionRows);
  if (optErr) {
    await supabase.from("polls").delete().eq("id", pollId);
    return { pollId: null, error: optErr.message };
  }
  return { pollId, error: null };
}

export async function updatePollRecord(pollId: string, patch: PollAdminPatch): Promise<{ error: string | null }> {
  const payload: Record<string, unknown> = {};
  if (patch.title !== undefined) payload.title = patch.title.trim();
  if (patch.description !== undefined) payload.description = patch.description?.trim() ?? null;
  if (patch.status !== undefined) payload.status = patch.status;
  if (patch.allows_multiple !== undefined) payload.allows_multiple = patch.allows_multiple;
  if (patch.closes_at !== undefined) payload.closes_at = patch.closes_at?.trim() || null;
  if (Object.keys(payload).length === 0) return { error: null };
  payload.updated_at = new Date().toISOString();
  const { error } = await supabase.from("polls").update(payload).eq("id", pollId);
  return { error: error?.message ?? null };
}

export async function deletePollById(pollId: string): Promise<{ error: string | null }> {
  const { error } = await supabase.from("polls").delete().eq("id", pollId);
  return { error: error?.message ?? null };
}

async function deleteAllVotesForPoll(pollId: string): Promise<{ error: string | null }> {
  const { error } = await supabase.from("poll_votes").delete().eq("poll_id", pollId);
  return { error: error?.message ?? null };
}

async function deleteAllOptionsForPoll(pollId: string): Promise<{ error: string | null }> {
  const { error } = await supabase.from("poll_options").delete().eq("poll_id", pollId);
  return { error: error?.message ?? null };
}

async function insertPollOptions(
  pollId: string,
  labels: string[],
): Promise<{ error: string | null }> {
  const cleaned = labels.map((s) => s.trim()).filter(Boolean);
  if (cleaned.length < 2) return { error: "At least two options are required." };
  const rows = cleaned.map((label, i) => ({
    poll_id: pollId,
    label,
    position: i,
  }));
  const { error } = await supabase.from("poll_options").insert(rows);
  return { error: error?.message ?? null };
}

export async function replacePollOptionsKeepingPoll(
  pollId: string,
  labels: string[],
): Promise<{ error: string | null }> {
  const v = await deleteAllVotesForPoll(pollId);
  if (v.error) return v;
  const d = await deleteAllOptionsForPoll(pollId);
  if (d.error) return d;
  return insertPollOptions(pollId, labels);
}

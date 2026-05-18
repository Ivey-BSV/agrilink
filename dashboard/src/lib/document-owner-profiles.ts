import type { SupabaseClient } from "@supabase/supabase-js";

function formatProfileUploaderLabel(p: {
  full_name: string | null;
  username: string | null;
}): string {
  const fn = p.full_name?.trim();
  if (fn) return fn;
  const u = p.username?.trim();
  if (u) return `@${u}`;
  return "";
}

export async function fetchUploaderLabelByUserIds(
  supabase: SupabaseClient,
  userIds: string[]
): Promise<Record<string, string>> {
  const ids = [...new Set(userIds)].filter(Boolean);
  const map: Record<string, string> = {};
  if (!ids.length) return map;

  const { data, error } = await supabase.from("user_profiles").select("id, full_name, username").in("id", ids);

  if (error || !data) {
    for (const id of ids) {
      map[id] = `Member (${id.slice(0, 8)}…)`;
    }
    return map;
  }

  const rows = data as { id: string; full_name: string | null; username: string | null }[];
  for (const id of ids) {
    const row = rows.find((r) => r.id === id);
    const label = row ? formatProfileUploaderLabel(row) : "";
    map[id] = label || `Member (${id.slice(0, 8)}…)`;
  }
  return map;
}

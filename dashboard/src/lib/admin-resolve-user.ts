import type { SupabaseClient } from "@supabase/supabase-js";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function escapeIlikeLiteral(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/%/g, "\\%").replace(/_/g, "\\_");
}

export async function resolveUserProfileId(
  supabase: SupabaseClient,
  raw: string,
): Promise<{ id: string } | { error: string }> {
  const t = raw.trim();
  if (!t) return { error: "Enter a user id or username." };

  if (UUID_RE.test(t)) {
    const { data, error } = await supabase.from("user_profiles").select("id").eq("id", t).maybeSingle();
    if (error) return { error: error.message };
    if (!data) return { error: "No profile found for that user id." };
    return { id: data.id };
  }

  const u = t.startsWith("@") ? t.slice(1).trim() : t;
  if (!u) return { error: "Enter a username." };

  const { data: exact } = await supabase.from("user_profiles").select("id").eq("username", u).maybeSingle();
  if (exact) return { id: exact.id };

  const literal = escapeIlikeLiteral(u);
  const { data: rows, error: e2 } = await supabase.from("user_profiles").select("id").ilike("username", literal);
  if (e2) return { error: e2.message };
  if (!rows?.length) return { error: "No user found with that username." };
  if (rows.length > 1) return { error: "Multiple profiles match; use the UUID from Supabase." };
  return { id: rows[0].id };
}

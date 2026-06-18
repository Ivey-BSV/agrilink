import type { SupabaseClient } from "@supabase/supabase-js";
import { normalizeUsername } from "@/lib/username";

export async function resolveEmailForPasswordSignIn(
  supabase: SupabaseClient,
  usernameOrEmail: string,
): Promise<string> {
  const t = usernameOrEmail.trim();
  if (!t) {
    throw new Error("Enter your email or username.");
  }
  if (t.includes("@")) {
    return t;
  }
  const normalized = normalizeUsername(t);
  if (!normalized) {
    throw new Error("Enter a valid username.");
  }
  const { data, error } = await supabase.rpc("get_email_by_username", { username_param: normalized });
  if (error) {
    throw new Error(error.message);
  }
  const email = data != null && String(data).trim() !== "" ? String(data).trim() : "";
  if (!email) {
    throw new Error("No account found for that username.");
  }
  return email;
}

export async function resetPasswordViaEdgeFunction(
  supabase: SupabaseClient,
  opts: { usernameOrEmail: string; code: string; newPassword: string },
): Promise<void> {
  const raw = opts.usernameOrEmail.trim();
  const usernameOrEmail = raw.includes("@") ? raw : normalizeUsername(raw);
  if (!usernameOrEmail) {
    throw new Error("Enter your email or username.");
  }
  const { data, error } = await supabase.functions.invoke("reset_password", {
    body: {
      usernameOrEmail,
      code: opts.code.trim(),
      new_password: opts.newPassword,
    },
    headers: {
      Authorization: `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? ""}`,
    },
  });
  if (error) {
    throw new Error(error.message);
  }
  const payload = data as { error?: string } | null;
  if (payload && typeof payload === "object" && payload.error) {
    throw new Error(String(payload.error));
  }
}

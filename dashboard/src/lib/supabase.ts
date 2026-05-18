import { createClient } from "@supabase/supabase-js";

const fallbackUrl = "https://placeholder.supabase.co";
const fallbackAnonKey = "placeholder-anon-key";

function resolveSupabaseUrl() {
  return (
    process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ||
    process.env.SUPABASE_URL?.trim() ||
    fallbackUrl
  );
}

function resolveSupabaseAnonKey() {
  return (
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ||
    process.env.SUPABASE_ANON_KEY?.trim() ||
    fallbackAnonKey
  );
}

const supabaseUrl = resolveSupabaseUrl();
const supabaseAnonKey = resolveSupabaseAnonKey();

const usingPlaceholders =
  supabaseUrl === fallbackUrl || supabaseAnonKey === fallbackAnonKey;

if (usingPlaceholders && typeof window !== "undefined") {
  throw new Error(
    "Missing Supabase credentials. Add SUPABASE_URL and SUPABASE_ANON_KEY to the repo root .env file."
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

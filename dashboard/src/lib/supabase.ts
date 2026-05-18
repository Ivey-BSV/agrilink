import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

const fallbackUrl = "https://placeholder.supabase.co";
const fallbackAnonKey = "placeholder-anon-key";

if ((!supabaseUrl || !supabaseAnonKey) && typeof window !== "undefined") {
  throw new Error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY in dashboard env."
  );
}

export const supabase = createClient(
  supabaseUrl ?? fallbackUrl,
  supabaseAnonKey ?? fallbackAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    },
  },
);


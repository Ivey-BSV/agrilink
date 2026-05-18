import { supabase } from "@/lib/supabase";

export async function runAdminOperation<T = unknown>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke("admin_operations", { body });
  if (error) {
    throw new Error(error.message);
  }
  const payload = data as { error?: string } | null;
  if (payload && typeof payload === "object" && "error" in payload && payload.error) {
    throw new Error(String(payload.error));
  }
  return data as T;
}

import { supabase } from "@/lib/supabase";

export type FarmDetailsSummary = {
  id?: string;
  farm_name: string | null;
  farm_overview: string | null;
};

export async function loadFarmDetailsSummary(userId: string): Promise<{
  row: FarmDetailsSummary | null;
  error: string | null;
}> {
  const { data, error } = await supabase.from("farm_details").select("id, farm_name, farm_overview").eq("user_id", userId).maybeSingle();
  if (error) return { row: null, error: error.message };
  return { row: (data as FarmDetailsSummary) ?? null, error: null };
}

export async function upsertFarmDetailsSummary(
  userId: string,
  patch: { farm_name: string | null; farm_overview: string | null }
): Promise<{ error: string | null }> {
  const payload = {
    user_id: userId,
    farm_name: patch.farm_name,
    farm_overview: patch.farm_overview,
    updated_at: new Date().toISOString(),
  };
  const { data: existing, error: selErr } = await supabase.from("farm_details").select("id").eq("user_id", userId).maybeSingle();
  if (selErr) return { error: selErr.message };
  if (existing) {
    const { error } = await supabase.from("farm_details").update(payload).eq("user_id", userId);
    return { error: error?.message ?? null };
  }
  const { error } = await supabase.from("farm_details").insert(payload);
  return { error: error?.message ?? null };
}

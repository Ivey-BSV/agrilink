import { supabase } from "@/lib/supabase";

export type FarmDetailsSummary = {
  id?: string;
  farm_name: string | null;
  farm_overview: string | null;
};

export type FarmDetailsRow = FarmDetailsSummary & {
  farm_size: number | null;
  farm_size_unit: string | null;
  crops: string[] | null;
  livestock: string[] | null;
  soil_type: string | null;
  irrigation_method: string | null;
  farming_method: string | null;
  certification: string | null;
  established_date: string | null;
  farm_type: string[] | null;
  farm_scale: string | null;
  activities: string[] | null;
  specializations: string[] | null;
  is_open_farm: boolean | null;
};

export async function loadFarmDetailsSummary(userId: string): Promise<{
  row: FarmDetailsSummary | null;
  error: string | null;
}> {
  const { data, error } = await supabase.from("farm_details").select("id, farm_name, farm_overview").eq("user_id", userId).maybeSingle();
  if (error) return { row: null, error: error.message };
  return { row: (data as FarmDetailsSummary) ?? null, error: null };
}

export async function loadFarmDetailsFull(userId: string): Promise<{
  row: FarmDetailsRow | null;
  error: string | null;
}> {
  const { data, error } = await supabase.from("farm_details").select("*").eq("user_id", userId).maybeSingle();
  if (error) return { row: null, error: error.message };
  return { row: (data as FarmDetailsRow) ?? null, error: null };
}

export function formatFarmLabel(value: string): string {
  return value
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
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

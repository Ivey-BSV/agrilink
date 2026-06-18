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
  farm_goals: string[] | null;
  value_added_products: string[] | null;
  is_open_farm: boolean | null;
  agritourism_offerings: string[] | null;
  farm_accessibility: string | null;
  visitor_guidelines: string | null;
  highway_exit: string | null;
  highway_directions: string | null;
  signage_info: string | null;
};

const FARM_TYPE_LABELS: Record<string, string> = {
  cash_crops: "Cash Crops",
  specialty_crops: "Specialty Crops",
  livestock: "Livestock",
  mixed: "Mixed Operation",
  homestead: "Homestead",
};

export async function loadFarmDetailsFull(userId: string): Promise<{
  row: FarmDetailsRow | null;
  error: string | null;
}> {
  const { data, error } = await supabase.from("farm_details").select("*").eq("user_id", userId).maybeSingle();
  if (error) return { row: null, error: error.message };
  return { row: (data as FarmDetailsRow) ?? null, error: null };
}

export function formatFarmLabel(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return value;
  return trimmed
    .split("_")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

export function formatFarmTypeLabel(type: string): string {
  return FARM_TYPE_LABELS[type] ?? formatFarmLabel(type);
}

export function formatFarmEstablishedDate(value: string | null | undefined): string {
  if (!value?.trim()) return "";
  const d = new Date(value.trim());
  if (Number.isNaN(d.getTime())) return value.trim();
  return d.toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" });
}


export function formatFarmListItems(items: string[]): string {
  return items
    .map((item) => {
      const t = item.trim();
      if (!t) return "";
      return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase();
    })
    .filter(Boolean)
    .join(", ");
}

export function formatFarmListLabels(items: string[]): string {
  return items.map((item) => formatFarmLabel(item)).join(", ");
}

export function hasFarmDetailsContent(farm: FarmDetailsRow | null): boolean {
  if (!farm) return false;
  return Boolean(
    farm.farm_overview?.trim() ||
      farm.farm_name?.trim() ||
      farm.farm_size ||
      farm.farm_size_unit ||
      (farm.crops?.length ?? 0) > 0 ||
      (farm.livestock?.length ?? 0) > 0 ||
      farm.farming_method ||
      farm.soil_type ||
      farm.irrigation_method ||
      farm.certification ||
      farm.established_date ||
      farm.farm_scale ||
      (farm.farm_type?.length ?? 0) > 0 ||
      (farm.activities?.length ?? 0) > 0 ||
      (farm.specializations?.length ?? 0) > 0 ||
      (farm.farm_goals?.length ?? 0) > 0 ||
      (farm.value_added_products?.length ?? 0) > 0 ||
      farm.is_open_farm ||
      (farm.agritourism_offerings?.length ?? 0) > 0 ||
      farm.farm_accessibility?.trim() ||
      farm.visitor_guidelines?.trim() ||
      farm.highway_exit?.trim() ||
      farm.highway_directions?.trim() ||
      farm.signage_info?.trim()
  );
}

export type FarmDetailEntry = { label: string; value: string };


export function buildFarmDetailEntries(farm: FarmDetailsRow): FarmDetailEntry[] {
  const rows: FarmDetailEntry[] = [];

  if (farm.farm_overview?.trim()) {
    rows.push({ label: "Farm overview", value: farm.farm_overview.trim() });
  }
  if (farm.farm_name?.trim()) {
    rows.push({ label: "Farm name", value: farm.farm_name.trim() });
  }
  if (farm.farm_size != null && farm.farm_size_unit) {
    const unit = farm.farm_size_unit.charAt(0).toUpperCase() + farm.farm_size_unit.slice(1);
    rows.push({ label: "Farm size", value: `${farm.farm_size} ${unit}` });
  }
  if (farm.established_date) {
    const formatted = formatFarmEstablishedDate(farm.established_date);
    if (formatted) rows.push({ label: "Established date", value: formatted });
  }
  if (farm.farming_method?.trim()) {
    rows.push({ label: "Farming method", value: formatFarmLabel(farm.farming_method) });
  }
  if (farm.soil_type?.trim()) {
    rows.push({ label: "Soil type", value: formatFarmLabel(farm.soil_type) });
  }
  if (farm.irrigation_method?.trim()) {
    rows.push({ label: "Irrigation", value: formatFarmLabel(farm.irrigation_method) });
  }
  if (farm.crops?.length) {
    rows.push({ label: "Primary crops", value: formatFarmListItems(farm.crops) });
  }
  if (farm.livestock?.length) {
    rows.push({ label: "Livestock", value: formatFarmListItems(farm.livestock) });
  }
  if (farm.farm_type?.length) {
    rows.push({ label: "Farm types", value: farm.farm_type.map(formatFarmTypeLabel).join(", ") });
  }
  if (farm.activities?.length) {
    rows.push({ label: "Activities", value: formatFarmListLabels(farm.activities) });
  }
  if (farm.specializations?.length) {
    rows.push({ label: "Specializations", value: formatFarmListLabels(farm.specializations) });
  }
  if (farm.farm_goals?.length) {
    rows.push({ label: "Farm goals", value: formatFarmListLabels(farm.farm_goals) });
  }
  if (farm.value_added_products?.length) {
    rows.push({ label: "Value-added products", value: formatFarmListLabels(farm.value_added_products) });
  }
  if (farm.is_open_farm) {
    rows.push({ label: "Open farm", value: "Visitors welcome" });
  }
  if (farm.agritourism_offerings?.length) {
    rows.push({ label: "Agritourism", value: formatFarmListLabels(farm.agritourism_offerings) });
  }
  if (farm.farm_accessibility?.trim()) {
    rows.push({ label: "Accessibility", value: farm.farm_accessibility.trim() });
  }
  if (farm.visitor_guidelines?.trim()) {
    rows.push({ label: "Visitor guidelines", value: farm.visitor_guidelines.trim() });
  }
  if (farm.highway_exit?.trim()) {
    rows.push({ label: "Highway exit", value: farm.highway_exit.trim() });
  }
  if (farm.highway_directions?.trim()) {
    rows.push({ label: "Directions", value: farm.highway_directions.trim() });
  }
  if (farm.signage_info?.trim()) {
    rows.push({ label: "Signage", value: farm.signage_info.trim() });
  }

  return rows;
}

export type FarmDetailsDraft = {
  farm_overview: string;
  farm_name: string;
  farm_size: string;
  farm_size_unit: string;
  farming_method: string;
  soil_type: string;
  irrigation_method: string;
  certification: string;
  farm_scale: string;
  established_date: string;
  crops: string[];
  livestock: string[];
  farm_type: string[];
  activities: string[];
  specializations: string[];
  farm_goals: string[];
  value_added_products: string[];
  is_open_farm: boolean;
  agritourism_offerings: string[];
  farm_accessibility: string;
  visitor_guidelines: string;
  highway_exit: string;
  highway_directions: string;
  signage_info: string;
};

export function emptyFarmDetailsDraft(): FarmDetailsDraft {
  return {
    farm_overview: "",
    farm_name: "",
    farm_size: "",
    farm_size_unit: "acres",
    farming_method: "",
    soil_type: "",
    irrigation_method: "",
    certification: "",
    farm_scale: "",
    established_date: "",
    crops: [],
    livestock: [],
    farm_type: [],
    activities: [],
    specializations: [],
    farm_goals: [],
    value_added_products: [],
    is_open_farm: false,
    agritourism_offerings: [],
    farm_accessibility: "",
    visitor_guidelines: "",
    highway_exit: "",
    highway_directions: "",
    signage_info: "",
  };
}

function toIsoDateOnly(value: string): string | null {
  const t = value.trim();
  if (!t) return null;
  const d = new Date(t);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

export function farmDetailsRowToDraft(row: FarmDetailsRow | null): FarmDetailsDraft {
  const base = emptyFarmDetailsDraft();
  if (!row) return base;

  let established = "";
  if (row.established_date) {
    const d = new Date(row.established_date);
    if (!Number.isNaN(d.getTime())) {
      established = d.toISOString().slice(0, 10);
    }
  }

  return {
    farm_overview: row.farm_overview?.trim() ?? "",
    farm_name: row.farm_name?.trim() ?? "",
    farm_size: row.farm_size != null ? String(row.farm_size) : "",
    farm_size_unit: row.farm_size_unit?.trim() || "acres",
    farming_method: row.farming_method?.trim() ?? "",
    soil_type: row.soil_type?.trim() ?? "",
    irrigation_method: row.irrigation_method?.trim() ?? "",
    certification: row.certification?.trim() ?? "",
    farm_scale: row.farm_scale?.trim() ?? "",
    established_date: established,
    crops: row.crops ?? [],
    livestock: row.livestock ?? [],
    farm_type: row.farm_type ?? [],
    activities: row.activities ?? [],
    specializations: row.specializations ?? [],
    farm_goals: row.farm_goals ?? [],
    value_added_products: row.value_added_products ?? [],
    is_open_farm: Boolean(row.is_open_farm),
    agritourism_offerings: row.agritourism_offerings ?? [],
    farm_accessibility: row.farm_accessibility?.trim() ?? "",
    visitor_guidelines: row.visitor_guidelines?.trim() ?? "",
    highway_exit: row.highway_exit?.trim() ?? "",
    highway_directions: row.highway_directions?.trim() ?? "",
    signage_info: row.signage_info?.trim() ?? "",
  };
}

function draftField(value: string): string | null {
  const t = value.trim();
  return t.length > 0 ? t : null;
}

export async function saveFarmDetailsFull(
  userId: string,
  draft: FarmDetailsDraft
): Promise<{ error: string | null }> {
  const sizeRaw = draft.farm_size.trim();
  const farmSize = sizeRaw ? parseInt(sizeRaw, 10) : null;
  if (sizeRaw && (farmSize == null || Number.isNaN(farmSize) || farmSize < 0)) {
    return { error: "Farm size must be a valid number." };
  }

  const payload: Record<string, unknown> = {
    user_id: userId,
    updated_at: new Date().toISOString(),
    farm_overview: draftField(draft.farm_overview),
    farm_name: draftField(draft.farm_name),
    farm_size: farmSize,
    farm_size_unit: draftField(draft.farm_size_unit) ?? (farmSize != null ? "acres" : null),
    farming_method: draftField(draft.farming_method),
    soil_type: draftField(draft.soil_type),
    irrigation_method: draftField(draft.irrigation_method),
    certification: draftField(draft.certification),
    farm_scale: draftField(draft.farm_scale),
    established_date: toIsoDateOnly(draft.established_date),
    crops: draft.crops.length ? draft.crops : null,
    livestock: draft.livestock.length ? draft.livestock : null,
    farm_type: draft.farm_type.length ? draft.farm_type : null,
    activities: draft.activities.length ? draft.activities : null,
    specializations: draft.specializations.length ? draft.specializations : null,
    farm_goals: draft.farm_goals.length ? draft.farm_goals : null,
    value_added_products: draft.value_added_products.length ? draft.value_added_products : null,
    is_open_farm: draft.is_open_farm,
    agritourism_offerings: draft.agritourism_offerings.length ? draft.agritourism_offerings : null,
    farm_accessibility: draftField(draft.farm_accessibility),
    visitor_guidelines: draftField(draft.visitor_guidelines),
    highway_exit: draftField(draft.highway_exit),
    highway_directions: draftField(draft.highway_directions),
    signage_info: draftField(draft.signage_info),
  };

  const { data: existing, error: selErr } = await supabase
    .from("farm_details")
    .select("id")
    .eq("user_id", userId)
    .maybeSingle();
  if (selErr) return { error: selErr.message };

  if (existing) {
    const { error } = await supabase.from("farm_details").update(payload).eq("user_id", userId);
    return { error: error?.message ?? null };
  }

  const { error } = await supabase.from("farm_details").insert(payload);
  return { error: error?.message ?? null };
}

export async function deleteFarmDetails(userId: string): Promise<{ error: string | null }> {
  const { error } = await supabase.from("farm_details").delete().eq("user_id", userId);
  return { error: error?.message ?? null };
}

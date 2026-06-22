import {
  formatFarmEstablishedDate,
  formatFarmLabel,
  formatFarmListItems,
  formatFarmListLabels,
  formatFarmTypeLabel,
  type FarmDetailsRow,
} from "@/lib/farm-details";
import { supabase } from "@/lib/supabase";

export type DirectoryProfile = {
  id: string;
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
  location: string | null;
  farm_type: string | null;
  experience_level: string | null;
  bio: string | null;
};

export type DirectoryEntry = {
  profile: DirectoryProfile;
  farm: FarmDetailsRow | null;
};

const FARM_SELECT =
  "user_id, farm_name, farm_overview, farm_size, farm_size_unit, established_date, farming_method, certification, farm_scale, crops, livestock, farm_type, activities";

const CHUNK = 80;

function joinDirectoryMeta(parts: (string | null | undefined)[]): string {
  return parts.map((p) => p?.trim()).filter(Boolean).join(" · ");
}

export function directoryProfileSubtitle(profile: DirectoryProfile): string {
  const username = profile.username?.trim();
  const location = profile.location?.trim();
  if (username && location) return `@${username} · ${location}`;
  if (username) return `@${username}`;
  if (location) return location;
  return "";
}

export function directoryFarmStatsLine(farm: FarmDetailsRow | null): string {
  if (!farm) return "";
  const size =
    farm.farm_size != null
      ? `${farm.farm_size} ${(farm.farm_size_unit?.trim() || "acres").toLowerCase()}`
      : null;
  const established = farm.established_date ? formatFarmEstablishedDate(farm.established_date) : null;
  const method = farm.farming_method?.trim() ? formatFarmLabel(farm.farming_method) : null;
  return joinDirectoryMeta([size, established, method]);
}

export function directoryCertificationLine(farm: FarmDetailsRow | null): string {
  if (!farm) return "";
  const cert = farm.certification?.trim() ? formatFarmLabel(farm.certification) : null;
  const scale = farm.farm_scale?.trim() ? formatFarmLabel(farm.farm_scale) : null;
  return joinDirectoryMeta([cert, scale]);
}

export type DirectoryDetailLine = { label: string; value: string };


export function directoryFarmDetailLines(farm: FarmDetailsRow | null): DirectoryDetailLine[] {
  if (!farm) return [];
  const lines: DirectoryDetailLine[] = [];
  if (farm.crops?.length) {
    lines.push({ label: "Crops", value: formatFarmListItems(farm.crops) });
  }
  if (farm.livestock?.length) {
    lines.push({ label: "Livestock", value: formatFarmListItems(farm.livestock) });
  }
  if (farm.farm_type?.length) {
    lines.push({ label: "Farm types", value: farm.farm_type.map(formatFarmTypeLabel).join(", ") });
  }
  if (farm.activities?.length) {
    lines.push({ label: "Activities", value: formatFarmListLabels(farm.activities) });
  }
  return lines;
}

export function directoryEntrySearchText(entry: DirectoryEntry): string {
  const { profile, farm } = entry;
  const parts = [
    profile.full_name,
    profile.username,
    profile.location,
    profile.farm_type,
    profile.experience_level,
    profile.bio,
    farm?.farm_name,
    farm?.farm_overview,
    farm?.farming_method,
    farm?.certification,
    farm?.farm_scale,
    farm?.farm_size != null ? String(farm.farm_size) : null,
    farm?.farm_size_unit,
    farm?.established_date,
    ...(farm?.crops ?? []),
    ...(farm?.livestock ?? []),
    ...(farm?.farm_type ?? []),
    ...(farm?.activities ?? []),
  ];
  return parts
    .filter(Boolean)
    .map((v) => String(v).toLowerCase())
    .join(" ");
}

export async function loadDirectoryEntries(): Promise<{
  entries: DirectoryEntry[];
  error: string | null;
}> {
  const { data: profiles, error: profileError } = await supabase
    .from("user_profiles")
    .select("id, full_name, username, avatar_url, location, farm_type, experience_level, bio")
    .order("created_at", { ascending: true })
    .limit(200);

  if (profileError) return { entries: [], error: profileError.message };

  const list = (profiles as DirectoryProfile[]) ?? [];
  if (list.length === 0) return { entries: [], error: null };

  const farmByUser = new Map<string, FarmDetailsRow>();
  const ids = list.map((p) => p.id);

  for (let i = 0; i < ids.length; i += CHUNK) {
    const chunk = ids.slice(i, i + CHUNK);
    const { data: farms, error: farmError } = await supabase.from("farm_details").select(FARM_SELECT).in("user_id", chunk);
    if (farmError) return { entries: [], error: farmError.message };
    for (const row of (farms ?? []) as (FarmDetailsRow & { user_id: string })[]) {
      farmByUser.set(row.user_id, row);
    }
  }

  const entries: DirectoryEntry[] = list.map((profile) => ({
    profile,
    farm: farmByUser.get(profile.id) ?? null,
  }));

  return { entries, error: null };
}

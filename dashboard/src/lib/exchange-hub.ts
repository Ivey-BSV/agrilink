import { parseImageUrls } from "@/lib/media-urls";
import { supabase } from "@/lib/supabase";

export type ExchangeHubListing = {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  condition: string | null;
  location: string | null;
  tags: string[];
  image_urls: string[];
  specifications: Record<string, string>;
  created_at: string;
  author: {
    id: string;
    full_name: string | null;
    username: string | null;
    avatar_url: string | null;
  };
};

export type ExchangeHubSpecRow = { id: string; label: string; value: string };

const LISTING_SELECT =
  "id, user_id, title, description, condition, tags, image_urls, specifications, location, created_at";

function parseStringArray(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw.map((v) => String(v).trim()).filter(Boolean);
  }
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (Array.isArray(parsed)) return parsed.map((v) => String(v).trim()).filter(Boolean);
    } catch {}
  }
  return [];
}

function parseSpecifications(raw: unknown): Record<string, string> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const k = key.trim();
    const v = value == null ? "" : String(value).trim();
    if (k && v) out[k] = v;
  }
  return out;
}

async function excludedUserIds(userId: string | null): Promise<Set<string>> {
  if (!userId) return new Set();
  const { data, error } = await supabase
    .from("user_blocks")
    .select("blocker_id, blocked_id")
    .or(`blocker_id.eq.${userId},blocked_id.eq.${userId}`);
  if (error || !data) return new Set();
  const excluded = new Set<string>();
  for (const row of data as { blocker_id: string; blocked_id: string }[]) {
    if (row.blocker_id === userId) excluded.add(row.blocked_id);
    else if (row.blocked_id === userId) excluded.add(row.blocker_id);
  }
  return excluded;
}

function authorFromProfile(
  userId: string,
  profile: { full_name?: string | null; username?: string | null; avatar_url?: string | null } | undefined,
) {
  return {
    id: userId,
    full_name: profile?.full_name ?? null,
    username: profile?.username ?? null,
    avatar_url: profile?.avatar_url ?? null,
  };
}

export function exchangeHubAuthorLabel(listing: ExchangeHubListing): string {
  return listing.author.full_name?.trim() || listing.author.username?.trim() || "Member";
}

export function exchangeHubPrimaryImage(listing: ExchangeHubListing): string | null {
  return listing.image_urls[0] ?? null;
}

export async function loadExchangeHubListings(): Promise<{
  listings: ExchangeHubListing[];
  error: string | null;
}> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const excluded = await excludedUserIds(user?.id ?? null);

  const { data, error } = await supabase
    .from("marketplace_listings")
    .select(LISTING_SELECT)
    .order("created_at", { ascending: false })
    .limit(120);

  if (error) return { listings: [], error: error.message };

  const rows = (data ?? []) as Record<string, unknown>[];
  const filtered = rows.filter((row) => !excluded.has(row.user_id as string));
  const userIds = [...new Set(filtered.map((row) => row.user_id as string))];

  const profiles = new Map<
    string,
    { full_name: string | null; username: string | null; avatar_url: string | null; location: string | null }
  >();
  if (userIds.length > 0) {
    const { data: profileRows } = await supabase
      .from("user_profiles")
      .select("id, full_name, username, avatar_url, location")
      .in("id", userIds);
    for (const p of (profileRows ?? []) as {
      id: string;
      full_name: string | null;
      username: string | null;
      avatar_url: string | null;
      location: string | null;
    }[]) {
      profiles.set(p.id, p);
    }
  }

  const listings: ExchangeHubListing[] = filtered.map((row) => {
    const userId = row.user_id as string;
    const profile = profiles.get(userId);
    return {
      id: row.id as string,
      user_id: userId,
      title: row.title as string,
      description: (row.description as string | null) ?? null,
      condition: (row.condition as string | null) ?? null,
      location: (row.location as string | null) ?? profile?.location ?? null,
      tags: parseStringArray(row.tags),
      image_urls: parseImageUrls(row.image_urls),
      specifications: parseSpecifications(row.specifications),
      created_at: row.created_at as string,
      author: authorFromProfile(userId, profile),
    };
  });

  return { listings, error: null };
}

export async function loadFavoriteListingIds(): Promise<Set<string>> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new Set();

  const { data, error } = await supabase
    .from("marketplace_favorites")
    .select("listing_id")
    .eq("user_id", user.id);

  if (error || !data) return new Set();
  return new Set((data as { listing_id: string }[]).map((row) => row.listing_id));
}

export async function toggleExchangeHubFavorite(listingId: string): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Sign in required." };

  const { data: existing } = await supabase
    .from("marketplace_favorites")
    .select("listing_id")
    .eq("user_id", user.id)
    .eq("listing_id", listingId)
    .maybeSingle();

  if (existing) {
    const { error } = await supabase
      .from("marketplace_favorites")
      .delete()
      .eq("user_id", user.id)
      .eq("listing_id", listingId);
    return { error: error?.message ?? null };
  }

  const { error } = await supabase.from("marketplace_favorites").insert({
    user_id: user.id,
    listing_id: listingId,
  });
  return { error: error?.message ?? null };
}

export async function uploadExchangeHubImage(file: File, userId: string): Promise<{ url: string | null; error: string | null }> {
  const safeName = file.name.replaceAll("/", "_");
  const path = `${userId}/${Date.now()}_${safeName}`;
  const { error } = await supabase.storage.from("marketplace-images").upload(path, file, {
    upsert: true,
    contentType: file.type || "image/jpeg",
  });
  if (error) return { url: null, error: error.message };
  const url = supabase.storage.from("marketplace-images").getPublicUrl(path).data.publicUrl;
  return { url, error: null };
}

export type CreateExchangeHubListingInput = {
  title: string;
  description: string;
  condition?: string | null;
  tags: string[];
  imageUrls: string[];
  specifications: Record<string, string>;
};

export async function createExchangeHubListing(
  input: CreateExchangeHubListingInput,
): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Sign in required." };

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("location")
    .eq("id", user.id)
    .maybeSingle();

  const { error } = await supabase.from("marketplace_listings").insert({
    user_id: user.id,
    title: input.title.trim(),
    price: "",
    description: input.description.trim(),
    condition: input.condition?.trim() || null,
    tags: input.tags,
    image_urls: input.imageUrls,
    specifications: input.specifications,
    location: (profile as { location?: string | null } | null)?.location ?? null,
  });

  return { error: error?.message ?? null };
}

export async function updateExchangeHubListing(
  listingId: string,
  input: CreateExchangeHubListingInput,
): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Sign in required." };

  const { error } = await supabase
    .from("marketplace_listings")
    .update({
      title: input.title.trim(),
      description: input.description.trim(),
      condition: input.condition?.trim() || null,
      tags: input.tags,
      image_urls: input.imageUrls,
      specifications: input.specifications,
      updated_at: new Date().toISOString(),
    })
    .eq("id", listingId)
    .eq("user_id", user.id);

  return { error: error?.message ?? null };
}

export async function deleteExchangeHubListing(listingId: string): Promise<{ error: string | null }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Sign in required." };

  const { error } = await supabase.from("marketplace_listings").delete().eq("id", listingId).eq("user_id", user.id);
  return { error: error?.message ?? null };
}

export function specificationsToRows(specs: Record<string, string>): ExchangeHubSpecRow[] {
  return Object.entries(specs).map(([label, value], index) => ({
    id: `spec-${index}-${label}`,
    label,
    value,
  }));
}

export function rowsToSpecifications(rows: ExchangeHubSpecRow[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const row of rows) {
    const label = row.label.trim();
    const value = row.value.trim();
    if (label && value) out[label] = value;
  }
  return out;
}

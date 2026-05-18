export function parseImageUrls(raw: unknown): string[] {
  if (raw == null) return [];
  if (Array.isArray(raw)) {
    return raw.filter((x): x is string => typeof x === "string" && x.trim().length > 0).map((u) => u.trim());
  }
  return [];
}

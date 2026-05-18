export function normalizeUsername(raw: string): string {
  let s = raw.trim().toLowerCase();
  if (!s) return "";
  s = s.replaceAll("@", "_");
  s = s.replace(/\s+/g, "_");
  s = s.replace(/_+/g, "_");
  s = s.replace(/^_+|_+$/g, "");
  return s;
}

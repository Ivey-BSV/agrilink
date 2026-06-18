const SAFE_INTERNAL_PATH = /^\/[a-zA-Z0-9/_-]*$/;

export function safeRedirectPath(raw: string | null | undefined, fallback = "/platform/feed"): string {
  const trimmed = raw?.trim() ?? "";
  if (!trimmed || !SAFE_INTERNAL_PATH.test(trimmed) || trimmed.startsWith("//")) {
    return fallback;
  }
  return trimmed;
}

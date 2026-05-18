const STORAGE_KEY = "agrilink_dashboard_impersonate_user_id";

export function getImpersonatedUserId(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const v = window.localStorage.getItem(STORAGE_KEY);
    return v && v.length > 10 ? v : null;
  } catch {
    return null;
  }
}

export function setImpersonatedUserId(userId: string | null) {
  if (typeof window === "undefined") return;
  try {
    if (!userId) window.localStorage.removeItem(STORAGE_KEY);
    else window.localStorage.setItem(STORAGE_KEY, userId);
    window.dispatchEvent(new Event("agrilink_impersonation_changed"));
  } catch {}
}

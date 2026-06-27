const STORAGE_KEY = "agrilink_staff_member_preview";

export const MEMBER_PREVIEW_CHANGED_EVENT = "agrilink_member_preview_changed";

export function getStaffMemberPreview(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

export function setStaffMemberPreview(active: boolean) {
  if (typeof window === "undefined") return;
  try {
    if (active) window.localStorage.setItem(STORAGE_KEY, "1");
    else window.localStorage.removeItem(STORAGE_KEY);
    window.dispatchEvent(new Event(MEMBER_PREVIEW_CHANGED_EVENT));
  } catch {}
}


export function isMemberFacingPath(pathname: string | null): boolean {
  if (!pathname) return false;
  if (pathname.startsWith("/dashboard/admin")) return false;
  if (pathname.startsWith("/platform")) return true;
  if (pathname === "/dashboard") return true;
  if (pathname.startsWith("/dashboard/")) return true;
  return false;
}

export function shouldShowStaffMemberPreviewBanner(
  pathname: string | null,
  isStaff: boolean,
  previewActive: boolean
): boolean {
  return isStaff && previewActive && isMemberFacingPath(pathname);
}

import { supabase } from "@/lib/supabase";

export type AppRole = "end_user" | "moderator" | "admin" | "super_admin";
export type AccountKind = "farmer" | "staff";

export type StaffProfileRow = {
  app_role: AppRole | string | null;
  account_kind: AccountKind | string | null;
  role?: string | null;
};

export type EffectiveStaffAccess = {
  appRole: AppRole;
  accountKind: AccountKind;
  emailBootstrap: boolean;
};

function parseSuperAdminEmails() {
  return (process.env.NEXT_PUBLIC_SUPER_ADMIN_EMAILS || "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

export function isSuperAdminEmail(email: string | null | undefined) {
  if (!email) return false;
  return parseSuperAdminEmails().includes(email.toLowerCase());
}

export function isAdminEmail(email: string | null | undefined) {
  if (!email) return false;
  const list = (process.env.NEXT_PUBLIC_ADMIN_EMAILS || "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return list.includes(email.toLowerCase());
}

function appRoleFromRow(row: StaffProfileRow | null | undefined): AppRole {
  if (!row) return "end_user";
  const r = row.app_role;
  if (r === "moderator" || r === "admin" || r === "super_admin" || r === "end_user") return r;
  if (row.role === "admin") return "admin";
  return "end_user";
}

function accountKindFromRow(row: StaffProfileRow | null | undefined, appRole: AppRole): AccountKind {
  const k = row?.account_kind;
  if (k === "staff" || k === "farmer") return k;
  if (appRole === "moderator" || appRole === "admin" || appRole === "super_admin") return "staff";
  return "farmer";
}

export async function getEffectiveStaffAccess(
  userId: string,
  email: string | null | undefined,
): Promise<EffectiveStaffAccess | null> {
  const { data, error } = await supabase
    .from("user_profiles")
    .select("app_role, account_kind, role")
    .eq("id", userId)
    .maybeSingle();

  if (error) return null;

  const row = data as StaffProfileRow | null;
  const baseRole = appRoleFromRow(row);
  const kind = accountKindFromRow(row, baseRole);

  const dbStaff =
    kind === "staff" &&
    (baseRole === "moderator" || baseRole === "admin" || baseRole === "super_admin");

  if (dbStaff) {
    const upgraded: AppRole = isSuperAdminEmail(email) ? "super_admin" : baseRole;
    return {
      appRole: upgraded,
      accountKind: "staff",
      emailBootstrap: false,
    };
  }

  if (isSuperAdminEmail(email)) {
    return { appRole: "super_admin", accountKind: "staff", emailBootstrap: true };
  }
  if (isAdminEmail(email)) {
    return { appRole: "admin", accountKind: "staff", emailBootstrap: true };
  }

  return null;
}

export function isSuperEffective(access: EffectiveStaffAccess | null) {
  return access?.appRole === "super_admin";
}

export function isAdminOrSuperEffective(access: EffectiveStaffAccess | null) {
  return access?.appRole === "admin" || access?.appRole === "super_admin";
}

export function isModeratorPlusEffective(access: EffectiveStaffAccess | null) {
  return (
    access?.appRole === "moderator" ||
    access?.appRole === "admin" ||
    access?.appRole === "super_admin"
  );
}

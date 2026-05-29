"use client";

import { Fragment } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { setStaffMemberPreview } from "@/lib/member-preview";
import { useStaffAccess } from "@/components/staff-access-context";
import {
  isAdminOrSuperEffective,
  isSuperEffective,
  type EffectiveStaffAccess,
} from "@/lib/staff-profile";

type AdminNavItem = { href: string; label: string; dividerBefore?: boolean };

function adminNavItems(access: EffectiveStaffAccess): AdminNavItem[] {
  const admin = isAdminOrSuperEffective(access);
  const sup = isSuperEffective(access);
  const items: AdminNavItem[] = [{ href: "/dashboard/admin", label: "Overview" }];
  if (admin) items.push({ href: "/dashboard/admin/farmers", label: "Farmers" });
  items.push({ href: "/dashboard/admin/events", label: "All events" });
  if (sup) {
    items.push(
      { href: "/dashboard/admin/staff", label: "Staff access", dividerBefore: true },
      { href: "/dashboard/admin/audit", label: "Audit log" },
      { href: "/dashboard/admin/system", label: "System & export" },
    );
  }
  return items;
}

function navLinkActive(pathname: string, href: string): boolean {
  if (href === "/dashboard/admin") return pathname === "/dashboard/admin";
  return pathname === href || pathname.startsWith(`${href}/`);
}

export default function AdminSectionLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { staffAccess: access, ready } = useStaffAccess();

  if (!ready) {
    return (
      <div className="content-card session-check-card">
        Checking admin access…
      </div>
    );
  }
  if (!access) {
    return (
      <div className="content-card stack">
        <h2 className="section-title">Admin</h2>
        <p className="error">You do not have staff access to this area.</p>
        <p className="subtle">
          Ask a super admin to grant you staff access, or have your email added to the deployment&apos;s admin allowlist
          if your team uses one for first-time setup.
        </p>
      </div>
    );
  }

  const items = adminNavItems(access);

  return (
    <div className="admin-section">
      <div className="content-card admin-toolbar">
        <div className="admin-toolbar-head">
          <div className="admin-role-strip">
            Signed in as <strong>{access.appRole.replace(/_/g, " ")}</strong>
            {access.emailBootstrap
              ? " (signed in via the admin email allowlist—ask a super admin to grant you full staff access so permissions match your role.)"
              : ""}
          </div>
          <button
            type="button"
            className="btn btn-secondary btn-primary-compact"
            onClick={() => {
              setStaffMemberPreview(true);
              router.push("/platform/feed");
            }}
          >
            Preview member experience
          </button>
        </div>
        <nav className="admin-nav-flat" aria-label="Admin pages">
          {items.map((item) => (
            <Fragment key={item.href}>
              {item.dividerBefore ? <span className="admin-nav-divider" aria-hidden /> : null}
              <Link
                href={item.href}
                className={`nav-link admin-nav-pill${navLinkActive(pathname, item.href) ? " active" : ""}`}
              >
                {item.label}
              </Link>
            </Fragment>
          ))}
        </nav>
      </div>
      {children}
    </div>
  );
}

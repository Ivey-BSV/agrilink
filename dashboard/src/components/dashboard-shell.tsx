"use client";

import Link from "next/link";
import React from "react";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import type { User } from "@supabase/supabase-js";
import { isSuperEffective, type EffectiveStaffAccess } from "@/lib/staff-profile";
import { getImpersonatedUserId, setImpersonatedUserId } from "@/lib/impersonation";
import { dashboardPageTitle } from "@/lib/dashboard-page-title";
import { AppSidebar, AppSidebarMobileNav } from "@/components/app-sidebar";
import { useStaffAccess } from "@/components/staff-access-context";

type DashboardShellProps = {
  user: User;
  children: React.ReactNode;
};

function formatRoleLabel(access: EffectiveStaffAccess | null) {
  if (!access) return "";
  return access.appRole.replace(/_/g, " ");
}

function isMemberWorkspaceDashboardPath(pathname: string | null) {
  return pathname === "/dashboard";
}

export function DashboardShell({ user, children }: DashboardShellProps) {
  const pathname = usePathname();
  const { staffAccess, ready } = useStaffAccess();
  const [impersonateId, setImpersonateId] = React.useState<string | null>(null);

  React.useEffect(() => {
    const sync = () => setImpersonateId(getImpersonatedUserId());
    sync();
    window.addEventListener("agrilink_impersonation_changed", sync);
    return () => window.removeEventListener("agrilink_impersonation_changed", sync);
  }, []);

  const isStaff = staffAccess != null;
  const showStaffMemberWorkspaceBanner =
    ready && staffAccess != null && isMemberWorkspaceDashboardPath(pathname);
  const headerTitle = dashboardPageTitle(pathname);

  return (
    <div className="dashboard-root app-shell-unified">
      <div className="app-shell-inner">
        {isSuperEffective(staffAccess) && impersonateId ? (
          <div className="content-card banner-warning" style={{ marginBottom: 20 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
              <div className="subtle">
                Impersonation target (local only): <code>{impersonateId}</code>
              </div>
              <button type="button" className="btn btn-secondary" onClick={() => setImpersonatedUserId(null)}>
                Clear impersonation
              </button>
            </div>
          </div>
        ) : null}

        {showStaffMemberWorkspaceBanner ? (
          <div className="content-card" style={{ marginBottom: 16, padding: "12px 16px" }}>
            <div
              style={{
                display: "flex",
                flexWrap: "wrap",
                gap: 12,
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <p className="subtle" style={{ margin: 0 }}>
                You’re on the <strong>member dashboard</strong> — the same home farmers use. Use <strong>Staff</strong> in the sidebar
                or the button below when you need admin tools.
              </p>
              <Link href="/dashboard/admin" className="btn btn-primary btn-primary-compact">
                Back to admin console
              </Link>
            </div>
          </div>
        ) : null}

        <div className="app-shell-frame">
          <AppSidebar />

          <div className="dashboard-column app-shell-column">
            <header className="platform-page-titlebar">
              <h1>{headerTitle}</h1>
              <p className="platform-title-meta subtle">
                {user.email}
                {isStaff ? ` · ${formatRoleLabel(staffAccess)}` : ""}
              </p>
            </header>

            <AppSidebarMobileNav />

            <motion.main
              key={pathname}
              className="dashboard-main app-shell-main"
              initial={false}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.18, ease: [0.25, 0.46, 0.45, 0.94] }}
            >
              {children}
            </motion.main>
          </div>
        </div>
      </div>
    </div>
  );
}

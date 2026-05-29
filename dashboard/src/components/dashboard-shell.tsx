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
import { StaffMemberPreviewGate } from "@/components/staff-member-preview-gate";
import { useStaffAccess } from "@/components/staff-access-context";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";

type DashboardShellProps = {
  user: User;
  children: React.ReactNode;
};

function formatRoleLabel(access: EffectiveStaffAccess | null) {
  if (!access) return "";
  return access.appRole.replace(/_/g, " ");
}

export function DashboardShell({ user, children }: DashboardShellProps) {
  const pathname = usePathname();
  const { staffAccess } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();
  const [impersonateId, setImpersonateId] = React.useState<string | null>(null);
  const showStaffRoleInHeader = staffAccess != null && !memberPreview;

  React.useEffect(() => {
    const sync = () => setImpersonateId(getImpersonatedUserId());
    sync();
    window.addEventListener("agrilink_impersonation_changed", sync);
    return () => window.removeEventListener("agrilink_impersonation_changed", sync);
  }, []);

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

        <StaffMemberPreviewGate />

        <div className="app-shell-frame">
          <AppSidebar />

          <div className="dashboard-column app-shell-column">
            <header className="platform-page-titlebar">
              <h1>{headerTitle}</h1>
              <p className="platform-title-meta subtle">
                {user.email}
                {showStaffRoleInHeader ? ` · ${formatRoleLabel(staffAccess)}` : ""}
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

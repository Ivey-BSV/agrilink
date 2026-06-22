"use client";

import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import type { User } from "@supabase/supabase-js";
import { AppSidebar, AppSidebarMobileNav } from "@/components/app-sidebar";
import { StaffMemberPreviewGate } from "@/components/staff-member-preview-gate";
import { useStaffAccess } from "@/components/staff-access-context";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";

function titleFromPath(pathname: string | null): string {
  if (!pathname) return "Forums";
  if (pathname.startsWith("/platform/feed")) return "Forums";
  if (pathname.startsWith("/platform/post/")) return "Post";
  if (pathname.startsWith("/platform/directory")) return "Farm Directory";
  if (pathname.startsWith("/platform/profile/farm-details")) return "Farm Details";
  if (pathname.startsWith("/platform/profile")) return "My Profile";
  if (pathname.startsWith("/platform/collaboration/projects/")) return "Project";
  if (pathname.startsWith("/platform/collaboration/projects")) return "Projects";
  if (pathname.startsWith("/platform/collaboration/polls/")) return "Poll";
  if (pathname.startsWith("/platform/collaboration/polls")) return "Polls";
  if (pathname.startsWith("/platform/collaboration/exchange-hub")) return "Exchange Hub";
  if (pathname.startsWith("/platform/notifications")) return "Notifications";
  if (pathname.startsWith("/platform/settings/about")) return "About your account";
  if (pathname.startsWith("/platform/settings/password")) return "Change password";
  if (pathname.startsWith("/platform/settings/contact")) return "Contact";
  if (pathname.startsWith("/platform/settings/privacy")) return "Privacy policy";
  if (pathname.startsWith("/platform/settings/terms")) return "Terms of use";
  if (pathname.startsWith("/platform/settings/notifications")) return "Notification settings";
  if (pathname.startsWith("/platform/settings")) return "Settings";
  if (pathname.startsWith("/platform/chat")) return "Chat";
  return "Forums";
}

export function PlatformShell({ user, children }: { user: User; children: ReactNode }) {
  const pathname = usePathname();
  const { staffAccess } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();
  const showStaffRoleInHeader = staffAccess != null && !memberPreview;

  return (
    <div className="platform-root app-shell-unified">
      <div className="app-shell-inner">
        <StaffMemberPreviewGate />

        <div className="app-shell-frame">
          <AppSidebar />

          <div className="platform-main-wrap app-shell-column">
            <header className="platform-page-titlebar">
              <h1>{titleFromPath(pathname)}</h1>
              <p className="platform-title-meta subtle">
                {user.email}
                {showStaffRoleInHeader ? ` · ${staffAccess.appRole.replace(/_/g, " ")}` : ""}
              </p>
            </header>

            <AppSidebarMobileNav />

            <motion.main
              key={pathname}
              className="app-shell-main"
              initial={false}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.18 }}
            >
              {children}
            </motion.main>
          </div>
        </div>
      </div>
    </div>
  );
}

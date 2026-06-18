"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { StaffMemberPreviewBanner } from "@/components/staff-member-preview-banner";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";
import { getStaffMemberPreview, shouldShowStaffMemberPreviewBanner } from "@/lib/member-preview";
import { useStaffAccess } from "@/components/staff-access-context";


export function StaffMemberPreviewGate() {
  const pathname = usePathname();
  const { staffAccess, ready } = useStaffAccess();
  const { active: previewActive, disable } = useStaffMemberPreview();

  useEffect(() => {
    if (pathname?.startsWith("/dashboard/admin") && getStaffMemberPreview()) {
      disable();
    }
  }, [pathname, disable]);

  if (!ready || !staffAccess) return null;
  if (!shouldShowStaffMemberPreviewBanner(pathname, true, previewActive)) return null;

  return <StaffMemberPreviewBanner />;
}

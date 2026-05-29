"use client";

import Link from "next/link";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";

export function StaffMemberPreviewBanner() {
  const { disable } = useStaffMemberPreview();

  return (
    <div className="content-card staff-member-preview-banner" role="status">
      <div className="staff-member-preview-banner-inner">
        <p className="subtle staff-member-preview-banner-text">
          You&apos;re previewing the <strong>member experience</strong> — the same Community, Collaboration,
          Resources, and profile tools farmers see. Your staff sign-in and permissions are unchanged.
        </p>
        <Link href="/dashboard/admin" className="btn btn-primary btn-primary-compact" onClick={() => disable()}>
          Exit member preview
        </Link>
      </div>
    </div>
  );
}

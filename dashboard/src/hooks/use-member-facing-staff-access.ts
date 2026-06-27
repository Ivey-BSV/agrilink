"use client";

import { useMemo } from "react";
import { useStaffAccess } from "@/components/staff-access-context";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";
import {
  isAdminOrSuperEffective,
  isModeratorPlusEffective,
  isSuperEffective,
  type EffectiveStaffAccess,
} from "@/lib/staff-profile";

/**
 * Staff access as seen in member-facing UI. When "member preview" is on,
 * treats the signed-in user as a regular member (no staff / super-admin affordances).
 */
export function useMemberFacingStaffAccess() {
  const { staffAccess: rawStaffAccess, ready } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();

  const staffAccess = useMemo<EffectiveStaffAccess | null>(
    () => (memberPreview ? null : rawStaffAccess),
    [memberPreview, rawStaffAccess],
  );

  return useMemo(
    () => ({
      staffAccess,
      rawStaffAccess,
      ready,
      memberPreview,
      isSuper: ready && !memberPreview && isSuperEffective(rawStaffAccess),
      isStaff: ready && !memberPreview && isModeratorPlusEffective(rawStaffAccess),
      isAdminOrSuper: ready && !memberPreview && isAdminOrSuperEffective(rawStaffAccess),
    }),
    [staffAccess, rawStaffAccess, ready, memberPreview],
  );
}

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

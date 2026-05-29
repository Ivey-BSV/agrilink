"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getStaffMemberPreview,
  MEMBER_PREVIEW_CHANGED_EVENT,
  setStaffMemberPreview,
} from "@/lib/member-preview";

export function useStaffMemberPreview() {
  const [active, setActive] = useState(false);

  useEffect(() => {
    const sync = () => setActive(getStaffMemberPreview());
    sync();
    window.addEventListener(MEMBER_PREVIEW_CHANGED_EVENT, sync);
    return () => window.removeEventListener(MEMBER_PREVIEW_CHANGED_EVENT, sync);
  }, []);

  const enable = useCallback(() => setStaffMemberPreview(true), []);
  const disable = useCallback(() => setStaffMemberPreview(false), []);

  return { active, enable, disable };
}

"use client";

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { User } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import { getEffectiveStaffAccess, type EffectiveStaffAccess } from "@/lib/staff-profile";

type StaffAccessState = {
  staffAccess: EffectiveStaffAccess | null;
  ready: boolean;
};

const StaffAccessContext = createContext<StaffAccessState>({
  staffAccess: null,
  ready: true,
});

export function StaffAccessProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [staffAccess, setStaffAccess] = useState<EffectiveStaffAccess | null>(null);
  const [ready, setReady] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
    });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });
    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!user) {
      setStaffAccess(null);
      setReady(true);
      return;
    }

    let cancelled = false;
    setReady(false);
    void getEffectiveStaffAccess(user.id, user.email).then((access) => {
      if (!cancelled) {
        setStaffAccess(access);
        setReady(true);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [user?.id, user?.email]);

  const value = useMemo(() => ({ staffAccess, ready }), [staffAccess, ready]);

  return <StaffAccessContext.Provider value={value}>{children}</StaffAccessContext.Provider>;
}

export function useStaffAccess() {
  return useContext(StaffAccessContext);
}

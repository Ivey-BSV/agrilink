"use client";

import type { ReactNode } from "react";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import { AppNav } from "@/components/app-nav";
import { AppFooter } from "@/components/app-footer";
import { StaffAccessProvider } from "@/components/staff-access-context";

export function AppChrome({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);

  const standaloneSignIn = pathname === "/" || pathname === "/signin";

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

  if (standaloneSignIn) {
    return <StaffAccessProvider>{children}</StaffAccessProvider>;
  }

  return (
    <StaffAccessProvider>
      <div className="public-page-shell">
        <AppNav user={user} />
        <div className="public-page-main">{children}</div>
        <AppFooter user={user} />
      </div>
    </StaffAccessProvider>
  );
}

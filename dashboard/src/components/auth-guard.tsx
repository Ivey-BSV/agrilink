"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import type { User } from "@supabase/supabase-js";

type AuthGuardProps = {
  children: (user: User) => React.ReactNode;
};

export function AuthGuard({ children }: AuthGuardProps) {
  const [user, setUser] = useState<User | null>(null);
  const [checking, setChecking] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    let mounted = true;

    const check = async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!mounted) return;

      if (!session?.user) {
        router.replace(`/?next=${encodeURIComponent(pathname || "/platform/feed")}`);
        return;
      }

      setUser(session.user);
      setChecking(false);
    };

    check();

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!mounted) return;
      if (!session?.user) {
        router.replace("/");
      } else {
        setUser(session.user);
      }
    });

    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [pathname, router]);

  if (checking || !user) {
    return (
      <div className="page-wrap">
        <div className="content-card session-check-card">Checking your session…</div>
      </div>
    );
  }

  return <>{children(user)}</>;
}


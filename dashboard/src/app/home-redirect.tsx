"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export function HomeRedirect() {
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (cancelled || !session?.user) return;
      router.replace("/platform/feed");
    });
    return () => {
      cancelled = true;
    };
  }, [router]);

  return null;
}

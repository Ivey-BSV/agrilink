"use client";

import { Suspense, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

function RedirectToHome() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const next = searchParams.get("next");
    router.replace(next ? `/?next=${encodeURIComponent(next)}` : "/");
  }, [router, searchParams]);

  return (
    <div className="signin-page signin-page--skeleton" aria-busy="true">
      <div className="signin-hero" />
      <div className="signin-panel" />
    </div>
  );
}

export default function SignInLegacyPage() {
  return (
    <Suspense
      fallback={
        <div className="signin-page signin-page--skeleton" aria-busy="true">
          <div className="signin-hero" />
          <div className="signin-panel" />
        </div>
      }
    >
      <RedirectToHome />
    </Suspense>
  );
}

"use client";

import { Suspense } from "react";
import { HomeRedirect } from "@/app/home-redirect";
import { SignInScreen } from "@/components/sign-in-screen";

function SignInWithParams() {
  return (
    <Suspense
      fallback={
        <div className="signin-page signin-page--skeleton" aria-busy="true">
          <div className="signin-hero" />
          <div className="signin-panel" />
        </div>
      }
    >
      <SignInScreen />
    </Suspense>
  );
}

export function HomeAuthEntry() {
  return (
    <>
      <HomeRedirect />
      <SignInWithParams />
    </>
  );
}

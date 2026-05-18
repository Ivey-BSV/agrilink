"use client";

import { AuthGuard } from "@/components/auth-guard";
import { PlatformShell } from "@/components/platform-shell";

export default function PlatformLayout({ children }: { children: React.ReactNode }) {
  return <AuthGuard>{(user) => <PlatformShell user={user}>{children}</PlatformShell>}</AuthGuard>;
}

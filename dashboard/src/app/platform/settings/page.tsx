"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { MOBILE_APP_VERSION_DISPLAY, WEB_DASHBOARD_VERSION } from "@/lib/cap-app-version";

const SETTINGS_LINKS: { href: string; label: string }[] = [
  { href: "/platform/settings/about", label: "About your account" },
  { href: "/platform/settings/password", label: "Change password" },
  { href: "/platform/settings/notifications", label: "Notification settings" },
  { href: "/platform/settings/privacy", label: "Privacy policy" },
  { href: "/platform/settings/terms", label: "Terms of use" },
  { href: "/platform/settings/contact", label: "Contact" },
];

export default function PlatformSettingsPage() {
  const router = useRouter();

  const signOut = async () => {
    await supabase.auth.signOut();
    router.replace("/");
  };

  return (
    <motion.div
      className="content-card stack"
      style={{ gap: 20 }}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div>
        <h2 className="section-title">Settings</h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Password, notifications, legal notices, and how to reach the program team. Update the profile other members see under{" "}
          <Link href="/platform/profile">My Profile</Link> in the sidebar.
        </p>
      </div>

      <nav className="platform-settings-list" aria-label="Settings sections">
        {SETTINGS_LINKS.map((item) => (
          <Link key={item.href} href={item.href}>
            {item.label}
          </Link>
        ))}
      </nav>

      <div className="content-card stack" style={{ gap: 8, padding: 16, background: "rgba(46, 125, 50, 0.06)" }}>
        <div className="subtle" style={{ fontWeight: 700, color: "var(--text)" }}>
          App versions
        </div>
        <p className="subtle" style={{ margin: 0 }}>
          Mobile (Flutter): <strong>{MOBILE_APP_VERSION_DISPLAY}</strong>
        </p>
        <p className="subtle" style={{ margin: 0 }}>
          Web dashboard: <strong>{WEB_DASHBOARD_VERSION}</strong>
        </p>
      </div>

      <button type="button" className="btn btn-secondary" style={{ alignSelf: "flex-start" }} onClick={() => void signOut()}>
        Sign out
      </button>
    </motion.div>
  );
}

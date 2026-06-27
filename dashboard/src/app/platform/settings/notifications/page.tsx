"use client";

import Link from "next/link";
import { SectionTitleWithInfo } from "@/components/page-section-header";
import { motion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";
import {
  isWebPushConfigured,
  requestWebPushPermission,
  clearWebPushToken,
} from "@/lib/firebase-web-push";

type SettingsRow = Record<string, unknown>;

const TOGGLES: { key: string; label: string }[] = [
  { key: "notify_new_posts_feed", label: "New posts in the feed" },
  { key: "notify_new_polls", label: "New polls" },
  { key: "notify_post_likes", label: "Likes on your posts" },
  { key: "notify_post_comments", label: "Comments on your posts" },
  { key: "notify_poll_closed", label: "Polls you voted in close" },
  { key: "notify_new_followers", label: "New followers" },
  { key: "notify_chat_messages", label: "Chat messages" },
  { key: "notify_project_activity", label: "Community project activity" },
  { key: "notify_repository_activity", label: "Repository files and links" },
  { key: "notify_workshop_activity", label: "Workshop files and links" },
];

type BrowserPushState = "checking" | "unsupported" | "blocked" | "off" | "on";

export default function NotificationSettingsPage() {
  const [row, setRow] = useState<SettingsRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [browserPush, setBrowserPush] = useState<BrowserPushState>("checking");
  const [browserPushBusy, setBrowserPushBusy] = useState(false);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  // Detect current browser push state.
  useEffect(() => {
    if (!isWebPushConfigured()) {
      setBrowserPush("unsupported");
      return;
    }
    if (!("Notification" in window) || !("serviceWorker" in navigator)) {
      setBrowserPush("unsupported");
      return;
    }
    if (Notification.permission === "denied") {
      setBrowserPush("blocked");
      return;
    }
    if (Notification.permission === "granted") {
      setBrowserPush("on");
    } else {
      setBrowserPush("off");
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) setError("Not signed in.");
        setLoading(false);
        return;
      }
      let { data, error: e } = await supabase.from("user_notification_settings").select("*").eq("user_id", user.id).maybeSingle();
      if (cancelled) return;
      if (e) {
        setError(e.message);
        setLoading(false);
        return;
      }
      if (!data) {
        const ins = await supabase.from("user_notification_settings").insert({ user_id: user.id }).select("*").single();
        data = ins.data;
        e = ins.error;
      }
      if (e) setError(e.message);
      else setRow((data as SettingsRow) ?? null);
      setLoading(false);
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  const patch = async (key: string, value: boolean) => {
    if (!row) return;
    const prev = row[key];
    setRow({ ...row, [key]: value });
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error: e } = await supabase.from("user_notification_settings").update({ [key]: value }).eq("user_id", user.id);
    if (e) {
      setRow({ ...row, [key]: prev });
      setError(e.message);
    }
  };

  const b = (key: string) => {
    const v = row?.[key];
    if (typeof v === "boolean") return v;
    return key === "push_enabled" ? false : true;
  };

  const enableBrowserPush = async () => {
    setBrowserPushBusy(true);
    try {
      const token = await requestWebPushPermission();
      if (!mounted.current) return;
      if (token) {
        setBrowserPush("on");
        // Also mark push_enabled = true in notification settings.
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          await supabase.from("user_notification_settings").update({ push_enabled: true }).eq("user_id", user.id);
          setRow((prev) => prev ? { ...prev, push_enabled: true } : prev);
        }
      } else if (Notification.permission === "denied") {
        setBrowserPush("blocked");
      }
    } finally {
      if (mounted.current) setBrowserPushBusy(false);
    }
  };

  const disableBrowserPush = async () => {
    setBrowserPushBusy(true);
    try {
      await clearWebPushToken();
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        await supabase.from("user_notification_settings").update({ push_enabled: false }).eq("user_id", user.id);
        setRow((prev) => prev ? { ...prev, push_enabled: false } : prev);
      }
      if (mounted.current) setBrowserPush("off");
    } finally {
      if (mounted.current) setBrowserPushBusy(false);
    }
  };

  return (
    <motion.div className="content-card stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <Link href="/platform/settings" className="btn btn-secondary" style={{ alignSelf: "flex-start", display: "inline-block" }}>
          ← Settings
        </Link>
        <SectionTitleWithInfo
          className="page-section-title-row--spaced"
          title="Notification settings"
          description="Decide which kinds of activity should ping you inside the site. Push alerts also respect your device and account settings when push is enabled."
        />
      </div>

      {/* Browser push notifications */}
      <div style={{ padding: "12px 14px", borderRadius: 10, border: "1px solid rgba(0,0,0,0.08)", background: "rgba(0,0,0,0.02)" }}>
        <div style={{ fontWeight: 600, marginBottom: 6 }}>Browser push notifications</div>
        {browserPush === "unsupported" ? (
          <p className="subtle" style={{ margin: 0, fontSize: "0.9rem" }}>
            Browser push is not available in this environment.
          </p>
        ) : browserPush === "blocked" ? (
          <p className="subtle" style={{ margin: 0, fontSize: "0.9rem" }}>
            Notifications are blocked in your browser settings. To enable them,
            click the lock icon in your address bar and allow notifications for
            this site, then reload.
          </p>
        ) : browserPush === "on" ? (
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
            <p className="subtle" style={{ margin: 0, fontSize: "0.9rem" }}>
              Push is active in this browser.
            </p>
            <button
              type="button"
              className="btn btn-secondary"
              disabled={browserPushBusy}
              onClick={() => void disableBrowserPush()}
            >
              {browserPushBusy ? "Disabling…" : "Disable"}
            </button>
          </div>
        ) : (
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
            <p className="subtle" style={{ margin: 0, fontSize: "0.9rem" }}>
              Get push alerts in this browser tab even when the app is in the background.
            </p>
            <button
              type="button"
              className="btn"
              disabled={browserPushBusy || browserPush === "checking"}
              onClick={() => void enableBrowserPush()}
            >
              {browserPushBusy ? "Enabling…" : "Enable"}
            </button>
          </div>
        )}
      </div>

      {loading ? <p className="subtle">Loading…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && row ? (
        <div className="stack" style={{ gap: 14 }}>
          {TOGGLES.map((t) => (
            <label
              key={t.key}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                gap: 16,
                borderBottom: "1px solid rgba(0,0,0,0.06)",
                paddingBottom: 12,
              }}
            >
              <span>{t.label}</span>
              <input type="checkbox" checked={b(t.key)} onChange={(ev) => void patch(t.key, ev.target.checked)} />
            </label>
          ))}
        </div>
      ) : null}
    </motion.div>
  );
}

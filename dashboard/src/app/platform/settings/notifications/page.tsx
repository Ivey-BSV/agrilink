"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

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
  { key: "push_enabled", label: "Push enabled (FCM token from mobile)" },
];

export default function NotificationSettingsPage() {
  const [row, setRow] = useState<SettingsRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

  return (
    <motion.div className="content-card stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <Link href="/platform/settings" className="btn btn-secondary" style={{ alignSelf: "flex-start", display: "inline-block" }}>
          ← Settings
        </Link>
        <h2 className="section-title" style={{ marginTop: 12 }}>
          Notification settings
        </h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Decide which kinds of activity should ping you inside the site. Push alerts also respect your device and account settings when push is enabled.
        </p>
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

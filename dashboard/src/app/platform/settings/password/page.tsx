"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";

export default function ChangePasswordPage() {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [show, setShow] = useState({ cur: false, n: false, c: false });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const submit = async (ev: FormEvent) => {
    ev.preventDefault();
    setError(null);
    setDone(false);
    if (!current.trim()) {
      setError("Please enter your current password.");
      return;
    }
    if (!next.trim()) {
      setError("Please enter a new password.");
      return;
    }
    if (next.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }
    if (next !== confirm) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user?.email) {
      setError("You must be signed in.");
      setLoading(false);
      return;
    }

    const { error: signErr } = await supabase.auth.signInWithPassword({
      email: user.email,
      password: current,
    });
    if (signErr) {
      setError("Current password is incorrect.");
      setLoading(false);
      return;
    }

    const { error: upErr } = await supabase.auth.updateUser({ password: next });
    if (upErr) {
      setError(upErr.message || "Failed to change password.");
      setLoading(false);
      return;
    }

    setDone(true);
    setCurrent("");
    setNext("");
    setConfirm("");
    setLoading(false);
  };

  return (
    <motion.div className="content-card stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <Link href="/platform/settings" className="btn btn-secondary" style={{ display: "inline-block" }}>
          ← Settings
        </Link>
        <h2 className="section-title" style={{ marginTop: 12 }}>
          Change password
        </h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Enter your current password, then choose a new one. We confirm your existing password before saving the update.
        </p>
      </div>

      {done ? (
        <p className="subtle" style={{ color: "var(--accent)", fontWeight: 600 }}>
          Password changed successfully.
        </p>
      ) : null}

      <form className="stack" style={{ gap: 14 }} onSubmit={(e) => void submit(e)}>
        <label className="stack" style={{ gap: 6 }}>
          <span className="subtle" style={{ fontWeight: 600 }}>
            Current password
          </span>
          <div style={{ display: "flex", gap: 8 }}>
            <input
              type={show.cur ? "text" : "password"}
              className="input"
              style={{ flex: 1, minWidth: 0 }}
              value={current}
              onChange={(e) => setCurrent(e.target.value)}
              autoComplete="current-password"
            />
            <button type="button" className="btn btn-secondary" onClick={() => setShow((s) => ({ ...s, cur: !s.cur }))}>
              {show.cur ? "Hide" : "Show"}
            </button>
          </div>
        </label>
        <label className="stack" style={{ gap: 6 }}>
          <span className="subtle" style={{ fontWeight: 600 }}>
            New password
          </span>
          <div style={{ display: "flex", gap: 8 }}>
            <input
              type={show.n ? "text" : "password"}
              className="input"
              style={{ flex: 1, minWidth: 0 }}
              value={next}
              onChange={(e) => setNext(e.target.value)}
              autoComplete="new-password"
            />
            <button type="button" className="btn btn-secondary" onClick={() => setShow((s) => ({ ...s, n: !s.n }))}>
              {show.n ? "Hide" : "Show"}
            </button>
          </div>
        </label>
        <label className="stack" style={{ gap: 6 }}>
          <span className="subtle" style={{ fontWeight: 600 }}>
            Confirm new password
          </span>
          <div style={{ display: "flex", gap: 8 }}>
            <input
              type={show.c ? "text" : "password"}
              className="input"
              style={{ flex: 1, minWidth: 0 }}
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              autoComplete="new-password"
            />
            <button type="button" className="btn btn-secondary" onClick={() => setShow((s) => ({ ...s, c: !s.c }))}>
              {show.c ? "Hide" : "Show"}
            </button>
          </div>
        </label>
        {error ? <p className="error">{error}</p> : null}
        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? "Updating…" : "Change password"}
        </button>
      </form>
    </motion.div>
  );
}

"use client";

import Link from "next/link";
import { motion } from "framer-motion";

const EMAIL = "cap@ivey.ca";
const PHONE = "519-661-2111 ext. 88864";

export default function ContactSettingsPage() {
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {}
  };

  const telDigits = PHONE.split(" ext.")[0]?.replace(/\D/g, "") ?? "";

  return (
    <motion.div className="content-card stack" style={{ gap: 20 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <Link href="/platform/settings" className="btn btn-secondary" style={{ display: "inline-block" }}>
          ← Settings
        </Link>
        <h2 className="section-title" style={{ marginTop: 12 }}>
          Contact
        </h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Program staff contact details for account questions or general help.
        </p>
      </div>

      <div className="content-card stack" style={{ gap: 16, padding: 20, background: "#fafafa" }}>
        <div className="subtle" style={{ fontWeight: 700, fontSize: "1.05rem", color: "var(--text)" }}>
          Email
        </div>
        <a href={`mailto:${EMAIL}`} style={{ fontSize: 18, fontWeight: 600, color: "var(--accent)" }}>
          {EMAIL}
        </a>
        <button type="button" className="btn btn-primary" onClick={() => void copy(EMAIL)}>
          Copy email
        </button>
      </div>

      <div className="content-card stack" style={{ gap: 16, padding: 20, background: "#fafafa" }}>
        <div className="subtle" style={{ fontWeight: 700, fontSize: "1.05rem", color: "var(--text)" }}>
          Phone
        </div>
        <span style={{ fontSize: 18, fontWeight: 600, color: "var(--accent)" }}>{PHONE}</span>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
          <a href={`tel:${telDigits}`} className="btn btn-primary">
            Call
          </a>
          <button type="button" className="btn btn-secondary" onClick={() => void copy(PHONE)}>
            Copy phone
          </button>
        </div>
      </div>
    </motion.div>
  );
}

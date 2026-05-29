"use client";

import Link from "next/link";
import { SectionTitleWithInfo } from "@/components/page-section-header";
import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDateLong } from "@/lib/format";

type Profile = {
  username: string | null;
  full_name: string | null;
  bio: string | null;
  location: string | null;
  farm_type: string | null;
  experience_level: string | null;
  created_at: string | null;
};

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ paddingBottom: 16, borderBottom: "1px solid rgba(0,0,0,0.08)" }}>
      <div className="subtle" style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>
        {label}
      </div>
      <div style={{ fontSize: 16 }}>{value}</div>
    </div>
  );
}

export default function AboutYourAccountPage() {
  const [email, setEmail] = useState<string | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) {
          setError("Not signed in.");
          setLoading(false);
        }
        return;
      }
      if (!cancelled) setEmail(user.email ?? null);

      const { data, error: e } = await supabase
        .from("user_profiles")
        .select("username, full_name, bio, location, farm_type, experience_level, created_at")
        .eq("id", user.id)
        .maybeSingle();

      if (cancelled) return;
      if (e) setError(e.message);
      else setProfile(data as Profile | null);
      setLoading(false);
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  const hasProfileDetails =
    profile?.farm_type || profile?.experience_level || (profile?.bio && profile.bio.trim());

  return (
    <motion.div className="content-card stack" style={{ gap: 20 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <Link href="/platform/settings" className="btn btn-secondary" style={{ display: "inline-block" }}>
          ← Settings
        </Link>
        <SectionTitleWithInfo
          className="page-section-title-row--spaced"
          title="About your account"
          description="A read-only snapshot of the email, username, and profile fields stored for your account. To change them, edit My Profile."
        />
      </div>

      {loading ? <p className="subtle">Loading…</p> : null}
      {error ? <p className="error">{error}</p> : null}

      {!loading && !error ? (
        <div className="stack" style={{ gap: 0 }}>
          <h3 className="section-title" style={{ fontSize: "1.05rem", marginBottom: 8 }}>
            Account information
          </h3>
          <div className="stack" style={{ gap: 0 }}>
            <Row label="Username" value={profile?.username?.trim() || "Not set"} />
            <Row label="Email" value={email?.trim() || "Not set"} />
            <Row label="Full name" value={profile?.full_name?.trim() || "Not set"} />
            <Row label="Date joined" value={formatDateLong(profile?.created_at)} />
            {profile?.location?.trim() ? <Row label="Location" value={profile.location.trim()} /> : null}
          </div>

          <h3 className="section-title" style={{ fontSize: "1.05rem", marginTop: 24, marginBottom: 8 }}>
            Profile details
          </h3>
          {hasProfileDetails ? (
            <div className="stack" style={{ gap: 0 }}>
              {profile?.farm_type?.trim() ? <Row label="Farm type" value={profile.farm_type.trim()} /> : null}
              {profile?.experience_level?.trim() ? (
                <Row label="Experience level" value={profile.experience_level.trim()} />
              ) : null}
              {profile?.bio?.trim() ? <Row label="Bio" value={profile.bio.trim()} /> : null}
            </div>
          ) : (
            <p className="subtle" style={{ fontStyle: "italic" }}>
              No additional profile details in the database yet.
            </p>
          )}
        </div>
      ) : null}
    </motion.div>
  );
}

"use client";

import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { FarmDirectoryCard } from "@/components/farm-directory-card";
import { MotionListItem } from "@/components/motion-list";
import { directoryEntrySearchText, loadDirectoryEntries, type DirectoryEntry } from "@/lib/farm-directory";

export default function PlatformDirectoryPage() {
  const [entries, setEntries] = useState<DirectoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const { entries: loaded, error: loadError } = await loadDirectoryEntries();
      if (cancelled) return;
      if (loadError) setError(loadError);
      else setEntries(loaded);
      setLoading(false);
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return entries;
    return entries.filter((entry) => directoryEntrySearchText(entry).includes(q));
  }, [entries, query]);

  return (
    <motion.div className="content-card stack" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
      <p className="subtle" style={{ marginBottom: 12 }}>
        Search members by name, region, farm type, crops, activities, and other farm details to find people you may want
        to connect with.
      </p>
      <div className="field" style={{ maxWidth: 430 }}>
        <label htmlFor="directory-search">Search</label>
        <input
          id="directory-search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Name, location, crops, certification…"
        />
      </div>

      <div className="platform-tag-row">
        <span className="pill">{entries.length} profiles</span>
        <span className="pill">{filtered.length} shown</span>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {loading ? <p className="subtle">Loading directory…</p> : null}
      {!loading && filtered.length === 0 ? <p className="empty">No matching profiles.</p> : null}

      <div className="list">
        {filtered.map((entry, index) => (
          <MotionListItem key={entry.profile.id} index={index} className="list-item farm-directory-card platform-directory-card">
            <FarmDirectoryCard entry={entry} />
          </MotionListItem>
        ))}
      </div>
    </motion.div>
  );
}

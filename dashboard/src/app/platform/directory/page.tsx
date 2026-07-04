"use client";

import { useEffect, useMemo, useState } from "react";
import { FarmDirectoryCard } from "@/components/farm-directory-card";
import { MotionListItem } from "@/components/motion-list";
import { PageSectionHeader } from "@/components/page-section-header";
import { PlatformMetaRow, PlatformPageShell } from "@/components/platform-section";
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
    <PlatformPageShell>
      <PageSectionHeader
        title="Farm Directory"
        description="Search members by name, region, farm type, crops, activities, and other farm details to find people you may want to connect with."
      />
      <div className="platform-toolbar">
        <div className="field" style={{ flex: "1 1 16rem", maxWidth: 430, margin: 0 }}>
          <label htmlFor="directory-search">Search</label>
          <input
            id="directory-search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Name, location, crops, certification…"
          />
        </div>
        <PlatformMetaRow>
          <span className="pill">{entries.length} profiles</span>
          <span className="pill">{filtered.length} shown</span>
        </PlatformMetaRow>
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
    </PlatformPageShell>
  );
}

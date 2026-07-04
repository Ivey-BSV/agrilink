"use client";

import { motion } from "framer-motion";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ExchangeHubCard } from "@/components/exchange-hub-card";
import { ExchangeHubDetailModal } from "@/components/exchange-hub-detail-modal";
import { ExchangeHubListingModal } from "@/components/exchange-hub-listing-modal";
import { ForumTagPicker } from "@/components/forum-tag-picker";
import { PageSectionHeader } from "@/components/page-section-header";
import {
  loadExchangeHubListings,
  loadFavoriteListingIds,
  type ExchangeHubListing,
} from "@/lib/exchange-hub";
import { supabase } from "@/lib/supabase";

type SortKey = "newest" | "oldest";
type FilterKey = "all" | "favourites";

export default function ExchangeHubPage() {
  const [listings, setListings] = useState<ExchangeHubListing[]>([]);
  const [favoriteIds, setFavoriteIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [signedIn, setSignedIn] = useState(false);

  const [sortBy, setSortBy] = useState<SortKey>("newest");
  const [filterBy, setFilterBy] = useState<FilterKey>("all");
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [tagsOpen, setTagsOpen] = useState(false);

  const [detailListing, setDetailListing] = useState<ExchangeHubListing | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<"create" | "edit">("create");
  const [editListing, setEditListing] = useState<ExchangeHubListing | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    setCurrentUserId(user?.id ?? null);
    setSignedIn(!!user);

    const [{ listings: loaded, error: loadError }, favorites] = await Promise.all([
      loadExchangeHubListings(),
      loadFavoriteListingIds(),
    ]);

    if (loadError) setError(loadError);
    setListings(loaded);
    setFavoriteIds(favorites);
    setLoading(false);
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const visibleListings = useMemo(() => {
    let items = [...listings];

    if (selectedTags.length > 0) {
      const need = new Set(selectedTags);
      items = items.filter((item) => item.tags.some((tag) => need.has(tag)));
    }

    if (filterBy === "favourites") {
      items = items.filter((item) => favoriteIds.has(item.id));
    }

    items.sort((a, b) => {
      const aTime = new Date(a.created_at).getTime();
      const bTime = new Date(b.created_at).getTime();
      return sortBy === "oldest" ? aTime - bTime : bTime - aTime;
    });

    return items;
  }, [listings, selectedTags, filterBy, favoriteIds, sortBy]);

  const openCreate = () => {
    setFormMode("create");
    setEditListing(null);
    setFormOpen(true);
  };

  const openEdit = (listing: ExchangeHubListing) => {
    setDetailListing(null);
    setFormMode("edit");
    setEditListing(listing);
    setFormOpen(true);
  };

  const onFavoriteChange = (listingId: string, favorited: boolean) => {
    setFavoriteIds((prev) => {
      const next = new Set(prev);
      if (favorited) next.add(listingId);
      else next.delete(listingId);
      return next;
    });
  };

  const onDeleted = (listingId: string) => {
    setListings((prev) => prev.filter((item) => item.id !== listingId));
    setFavoriteIds((prev) => {
      const next = new Set(prev);
      next.delete(listingId);
      return next;
    });
  };

  return (
    <motion.div className="content-card stack exchange-hub-shell" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <PageSectionHeader
        title="Exchange Hub"
        description="Share and discover community assets — equipment, tools, and resources farmers are willing to lend or offer. List the assets which you'd like to share with the community."
        action={
          signedIn ? (
            <button type="button" className="btn btn-primary btn-primary-compact" onClick={openCreate}>
              Share asset
            </button>
          ) : null
        }
      />

      <div className="exchange-hub-toolbar">
        <div className="platform-feed-filters">
          <button
            type="button"
            className={`platform-chip${filterBy === "all" ? " active" : ""}`}
            onClick={() => setFilterBy("all")}
          >
            All
          </button>
          <button
            type="button"
            className={`platform-chip${filterBy === "favourites" ? " active" : ""}`}
            onClick={() => setFilterBy("favourites")}
            disabled={!signedIn}
          >
            Favourites
          </button>
        </div>

        <div className="exchange-hub-toolbar-actions">
          <button type="button" className="btn btn-secondary platform-feed-tags-btn" onClick={() => setTagsOpen(true)}>
            Tags{selectedTags.length > 0 ? ` (${selectedTags.length})` : ""}
          </button>

          <label className="platform-feed-sort-label">
            Sort
            <select className="input platform-feed-sort-select" value={sortBy} onChange={(e) => setSortBy(e.target.value as SortKey)}>
              <option value="newest">Newest first</option>
              <option value="oldest">Oldest first</option>
            </select>
          </label>
        </div>
      </div>

      {loading ? <p className="subtle">Loading shared assets…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && visibleListings.length === 0 ? (
        <p className="empty">{filterBy === "favourites" ? "No favourited assets yet." : "No shared assets yet."}</p>
      ) : null}

      {!loading && visibleListings.length > 0 ? (
        <div className="exchange-hub-grid">
          {visibleListings.map((listing) => (
            <ExchangeHubCard key={listing.id} listing={listing} onOpen={() => setDetailListing(listing)} />
          ))}
        </div>
      ) : null}

      {tagsOpen ? (
        <div className="backdrop active" role="dialog" aria-modal="true" aria-labelledby="exchange-hub-tags-title">
          <div className="absolute inset-0" onClick={() => setTagsOpen(false)} />
          <div className="modal-content platform-create-modal" style={{ opacity: 1, transform: "none", maxWidth: 520, width: "min(96vw, 520px)" }}>
            <div className="stack" style={{ gap: 14 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
                <h3 id="exchange-hub-tags-title" className="section-title" style={{ fontSize: "1.15rem", margin: 0 }}>
                  Filter by tags
                </h3>
                <button type="button" className="btn btn-secondary" onClick={() => setTagsOpen(false)}>
                  Done
                </button>
              </div>
              <p className="subtle" style={{ margin: 0 }}>
                Show assets that include any of the tags you select.
              </p>
              <div style={{ maxHeight: "min(60vh, 420px)", overflowY: "auto", paddingRight: 4 }}>
                <ForumTagPicker selected={selectedTags} onChange={setSelectedTags} />
              </div>
              <div style={{ display: "flex", gap: 10, justifyContent: "space-between", flexWrap: "wrap" }}>
                <button type="button" className="btn btn-secondary" onClick={() => setSelectedTags([])}>
                  Clear all
                </button>
                <button type="button" className="btn btn-primary" onClick={() => setTagsOpen(false)}>
                  Apply
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <ExchangeHubDetailModal
        listing={detailListing}
        currentUserId={currentUserId}
        favoriteIds={favoriteIds}
        onClose={() => setDetailListing(null)}
        onFavoriteChange={onFavoriteChange}
        onEdit={openEdit}
        onDeleted={onDeleted}
      />

      <ExchangeHubListingModal
        open={formOpen}
        mode={formMode}
        listing={editListing}
        onClose={() => setFormOpen(false)}
        onSaved={() => void reload()}
      />
    </motion.div>
  );
}

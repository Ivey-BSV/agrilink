"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { UserAvatar } from "@/components/user-avatar";
import { PlatformSectionIntro } from "@/components/platform-section";
import {
  deleteExchangeHubListing,
  exchangeHubAuthorLabel,
  exchangeHubPrimaryImage,
  toggleExchangeHubFavorite,
  type ExchangeHubListing,
} from "@/lib/exchange-hub";
import { formatDate, formatRelativeTime } from "@/lib/format";
import { networkDisplayImageUrl } from "@/lib/image-urls";

type ExchangeHubDetailModalProps = {
  listing: ExchangeHubListing | null;
  currentUserId: string | null;
  favoriteIds: Set<string>;
  onClose: () => void;
  onFavoriteChange: (listingId: string, favorited: boolean) => void;
  onEdit: (listing: ExchangeHubListing) => void;
  onDeleted: (listingId: string) => void;
};

export function ExchangeHubDetailModal({
  listing,
  currentUserId,
  favoriteIds,
  onClose,
  onFavoriteChange,
  onEdit,
  onDeleted,
}: ExchangeHubDetailModalProps) {
  const [favoriting, setFavoriting] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!listing) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [listing, onClose]);

  if (!listing) return null;

  const imageUrl = networkDisplayImageUrl(exchangeHubPrimaryImage(listing), 1200);
  const author = exchangeHubAuthorLabel(listing);
  const isOwner = currentUserId != null && listing.user_id === currentUserId;
  const isFavorite = favoriteIds.has(listing.id);
  const specEntries = Object.entries(listing.specifications);

  const toggleFavorite = async () => {
    if (!currentUserId) {
      setError("Sign in to save favourites.");
      return;
    }
    setFavoriting(true);
    setError(null);
    const { error: favError } = await toggleExchangeHubFavorite(listing.id);
    setFavoriting(false);
    if (favError) {
      setError(favError);
      return;
    }
    onFavoriteChange(listing.id, !isFavorite);
  };

  const removeListing = async () => {
    if (!confirm("Delete this shared asset?")) return;
    setDeleting(true);
    setError(null);
    const { error: delError } = await deleteExchangeHubListing(listing.id);
    setDeleting(false);
    if (delError) {
      setError(delError);
      return;
    }
    onDeleted(listing.id);
    onClose();
  };

  return (
    <div className="backdrop active" role="dialog" aria-modal="true" aria-labelledby="exchange-hub-detail-title">
      <div className="absolute inset-0" onClick={onClose} />
      <div
        className="modal-content platform-create-modal exchange-hub-detail-modal"
        style={{ opacity: 1, transform: "none", maxWidth: 720, width: "min(96vw, 720px)" }}
      >
        <div className="stack" style={{ gap: 14 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12 }}>
            <h3 id="exchange-hub-detail-title" className="section-title" style={{ fontSize: "1.2rem", margin: 0 }}>
              Shared asset
            </h3>
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Close
            </button>
          </div>

          {imageUrl ? (
            <div className="exchange-hub-detail-media">
              <img src={imageUrl} alt="" className="exchange-hub-detail-img" />
            </div>
          ) : null}

          <div className="exchange-hub-detail-author-row">
            <UserAvatar url={listing.author.avatar_url} name={author} size={44} />
            <div className="stack" style={{ gap: 2, minWidth: 0 }}>
              {listing.author.id ? (
                <Link href={`/platform/user/${listing.author.id}`} className="workshop-line-title" style={{ textDecoration: "none" }}>
                  {author}
                </Link>
              ) : (
                <div className="workshop-line-title">{author}</div>
              )}
              <div className="workshop-line-meta">
                {formatRelativeTime(listing.created_at)} · {formatDate(listing.created_at)}
              </div>
            </div>
            <div style={{ marginLeft: "auto", display: "flex", gap: 8, flexWrap: "wrap" }}>
              {currentUserId ? (
                <button
                  type="button"
                  className={`btn btn-secondary${isFavorite ? " exchange-hub-fav-active" : ""}`}
                  disabled={favoriting}
                  onClick={() => void toggleFavorite()}
                >
                  {favoriting ? "…" : isFavorite ? "Favourited" : "Favourite"}
                </button>
              ) : null}
              {isOwner ? (
                <>
                  <button type="button" className="btn btn-secondary" onClick={() => onEdit(listing)}>
                    Edit
                  </button>
                  <button type="button" className="btn btn-danger" disabled={deleting} onClick={() => void removeListing()}>
                    {deleting ? "Deleting…" : "Delete"}
                  </button>
                </>
              ) : null}
            </div>
          </div>

          <div className="exchange-hub-detail-title">{listing.title}</div>

          <div className="platform-meta-row">
            {listing.location ? <span className="pill">{listing.location}</span> : null}
            {listing.condition ? <span className="pill">{listing.condition}</span> : null}
          </div>

          {listing.tags.length > 0 ? (
            <div className="exchange-hub-card-tags">
              {listing.tags.map((tag) => (
                <span key={tag} className="exchange-hub-tag-pill">
                  {tag}
                </span>
              ))}
            </div>
          ) : null}

          {listing.description ? (
            <div className="stack" style={{ gap: 8 }}>
              <PlatformSectionIntro title="Description" />
              <p className="subtle" style={{ margin: 0, whiteSpace: "pre-wrap", lineHeight: 1.5 }}>
                {listing.description}
              </p>
            </div>
          ) : null}

          {specEntries.length > 0 ? (
            <div className="stack" style={{ gap: 8 }}>
              <PlatformSectionIntro title="Specifications" />
              <ul className="exchange-hub-spec-list">
                {specEntries.map(([label, value]) => (
                  <li key={label} className="exchange-hub-spec-line">
                    <span className="exchange-hub-spec-label">{label}</span>
                    <span>{value}</span>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {error ? <p className="error">{error}</p> : null}
        </div>
      </div>
    </div>
  );
}

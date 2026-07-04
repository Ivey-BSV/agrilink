"use client";

import { formatRelativeTime } from "@/lib/format";
import type { ExchangeHubListing } from "@/lib/exchange-hub";
import { exchangeHubAuthorLabel, exchangeHubPrimaryImage } from "@/lib/exchange-hub";
import { networkDisplayImageUrl } from "@/lib/image-urls";

type ExchangeHubCardProps = {
  listing: ExchangeHubListing;
  onOpen: () => void;
};

export function ExchangeHubCard({ listing, onOpen }: ExchangeHubCardProps) {
  const imageUrl = networkDisplayImageUrl(exchangeHubPrimaryImage(listing), 640);
  const author = exchangeHubAuthorLabel(listing);

  return (
    <button type="button" className="exchange-hub-card" onClick={onOpen}>
      <div className="exchange-hub-card-media">
        {imageUrl ? (
          <img src={imageUrl} alt="" className="exchange-hub-card-img" loading="lazy" decoding="async" />
        ) : (
          <div className="exchange-hub-card-placeholder" aria-hidden>
            <span>📦</span>
          </div>
        )}
        <span className="exchange-hub-card-time">{formatRelativeTime(listing.created_at)}</span>
      </div>
      <div className="exchange-hub-card-body stack" style={{ gap: 6 }}>
        <div className="exchange-hub-card-title">{listing.title}</div>
        <div className="exchange-hub-card-meta">
          {listing.location ? <span>{listing.location}</span> : null}
          {listing.location ? <span aria-hidden> · </span> : null}
          <span>{author}</span>
        </div>
        {listing.tags.length > 0 ? (
          <div className="exchange-hub-card-tags">
            {listing.tags.slice(0, 3).map((tag) => (
              <span key={tag} className="exchange-hub-tag-pill">
                {tag}
              </span>
            ))}
            {listing.tags.length > 3 ? (
              <span className="exchange-hub-tag-pill exchange-hub-tag-pill--more">+{listing.tags.length - 3}</span>
            ) : null}
          </div>
        ) : null}
      </div>
    </button>
  );
}

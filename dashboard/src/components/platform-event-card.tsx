"use client";

import {
  formatEventCategory,
  formatEventDateTimeLine,
  isEventUpcoming,
} from "@/lib/event-format";

export type PlatformEventItem = {
  id: string;
  title: string;
  category: string;
  event_date: string;
  time: string;
  location: string;
  description?: string | null;
  link_url?: string | null;
};

type PlatformEventCardProps = {
  event: PlatformEventItem;
};

export function PlatformEventCard({ event }: PlatformEventCardProps) {
  const upcoming = isEventUpcoming(event.event_date);
  const category = formatEventCategory(event.category);
  const when = formatEventDateTimeLine(event.event_date, event.time);
  const location = event.location?.trim();
  const description = event.description?.trim();
  const linkUrl = event.link_url?.trim();

  return (
    <article className="platform-event-card">
      <div className="platform-event-card-badges">
        <span className="platform-event-badge platform-event-badge--category">{category}</span>
        <span className={`platform-event-badge platform-event-badge--status${upcoming ? " is-upcoming" : " is-past"}`}>
          {upcoming ? "Upcoming" : "Past"}
        </span>
      </div>
      <h3 className="platform-event-card-title">{event.title}</h3>
      {description ? <p className="platform-event-card-desc">{description}</p> : null}
      <ul className="platform-event-card-meta">
        <li>
          <span className="platform-event-meta-icon" aria-hidden>
            📅
          </span>
          <span>{when}</span>
        </li>
        {location ? (
          <li>
            <span className="platform-event-meta-icon" aria-hidden>
              📍
            </span>
            <span>{location}</span>
          </li>
        ) : null}
        {linkUrl ? (
          <li>
            <span className="platform-event-meta-icon" aria-hidden>
              🔗
            </span>
            <a href={linkUrl} target="_blank" rel="noreferrer">
              Event link
            </a>
          </li>
        ) : null}
      </ul>
    </article>
  );
}

type PlatformEventListProps = {
  events: PlatformEventItem[];
  loading?: boolean;
  emptyMessage: string;
};

export function PlatformEventList({ events, loading, emptyMessage }: PlatformEventListProps) {
  if (loading) return <p className="subtle">Loading events…</p>;
  if (events.length === 0) return <p className="empty">{emptyMessage}</p>;
  return (
    <div className="platform-event-list">
      {events.map((ev) => (
        <PlatformEventCard key={ev.id} event={ev} />
      ))}
    </div>
  );
}

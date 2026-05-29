/** Human-readable category label from stored value. */
export function formatEventCategory(raw: string | null | undefined): string {
  const t = (raw ?? "").trim();
  if (!t) return "Event";
  return t.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** e.g. "May 28, 2026" from ISO date or date string. */
export function formatEventDateAbbreviated(value: string | null | undefined): string {
  if (!value?.trim()) return "Date TBD";
  const d = new Date(value.trim());
  if (Number.isNaN(d.getTime())) return value.trim();
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

export function formatEventDateTimeLine(eventDate: string | null | undefined, time: string | null | undefined): string {
  const datePart = formatEventDateAbbreviated(eventDate);
  const timePart = (time ?? "").trim();
  return timePart ? `${datePart} at ${timePart}` : datePart;
}

export function isEventUpcoming(eventDate: string | null | undefined): boolean {
  if (!eventDate?.trim()) return false;
  const ev = new Date(eventDate.trim());
  if (Number.isNaN(ev.getTime())) return false;
  const now = new Date();
  return (
    ev > now ||
    (ev.getFullYear() === now.getFullYear() &&
      ev.getMonth() === now.getMonth() &&
      ev.getDate() === now.getDate())
  );
}

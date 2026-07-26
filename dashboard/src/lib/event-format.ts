/** Calendar date (YYYY-MM-DD) without UTC timezone shift. */
export function parseEventCalendarDate(value: string | null | undefined): Date | null {
  if (!value?.trim()) return null;
  const raw = value.trim();
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (dateOnly) {
    const y = Number(dateOnly[1]);
    const m = Number(dateOnly[2]);
    const d = Number(dateOnly[3]);
    const local = new Date(y, m - 1, d);
    if (local.getFullYear() !== y || local.getMonth() !== m - 1 || local.getDate() !== d) {
      return null;
    }
    return local;
  }
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/** Normalize DB/date strings for `<input type="date">`. */
export function toEventDateInputValue(value: string | null | undefined): string {
  if (!value?.trim()) return "";
  const match = /^(\d{4}-\d{2}-\d{2})/.exec(value.trim());
  return match ? match[1] : value.trim();
}

export function formatEventCategory(raw: string | null | undefined): string {
  const t = (raw ?? "").trim();
  if (!t) return "Event";
  return t.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function formatEventDateAbbreviated(value: string | null | undefined): string {
  if (!value?.trim()) return "Date TBD";
  const d = parseEventCalendarDate(value);
  if (!d) return value.trim();
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

export function formatEventDateTimeLine(eventDate: string | null | undefined, time: string | null | undefined): string {
  const datePart = formatEventDateAbbreviated(eventDate);
  const timePart = (time ?? "").trim();
  return timePart ? `${datePart} at ${timePart}` : datePart;
}

export function isEventUpcoming(eventDate: string | null | undefined): boolean {
  const ev = parseEventCalendarDate(eventDate);
  if (!ev) return false;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return ev.getTime() >= today.getTime();
}

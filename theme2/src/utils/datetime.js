/**
 * Shared date/time utilities.
 *
 * Conventions:
 *   - The backend always sends and accepts ISO strings in UTC (with `Z`).
 *   - The UI always displays times in the user's *browser* timezone.
 *   - `datetime-local` inputs speak "browser-local wall time" without an offset,
 *     which is ambiguous. These helpers make the round trip explicit.
 *
 * If we ever switch to a stored per-user offset, only this file should change.
 */

// -----------------------------------------------------------------------------
// Parsing
// -----------------------------------------------------------------------------

/**
 * Parse a UTC ISO string (with Z) from the API.
 * Also tolerates legacy values like "2026-01-02 03:17:00" (space, no Z)
 * by treating them as UTC.
 */
export function parseUtc(value) {
  if (!value) return null;

  // Normalize "YYYY-MM-DD HH:MM:SS" to ISO with Z.
  let iso = String(value).trim().replace(" ", "T");
  if (!/[Zz]|[+-]\d{2}:?\d{2}$/.test(iso)) {
    // No timezone marker: assume UTC.
    iso += "Z";
  }

  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

// -----------------------------------------------------------------------------
// Formatting for display
// -----------------------------------------------------------------------------

const pad = (n) => String(n).padStart(2, "0");

/** "2026-01-02" from a Date in local time. */
export function formatDateOnly(date) {
  if (!date) return "";
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** "04:17" from a Date in local time. */
export function formatTimeShort(date) {
  if (!date) return "";
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** "04:17:00" from a Date in local time. */
export function formatTimeLong(date) {
  if (!date) return "";
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

/** "YYYY-MM-DD HH:MM:SS" from a Date in local time. Used in tables. */
export function formatDateTimeForDisplay(date) {
  if (!date) return "";
  return `${formatDateOnly(date)} ${formatTimeLong(date)}`;
}

/** Best-effort short timezone label like "UTC+02:00" or "CEST". */
export function browserTimezoneLabel(date = new Date()) {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZoneName: "short"
    }).formatToParts(date);
    const tz = parts.find((p) => p.type === "timeZoneName");
    return tz ? tz.value : "";
  } catch {
    return "";
  }
}

// -----------------------------------------------------------------------------
// datetime-local <input> helpers
// -----------------------------------------------------------------------------

/**
 * Convert a UTC ISO string from the API to a `datetime-local` input value
 * in the browser's local timezone.
 *
 * Output format: "YYYY-MM-DDTHH:MM"
 */
export function utcToLocalInput(utcString) {
  const date = parseUtc(utcString);
  if (!date) return "";
  return `${formatDateOnly(date)}T${formatTimeShort(date)}`;
}

/**
 * Convert a `datetime-local` input value (browser-local wall time, no offset)
 * into a UTC ISO string with a `Z` suffix, ready to POST/PUT to the API.
 *
 * Input format: "YYYY-MM-DDTHH:MM" (or with seconds).
 * Output: "2026-01-02T03:17:00Z"
 */
export function localInputToUtc(inputValue) {
  if (!inputValue) return "";

  // A datetime-local value has no timezone marker, so `new Date()` parses it
  // as browser-local — exactly what we want.
  const date = new Date(inputValue);
  if (Number.isNaN(date.getTime())) return "";

  // toISOString() always emits UTC with a Z suffix.
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

// -----------------------------------------------------------------------------
// Durations
// -----------------------------------------------------------------------------

/** Minutes between two UTC ISO strings, floored. Never negative. */
export function minutesBetween(utcStart, utcEnd) {
  const start = parseUtc(utcStart);
  const end = parseUtc(utcEnd);
  if (!start || !end) return 0;
  const diff = Math.floor((end.getTime() - start.getTime()) / 60000);
  return diff > 0 ? diff : 0;
}

/** Format minutes as "2h 04m" or "34m". */
export function formatMinutes(totalMinutes) {
  const m = Math.max(0, Math.floor(totalMinutes || 0));
  const h = Math.floor(m / 60);
  const rem = m % 60;
  if (h === 0) return `${rem}m`;
  return `${h}h ${pad(rem)}m`;
}

/** Duration between two UTC ISO strings, formatted. */
export function formatDurationBetween(utcStart, utcEnd) {
  const mins = minutesBetween(utcStart, utcEnd);
  return mins === 0 ? "—" : formatMinutes(mins);
}
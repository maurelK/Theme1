import { parseUtc, minutesBetween } from "./datetime";

const pad = (n) => String(n).padStart(2, "0");

// "YYYY-MM-DD" in the browser timezone.
export function localDateKey(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// Monday of the week containing `date`, as a local "YYYY-MM-DD" key.
export function weekStartKey(date) {
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate() - ((date.getDay() + 6) % 7));
  return localDateKey(monday);
}

// Sum completed entries into buckets, sorted chronologically: [{ key, hours }].
function aggregate(workingTimes, keyOf) {
  const buckets = new Map();

  for (const wt of workingTimes) {
    const start = parseUtc(wt.start);
    if (!start || !parseUtc(wt.end)) continue;
    const key = keyOf(start);
    buckets.set(key, (buckets.get(key) || 0) + minutesBetween(wt.start, wt.end));
  }

  return Array.from(buckets.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, minutes]) => ({ key, hours: +(minutes / 60).toFixed(2) }));
}

export const hoursByDay = (workingTimes) => aggregate(workingTimes, localDateKey);
export const hoursByWeek = (workingTimes) => aggregate(workingTimes, weekStartKey);

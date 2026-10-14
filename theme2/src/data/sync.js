// Replays the outbox against the API, oldest first, when the network allows.
//
// Outcome per item:
//  * 2xx (including an idempotent duplicate)  -> applied, removed
//  * 401                                      -> session expired: stop, keep everything
//  * other 4xx (e.g. 409 already clocked in)  -> rejected by the server: removed and
//                                                reported, since replaying cannot succeed
//  * 5xx or network error                     -> stop, retry later
// Only the signed-in user's items are sent; another user's items wait for them.

import { readonly, ref } from "vue";
import { apiFetch, authState, revalidateSession } from "../services/auth";
import { network } from "../platform/network";
import { outbox } from "./outbox";

const RETRY_INTERVAL_MS = 30_000;

const syncing = ref(false);
// Items the server refused, shown to the user: { id, label, message, at }.
const rejected = ref([]);
const afterSyncListeners = new Set();
let started = false;

async function sendItem(item) {
  const response = await apiFetch(item.path, {
    method: item.method,
    silent: true,
    headers: { "Content-Type": "application/json" },
    body: item.body ? JSON.stringify(item.body) : undefined
  });
  const body = await response.json().catch(() => ({}));
  return { status: response.status, body };
}

async function flush() {
  if (syncing.value || !authState.user || !network.isOnline()) return;
  const items = (await outbox.list()).filter((item) => String(item.userId) === String(authState.user.id));
  if (items.length === 0) return;

  syncing.value = true;
  const applied = [];
  try {
    // A session restored offline carries a possibly stale CSRF token.
    if (!(await revalidateSession())) return;

    for (const item of items) {
      let result;
      try {
        result = await sendItem(item);
      } catch {
        return; // Network dropped again: keep the rest for later.
      }

      if (result.status >= 200 && result.status < 300) {
        await outbox.remove(item.id);
        applied.push(item);
      } else if (result.status === 401) {
        return;
      } else if (result.status >= 400 && result.status < 500) {
        await outbox.remove(item.id);
        rejected.value = [
          ...rejected.value,
          { id: item.id, label: item.label, message: result.body.error || `Rejected (${result.status})`, at: item.createdAt }
        ];
      } else {
        await outbox.markAttempt(item.id, `HTTP ${result.status}`);
        return;
      }
    }
  } catch (error) {
    console.warn("Sync interrupted:", error);
  } finally {
    syncing.value = false;
    if (applied.length || rejected.value.length) afterSyncListeners.forEach((listener) => listener(applied));
  }
}

export const sync = {
  syncing: readonly(syncing),
  rejected: readonly(rejected),

  flush,

  dismissRejected(id) {
    rejected.value = rejected.value.filter((entry) => entry.id !== id);
  },

  // Run `listener(appliedItems)` after each sync pass, e.g. to refresh a cache.
  onSynced(listener) {
    afterSyncListeners.add(listener);
    return () => afterSyncListeners.delete(listener);
  },

  // Flush on reconnect, when the app returns to the foreground, and periodically.
  start() {
    if (started) return;
    started = true;
    outbox.ensureLoaded();
    network.onReconnect(flush);
    document.addEventListener("resume", flush); // Cordova
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") flush();
    });
    setInterval(() => {
      if (outbox.pending.value > 0) flush();
    }, RETRY_INTERVAL_MS);
    flush();
  }
};

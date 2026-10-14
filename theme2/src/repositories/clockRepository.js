// Clock-in/out data access with offline support.
//  * readLocal: last known status, from the device cache
//  * refresh:   status from the server (the server is the source of truth)
//  * clock:     sends the action now, or queues it in the outbox when offline
// Pending queued actions are applied on top of the cached status, so the screen
// reflects what the user did even before it reaches the server.

import { apiFetch, authState } from "../services/auth";
import { localDb } from "../platform/localDb";
import { network } from "../platform/network";
import { newIdempotencyKey, outbox } from "../data/outbox";
import { trustedClock } from "../data/trustedClock";

const TYPE = "clock";
const cacheKey = (userId) => `clock:status:${userId}`;

export class OfflineNotAllowedError extends Error {}

// Replay pending actions over the cached server status.
function withPending(status, pendingItems) {
  return pendingItems.reduce(
    (current, item) =>
      item.body.action === "in"
        ? { ...current, in: true, since: item.body.device_time, pending: true }
        : { ...current, in: false, since: null, pending: true },
    { ...(status || { in: false, since: null, shift: null }), pending: false }
  );
}

export const clockRepository = {
  async readLocal(userId) {
    const cached = await localDb.get(cacheKey(userId));
    return withPending(cached, await outbox.itemsFor(TYPE, userId));
  },

  async refresh(userId) {
    const response = await apiFetch(`/api/clocks/${userId}/status`, { silent: true });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.error || `Unable to load status (${response.status})`);

    if (body.server_time) await trustedClock.sync(body.server_time);
    await localDb.set(cacheKey(userId), body);
    return withPending(body, await outbox.itemsFor(TYPE, userId));
  },

  // Returns { queued: boolean }. Throws on a server refusal (e.g. already clocked in).
  async clock(userId, action) {
    const ownClock = String(userId) === String(authState.user?.id);
    const key = newIdempotencyKey();
    const item = {
      id: key,
      userId,
      type: TYPE,
      method: "POST",
      path: `/api/clocks/${userId}/${action}`,
      label: action === "in" ? "Clock in" : "Clock out",
      // The server only trusts device_time when users clock themselves.
      body: { action, idempotency_key: key, device_time: (await trustedClock.now()).toISOString() }
    };

    const queue = async () => {
      // Clocking someone else needs live data and a server-side time.
      if (!ownClock) throw new OfflineNotAllowedError("Connection required to clock another person.");
      await outbox.enqueue(item);
      return { queued: true };
    };

    if (!network.isOnline()) return queue();

    let response;
    try {
      response = await apiFetch(item.path, {
        method: "POST",
        silent: true,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(item.body)
      });
    } catch {
      // The request may or may not have reached the server: replaying with the
      // same idempotency key is safe either way.
      return queue();
    }

    const body = await response.json().catch(() => ({}));
    if (response.status >= 500) return queue();
    if (!response.ok) throw new Error(body.error || `Request failed (${response.status})`);
    return { queued: false };
  }
};

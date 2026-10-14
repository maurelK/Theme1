// Persistent queue of write requests made while offline, replayed in order by sync.js.
// Each item carries an idempotency key so a replay is applied once by the server.

import { readonly, ref } from "vue";
import { localDb } from "../platform/localDb";

const OUTBOX_KEY = "outbox";

const pending = ref(0);
let loaded = false;
// Serialise read-modify-write cycles so concurrent calls cannot lose an item.
let chain = Promise.resolve();

function withLock(task) {
  const run = chain.then(task);
  chain = run.catch(() => {});
  return run;
}

async function readItems() {
  const items = await localDb.get(OUTBOX_KEY, []);
  pending.value = items.length;
  loaded = true;
  return items;
}

async function writeItems(items) {
  await localDb.set(OUTBOX_KEY, items);
  pending.value = items.length;
}

export function newIdempotencyKey() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") return crypto.randomUUID();
  // Older WebViews: RFC 4122 v4 from getRandomValues.
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export const outbox = {
  pending: readonly(pending),

  // item: { id (idempotency key), userId, type, method, path, body, label }
  enqueue(item) {
    return withLock(async () => {
      const items = await readItems();
      items.push({ attempts: 0, createdAt: new Date().toISOString(), ...item });
      await writeItems(items);
    });
  },

  list() {
    return withLock(readItems);
  },

  remove(id) {
    return withLock(async () => {
      const items = await readItems();
      await writeItems(items.filter((item) => item.id !== id));
    });
  },

  markAttempt(id, lastError) {
    return withLock(async () => {
      const items = await readItems();
      const item = items.find((entry) => entry.id === id);
      if (item) {
        item.attempts += 1;
        item.lastError = lastError;
        await writeItems(items);
      }
    });
  },

  // Items of one domain for one user, e.g. to rebuild the local clock state.
  async itemsFor(type, userId) {
    const items = await this.list();
    return items.filter((item) => item.type === type && String(item.userId) === String(userId));
  },

  async ensureLoaded() {
    if (!loaded) await this.list();
  }
};

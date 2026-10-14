// Write actions that keep working offline: sent now when possible, otherwise
// queued in the outbox and replayed by the sync with the same idempotency key.
//
// Only actions listed as safe offline use this (see docs: create a team, add or
// remove a member, request a correction, edit one's own details). Sensitive
// actions (roles, deletions, invitations, passwords) stay online-only.

import { readonly, ref } from "vue";
import { authState } from "../services/auth";
import { network } from "../platform/network";
import { newIdempotencyKey, outbox } from "./outbox";
import { sendItem, sync } from "./sync";

export class ServerRefusedError extends Error {
  constructor(message, status, body) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

// Bumped whenever the outbox changes, so pages listing pending actions refresh.
const outboxVersion = ref(0);
sync.onSynced(() => outboxVersion.value++);

function errorMessage(body, status) {
  if (typeof body?.error === "string") return body.error;
  if (body?.errors) {
    return Object.entries(body.errors)
      .flatMap(([field, messages]) => [].concat(messages).map((m) => `${field} ${m}`))
      .join(", ");
  }
  return `Request failed (${status})`;
}

/**
 * Send a write now, or queue it when offline.
 *
 * action: { type, label, method, path, body?, meta?, okStatuses? }
 *   type/meta let a page find and display its own pending items.
 * Returns { queued: false, data } once applied, or { queued: true, item }.
 * Throws ServerRefusedError when the server rejects it (4xx).
 */
export async function sendOrQueue(action) {
  const item = { ...action, id: newIdempotencyKey(), userId: authState.user?.id };

  const queue = async () => {
    await outbox.enqueue(item);
    outboxVersion.value++;
    return { queued: true, item };
  };

  if (!network.isOnline()) return queue();

  let result;
  try {
    result = await sendItem(item);
  } catch {
    // The request may have reached the server: the replay uses the same key.
    return queue();
  }

  if (result.status >= 500) return queue();
  if (result.status >= 400) throw new ServerRefusedError(errorMessage(result.body, result.status), result.status, result.body);
  return { queued: false, data: result.body };
}

// Pending outbox items of a type for the signed-in user (re-read via `outboxVersion`).
export async function pendingItems(type) {
  const items = await outbox.list();
  return items.filter((item) => item.type === type && String(item.userId) === String(authState.user?.id));
}

export const outboxChanges = readonly(outboxVersion);

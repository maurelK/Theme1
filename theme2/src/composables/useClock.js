// Clock state for one user, online or offline. The component only renders it.

import { computed, onBeforeUnmount, ref, watch } from "vue";
import { clockRepository, OfflineNotAllowedError } from "../repositories/clockRepository";
import { network } from "../platform/network";
import { outbox } from "../data/outbox";
import { sync } from "../data/sync";

export function useClock(userIdRef) {
  const status = ref(null);
  const loading = ref(false);
  const statusLoading = ref(false);
  const error = ref("");
  // True when the status shown comes from the device cache, not a fresh server answer.
  const fromCache = ref(false);

  const clockedIn = computed(() => Boolean(status.value?.in));
  const pending = computed(() => Boolean(status.value?.pending));

  async function load() {
    const userId = userIdRef.value;
    if (!userId) return;
    statusLoading.value = true;

    // Show the cached state immediately, then try the server.
    const local = await clockRepository.readLocal(userId);
    if (local) status.value = local;

    try {
      status.value = await clockRepository.refresh(userId);
      fromCache.value = false;
    } catch {
      fromCache.value = true;
    } finally {
      statusLoading.value = false;
    }
  }

  // Returns "in" | "out" | null, and whether the action was queued offline.
  async function toggle() {
    const userId = userIdRef.value;
    if (!userId) return { action: null, queued: false };
    const action = clockedIn.value ? "out" : "in";

    loading.value = true;
    error.value = "";
    try {
      const { queued } = await clockRepository.clock(userId, action);
      if (queued) {
        status.value = await clockRepository.readLocal(userId);
        fromCache.value = true;
      } else {
        await load();
      }
      return { action, queued };
    } catch (err) {
      error.value = err instanceof OfflineNotAllowedError
        ? err.message
        : err.message || "Unable to update clock.";
      // The server may have moved the state (e.g. clocked out elsewhere).
      await load();
      throw err;
    } finally {
      loading.value = false;
    }
  }

  // Refresh once queued actions reach the server.
  const stopSyncListener = sync.onSynced(() => load());
  onBeforeUnmount(stopSyncListener);

  watch(userIdRef, () => {
    error.value = "";
    load();
  }, { immediate: true });

  return {
    status,
    clockedIn,
    pending,
    loading,
    statusLoading,
    error,
    fromCache,
    online: network.online,
    pendingCount: outbox.pending,
    syncing: sync.syncing,
    rejected: sync.rejected,
    dismissRejected: sync.dismissRejected,
    toggle,
    reload: load
  };
}

<template>
  <section class="my-requests" aria-labelledby="my-requests-title">
    <h3 id="my-requests-title">My correction requests</h3>
    <p class="my-requests-intro">
      Ask for a correction from the time entries tab. Your manager reviews it here.
    </p>

    <p v-if="loading" class="my-requests-status">Loading requests...</p>
    <p v-else-if="error && allRequests.length === 0" class="my-requests-status my-requests-error" role="alert">{{ error }}</p>
    <p v-else-if="allRequests.length === 0" class="my-requests-status">You have not sent any correction request.</p>

    <ul v-else class="my-requests-list">
      <li v-for="request in allRequests" :key="request.id" class="my-request">
        <div class="my-request-head">
          <span class="my-request-status" :class="`is-${request.status}`">{{ statusLabel(request.status) }}</span>
          <span class="my-request-date">{{ request.status === "unsent" ? "Saved" : "Sent" }} {{ formatDate(request.submitted_at) }}</span>
        </div>
        <p><strong>Recorded:</strong> {{ formatRange(request.current_start, request.current_end) }}</p>
        <p v-if="request.proposed_start || request.proposed_end">
          <strong>Proposed:</strong>
          {{ formatRange(request.proposed_start || request.current_start, request.proposed_end || request.current_end) }}
        </p>
        <p><strong>Reason:</strong> {{ request.reason }}</p>
        <p v-if="request.response"><strong>Reply:</strong> {{ request.response }}</p>
      </li>
    </ul>
  </section>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { apiFetch } from "../services/auth";
import { outboxChanges, pendingItems } from "../data/mutations";
import { sync } from "../data/sync";
import { formatRange, parseUtc } from "../utils/datetime";

const STATUS_LABELS = { unsent: "Not sent yet", pending: "Pending", approved: "Approved", rejected: "Rejected" };

const requests = ref([]);
const loading = ref(true);
const error = ref("");
// Requests made offline and not sent yet, shown first.
const unsent = ref([]);

const allRequests = computed(() => [
  ...unsent.value.map((item) => ({ ...item.meta, id: item.id, status: "unsent", submitted_at: item.createdAt })),
  ...requests.value
]);

// Offline, apiFetch answers with the copy saved on the phone.
async function load() {
  try {
    const response = await apiFetch("/api/correction-requests/mine", { silent: true });
    if (!response.ok) throw new Error("Unable to load your correction requests.");
    requests.value = (await response.json()).data || [];
    error.value = "";
  } catch (err) {
    error.value = requests.value.length ? "" : "Your requests are not saved on this device yet.";
  } finally {
    loading.value = false;
  }
}

async function loadUnsent() {
  unsent.value = await pendingItems("correction");
}

onMounted(() => {
  load();
  loadUnsent();
});
watch(outboxChanges, loadUnsent);
// Sent requests now come from the server.
onBeforeUnmount(sync.onSynced(load));

function statusLabel(status) {
  return STATUS_LABELS[status] || status;
}

function formatDate(value) {
  const date = parseUtc(value);
  return date ? date.toLocaleDateString() : "";
}
</script>

<style scoped>
.my-requests h3 { margin: 0 0 6px; color: #243332; font-size: 18px; }
.my-requests-intro { margin: 0 0 18px; color: #4f5d58; font-size: 14px; }
.my-requests-status { color: #4f5d58; font-size: 14px; }
.my-requests-error { color: #a33b2b; }
.my-requests-list { display: grid; gap: 12px; margin: 0; padding: 0; list-style: none; }
.my-request { padding: 16px; border: 1px solid #d4d6cc; background: #fffdf7; }
.my-request p { margin: 6px 0 0; color: #243332; font-size: 14px; }
.my-request-head { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; justify-content: space-between; }
.my-request-date { color: #4f5d58; font-size: 13px; }
.my-request-status { padding: 3px 10px; border: 1px solid currentColor; font-size: 12px; font-weight: 700; }
.my-request-status.is-unsent { color: #4f5d58; }
.my-request-status.is-pending { color: #8a5a00; }
.my-request-status.is-approved { color: #1f6b46; }
.my-request-status.is-rejected { color: #a33b2b; }
</style>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { apiFetch } from "../services/auth";

const props = defineProps({
  userId: { type: [Number, String], default: null }
});

// Wall clock — uses browser local time for the on-screen display.
const now = ref(new Date());
let tickHandle = null;

// Server state.
const loading = ref(false);
const statusLoading = ref(false);
const status = ref(null);   // { in, since, duration_minutes, shift }
const error = ref("");
const lastAction = ref(""); // optional success feedback

const userId = computed(() => {
  const u = props.userId;
  if (u === null || u === undefined || u === "null" || u === "undefined" || u === "") {
    return null;
  }
  return u;
});

const formattedTime = computed(() => {
  const t = now.value;
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(t.getHours())}:${pad(t.getMinutes())}:${pad(t.getSeconds())}`;
});

const clockedIn = computed(() => Boolean(status.value?.in));

const elapsedLabel = computed(() => {
  const mins = status.value?.duration_minutes ?? 0;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h === 0) return `${m}m`;
  return `${h}h ${String(m).padStart(2, "0")}m`;
});

const sinceLabel = computed(() => {
  if (!status.value?.since) return "";
  const dt = new Date(status.value.since);
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(dt.getHours())}:${pad(dt.getMinutes())}`;
});

const shiftLabel = computed(() => {
  const s = status.value?.shift;
  if (!s || s.start_minutes == null || s.end_minutes == null) return "No shift configured";
  const fmt = (mins) => {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
  };
  const tz = s.tz_offset_minutes ?? 0;
  const tzLabel =
    tz === 0 ? "UTC" : `UTC${tz > 0 ? "+" : "-"}${String(Math.floor(Math.abs(tz) / 60)).padStart(2, "0")}:${String(Math.abs(tz) % 60).padStart(2, "0")}`;
  return `${fmt(s.start_minutes)}–${fmt(s.end_minutes)} (${tzLabel}) · ${s.source}`;
});

async function loadStatus() {
  if (!userId.value) return;
  statusLoading.value = true;
  error.value = "";

  try {
    const res = await apiFetch(`/api/clocks/${userId.value}/status`);
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Unable to load status (${res.status})`);
    }
    status.value = await res.json();
  } catch (err) {
    error.value = err.message || "Unable to load clock status.";
  } finally {
    statusLoading.value = false;
  }
}

async function toggle() {
  if (!userId.value) return;
  loading.value = true;
  error.value = "";
  lastAction.value = "";

  const action = clockedIn.value ? "out" : "in";

  try {
    const res = await apiFetch(`/api/clocks/${userId.value}/${action}`, {
      method: "POST"
    });

    const body = await res.json().catch(() => ({}));

    if (!res.ok) {
      // Common conflicts get friendly messages.
      if (res.status === 409) {
        error.value = body.error || (action === "in" ? "Already clocked in." : "Not currently clocked in.");
      } else {
        error.value = body.error || `Request failed (${res.status})`;
      }
      // Refresh status anyway — server may have moved it.
      await loadStatus();
      return;
    }

    lastAction.value = action === "in" ? "Clocked in." : "Clocked out.";
    // Force an immediate status reload so the UI reflects the new state.
    await loadStatus();
  } catch (err) {
    error.value = err.message || "Unable to update clock.";
  } finally {
    loading.value = false;
  }
}

watch(userId, () => {
  loadStatus();
});

onMounted(() => {
  loadStatus();
  tickHandle = setInterval(() => {
    now.value = new Date();
  }, 1000);
});

onBeforeUnmount(() => {
  if (tickHandle) clearInterval(tickHandle);
});
</script>

<template>
  <main class="clock-shell">
    <div class="clock-time">{{ formattedTime }}</div>

    <div v-if="!userId" class="clock-empty">Select a user to manage their clock.</div>

    <div v-else class="clock-panel">
      <div class="clock-status-line">
        <span v-if="statusLoading">Checking status…</span>
        <span v-else-if="clockedIn">
          Clocked in since <strong>{{ sinceLabel }}</strong> · elapsed <strong>{{ elapsedLabel }}</strong>
        </span>
        <span v-else>Not clocked in.</span>
      </div>

      <div class="clock-shift-line">Shift: {{ shiftLabel }}</div>

      <button
        class="clock-button"
        :class="{ 'is-out': clockedIn }"
        :disabled="loading || statusLoading"
        @click="toggle"
      >
        {{ loading ? "Working…" : clockedIn ? "Clock Out" : "Clock In" }}
      </button>

      <p v-if="error" class="clock-alert clock-alert-error">{{ error }}</p>
      <p v-else-if="lastAction" class="clock-alert clock-alert-success">{{ lastAction }}</p>
    </div>
  </main>
</template>

<style scoped>
.clock-shell {
  max-width: 560px;
  margin: 40px auto 0;
  padding: 32px 24px;
  border: 1px solid #d4d6cc;
  background: #fffdf7;
  text-align: center;
}

.clock-time {
  font: 500 clamp(48px, 8vw, 72px) "Playfair Display", Georgia, serif;
  color: #243332;
  letter-spacing: -0.04em;
  line-height: 1;
  margin-bottom: 20px;
}

.clock-empty {
  color: #71807a;
  font-size: 14px;
}

.clock-panel {
  display: grid;
  gap: 14px;
}

.clock-status-line {
  color: #243332;
  font-size: 14px;
}

.clock-status-line strong {
  font-weight: 600;
}

.clock-shift-line {
  color: #71807a;
  font: 11px "DM Mono", monospace;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.clock-button {
  min-height: var(--tap-min, 44px);
  padding: 16px 28px;
  border: 0;
  background: #263b38;
  color: #fffdf7;
  font: 700 13px "Manrope", sans-serif;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  cursor: pointer;
  transition: background 0.2s, transform 0.15s;
}

.clock-button:hover:not(:disabled) {
  background: #35504b;
  transform: translateY(-1px);
}

.clock-button.is-out {
  background: #a3614a;
}

.clock-button.is-out:hover:not(:disabled) {
  background: #b5684b;
}

.clock-button:disabled {
  opacity: 0.6;
  cursor: wait;
}

.clock-alert {
  margin: 4px 0 0;
  font-size: 12px;
}

.clock-alert-error {
  color: #a3614a;
}

.clock-alert-success {
  color: #287c78;
}
</style>
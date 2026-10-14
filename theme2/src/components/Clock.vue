<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { useClock } from "../composables/useClock";
import { notifyClockIn, notifyClockOut, notifyError, unlockAudio } from "../services/feedback";
import { parseUtc, formatTimeShort, formatMinutes } from "../utils/datetime";

const props = defineProps({
  userId: { type: [Number, String], default: null }
});

const userId = computed(() => {
  const u = props.userId;
  if (u === null || u === undefined || u === "null" || u === "undefined" || u === "") {
    return null;
  }
  return u;
});

// Online and offline clock state (see composables/useClock.js).
const {
  status,
  clockedIn,
  pending,
  loading,
  statusLoading,
  error,
  fromCache,
  online,
  pendingCount,
  syncing,
  rejected,
  dismissRejected,
  toggle: toggleClock
} = useClock(userId);

const lastAction = ref("");

// Wall clock - ticks every second.
const now = ref(new Date());
let tickHandle = null;

const formattedTime = computed(() => {
  const t = now.value;
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(t.getHours())}:${pad(t.getMinutes())}:${pad(t.getSeconds())}`;
});

// Live elapsed: recompute from `since` on every tick, using the browser's
// current time. Never trust the server's duration_minutes snapshot for the
// running counter.
const elapsedLabel = computed(() => {
  if (!clockedIn.value) return "0m";
  const start = parseUtc(status.value?.since);
  if (!start) return "0m";
  const minutes = Math.max(0, Math.floor((now.value.getTime() - start.getTime()) / 60000));
  return formatMinutes(minutes);
});

// Display the clock-in timestamp in browser-local time.
const sinceLabel = computed(() => {
  const start = parseUtc(status.value?.since);
  return start ? formatTimeShort(start) : "";
});

// Human-readable label for the shift's timezone.
function shiftTzLabel(tzMinutes) {
  if (tzMinutes === 0) return "UTC";
  const sign = tzMinutes > 0 ? "+" : "-";
  const abs = Math.abs(tzMinutes);
  const h = String(Math.floor(abs / 60)).padStart(2, "0");
  const m = String(abs % 60).padStart(2, "0");
  return `UTC${sign}${h}:${m}`;
}

const shiftLabel = computed(() => {
  const s = status.value?.shift;
  if (!s || s.start_minutes == null || s.end_minutes == null) {
    return "No shift configured";
  }
  const fmt = (mins) => {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
  };
  return `${fmt(s.start_minutes)}-${fmt(s.end_minutes)} (${shiftTzLabel(s.tz_offset_minutes ?? 0)}) - ${s.source}`;
});

const pendingLabel = computed(() => {
  const count = pendingCount.value;
  if (!count) return "";
  const what = `${count} action${count === 1 ? "" : "s"}`;
  return syncing.value ? `Sending ${what}...` : `${what} saved on this device, sent when the connection returns.`;
});

async function toggle() {
  // Must run before the first await so the confirmation sound is allowed to play.
  unlockAudio();
  lastAction.value = "";

  try {
    const { action, queued } = await toggleClock();
    if (!action) return;
    const done = action === "in" ? "Clocked in" : "Clocked out";
    lastAction.value = queued ? `${done} offline. It will be sent automatically.` : `${done}.`;
    action === "in" ? notifyClockIn() : notifyClockOut();
  } catch {
    notifyError();
  }
}

onMounted(() => {
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

    <p v-if="!online" class="clock-banner clock-banner-offline" role="status">
      Offline. You can still clock in and out; it will be sent when the connection returns.
    </p>

    <div v-if="!userId" class="clock-empty">Select a user to manage their clock.</div>

    <div v-else class="clock-panel">
      <div class="clock-status-line">
        <span v-if="statusLoading && !status">Checking status...</span>
        <span v-else-if="clockedIn">
          Clocked in since <strong>{{ sinceLabel }}</strong> - elapsed <strong>{{ elapsedLabel }}</strong>
        </span>
        <span v-else>Not clocked in.</span>
        <span v-if="pending" class="clock-tag">Not sent yet</span>
        <span v-else-if="fromCache && status" class="clock-tag">Last known state</span>
      </div>

      <div class="clock-shift-line">Shift: {{ shiftLabel }}</div>

      <button
        class="clock-button"
        :class="{ 'is-out': clockedIn }"
        :disabled="loading || (statusLoading && !status)"
        @click="toggle"
      >
        {{ loading ? "Working..." : clockedIn ? "Clock Out" : "Clock In" }}
      </button>

      <!-- Announced to screen readers, as the spoken counterpart of the clock sounds. -->
      <p v-if="error" class="clock-alert clock-alert-error" role="alert">{{ error }}</p>
      <p v-else-if="lastAction" class="clock-alert clock-alert-success" role="status">{{ lastAction }}</p>

      <p v-if="pendingLabel" class="clock-pending" role="status">{{ pendingLabel }}</p>

      <ul v-if="rejected.length" class="clock-rejected" role="alert">
        <li v-for="item in rejected" :key="item.id">
          <span>{{ item.label }} made offline was refused: {{ item.message }}. Ask your manager to correct it.</span>
          <button type="button" class="clock-dismiss" @click="dismissRejected(item.id)">Dismiss</button>
        </li>
      </ul>
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

/* Offline mode */
.clock-banner {
  margin: 0 0 16px;
  padding: 10px 14px;
  font-size: 14px;
}
.clock-banner-offline { border: 1px solid #8a5a00; background: #fff4dc; color: #5c3d00; }
.clock-tag {
  display: inline-block;
  margin-left: 8px;
  padding: 2px 8px;
  border: 1px solid #8a5a00;
  color: #5c3d00;
  font-size: 12px;
}
.clock-pending { margin: 12px 0 0; color: #4f5d58; font-size: 14px; }
.clock-rejected { margin: 12px 0 0; padding: 0; list-style: none; text-align: left; }
.clock-rejected li {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border: 1px solid #a33b2b;
  color: #7a2a1e;
  font-size: 14px;
}
.clock-dismiss { border: 0; background: none; color: inherit; font-weight: 700; text-decoration: underline; cursor: pointer; }
</style>

<template>
  <div class="shift-backdrop" @click.self="$emit('close')">
    <div class="shift-modal" role="dialog" aria-modal="true" aria-labelledby="shift-title">
      <header class="shift-header">
        <div>
          <p class="eyebrow">Shift configuration</p>
          <h2 id="shift-title">{{ targetLabel }}</h2>
        </div>
        <button class="shift-close" type="button" aria-label="Close" @click="$emit('close')">×</button>
      </header>

      <p class="shift-help">
        Applies when this {{ targetType }} has no shift configured. Users fall back to their
        team shift, then to the global default.
      </p>

      <form class="shift-form" @submit.prevent="submit">
        <div class="shift-grid">
          <label>
            Start time
            <input v-model="startTime" type="time" required />
          </label>
          <label>
            End time
            <input v-model="endTime" type="time" required />
          </label>
        </div>

        <label>
          Timezone
          <select v-model="timezoneOffset">
            <option v-for="opt in timezoneOptions" :key="opt.value" :value="String(opt.value)">
              {{ opt.label }}
            </option>
            <option value="custom">Custom…</option>
          </select>
        </label>

        <label v-if="timezoneOffset === 'custom'">
          Custom offset (minutes from UTC)
          <input v-model.number="customOffset" type="number" min="-720" max="840" required />
        </label>

        <p v-if="error" class="shift-alert shift-alert-error">{{ error }}</p>

        <div class="shift-actions">
          <button
            type="button"
            class="btn-wt btn-outline"
            :disabled="saving"
            @click="clearShift"
          >
            Clear shift
          </button>
          <div class="shift-actions-right">
            <button type="button" class="btn-wt btn-outline" :disabled="saving" @click="$emit('close')">
              Cancel
            </button>
            <button type="submit" class="btn-wt btn-primary" :disabled="saving">
              {{ saving ? "Saving..." : "Save shift" }}
            </button>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { apiFetch } from "../services/auth";

const props = defineProps({
  // { type: "user" | "team", id: number, label: string }
  target: { type: Object, required: true }
});

const emit = defineEmits(["close", "saved"]);

const startTime = ref("09:00");
const endTime = ref("17:00");
const timezoneOffset = ref("0");
const customOffset = ref(0);
const saving = ref(false);
const error = ref("");

const targetType = computed(() => props.target.type);
const targetLabel = computed(() => props.target.label);

const timezoneOptions = [
  { value: 0, label: "UTC" },
  { value: 60, label: "UTC+01:00 (CET)" },
  { value: 120, label: "UTC+02:00 (CEST)" },
  { value: -300, label: "UTC-05:00 (EST)" },
  { value: -480, label: "UTC-08:00 (PST)" }
];

// --- Conversion helpers ----------------------------------------------------

// "09:00" -> 540
function timeToMinutes(value) {
  if (!value) return null;
  const [h, m] = value.split(":").map((n) => parseInt(n, 10));
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

// 540 -> "09:00"
function minutesToTime(mins) {
  if (mins == null) return "09:00";
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

function resolvedOffset() {
  if (timezoneOffset.value === "custom") {
    return Number(customOffset.value) || 0;
  }
  return Number(timezoneOffset.value) || 0;
}

// --- API -------------------------------------------------------------------

const endpoint = computed(() =>
  targetType.value === "user"
    ? `/api/admin/users/${props.target.id}/shift`
    : `/api/admin/teams/${props.target.id}/shift`
);

async function load() {
  try {
    const res = await apiFetch(endpoint.value);
    if (!res.ok) throw new Error(`Unable to load shift (${res.status})`);
    const body = await res.json();
    const data = body.data || body;

    if (data.shift_start_minutes != null) {
      startTime.value = minutesToTime(data.shift_start_minutes);
    }
    if (data.shift_end_minutes != null) {
      endTime.value = minutesToTime(data.shift_end_minutes);
    }
    const offset = data.timezone_offset_minutes ?? 0;
    const known = timezoneOptions.find((o) => o.value === offset);
    if (known) {
      timezoneOffset.value = String(offset);
    } else {
      timezoneOffset.value = "custom";
      customOffset.value = offset;
    }
  } catch (err) {
    error.value = err.message;
  }
}

async function submit() {
  const start = timeToMinutes(startTime.value);
  const end = timeToMinutes(endTime.value);

  if (start == null || end == null) {
    error.value = "Start and end times are required.";
    return;
  }
  if (end <= start) {
    error.value = "End time must be after start time.";
    return;
  }

  saving.value = true;
  error.value = "";

  try {
    const res = await apiFetch(endpoint.value, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        shift_start_minutes: start,
        shift_end_minutes: end,
        timezone_offset_minutes: resolvedOffset()
      })
    });

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      const detail = body.errors
        ? Object.values(body.errors).flat().join(", ")
        : body.error || `Unable to save (${res.status})`;
      throw new Error(detail);
    }

    emit("saved");
  } catch (err) {
    error.value = err.message;
  } finally {
    saving.value = false;
  }
}

async function clearShift() {
  if (!confirm("Clear this shift? The user/team will fall back to the next level (team/default).")) return;
  saving.value = true;
  error.value = "";

  try {
    const res = await apiFetch(endpoint.value, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        shift_start_minutes: null,
        shift_end_minutes: null,
        timezone_offset_minutes: 0
      })
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Unable to clear (${res.status})`);
    }
    emit("saved");
  } catch (err) {
    error.value = err.message;
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<style scoped>
.shift-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(36, 51, 50, 0.55);
  display: grid;
  place-items: center;
  z-index: 50;
  padding: 20px;
  overflow-y: auto;
}

.shift-modal {
  width: 100%;
  max-width: 520px;
  background: #fffdf7;
  border: 1px solid #d4d6cc;
  padding: 24px;
  display: grid;
  gap: 16px;
  box-shadow: 0 20px 60px rgba(36, 51, 50, 0.25);
}

.shift-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.shift-header h2 {
  margin: 0;
  font: 600 20px "Manrope", sans-serif;
  letter-spacing: -0.03em;
  color: #243332;
}

.shift-close {
  border: 0;
  background: transparent;
  color: #71807a;
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
}

.shift-help {
  margin: 0;
  color: #71807a;
  font-size: 12px;
  line-height: 1.5;
}

.shift-form {
  display: grid;
  gap: 14px;
}

.shift-form label {
  display: grid;
  gap: 6px;
  color: #65746e;
  font: 11px "DM Mono", monospace;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.shift-form input,
.shift-form select {
  width: 100%;
  border: 0;
  border-bottom: 1px solid #bcc4b8;
  background: transparent;
  color: #263836;
  padding: 8px 0;
  font: 13px "Manrope", sans-serif;
  outline: 0;
}

.shift-form input:focus,
.shift-form select:focus {
  border-color: #bd684c;
  box-shadow: 0 2px 0 #bd684c;
}

.shift-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.shift-alert {
  margin: 0;
  font-size: 12px;
}

.shift-alert-error {
  color: #a3614a;
}

.shift-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-top: 8px;
}

.shift-actions-right {
  display: flex;
  gap: 12px;
}

@media (max-width: 480px) {
  .shift-grid {
    grid-template-columns: 1fr;
  }

  .shift-actions {
    flex-direction: column-reverse;
    align-items: stretch;
  }

  .shift-actions-right {
    flex-direction: column-reverse;
  }

  .shift-actions button {
    width: 100%;
  }
}
</style>
<template>
  <div class="correction-backdrop" @click.self="$emit('close')">
    <div class="correction-modal" role="dialog" aria-modal="true" aria-labelledby="correction-title">
      <header class="correction-header">
        <div>
          <p class="eyebrow">Request a correction</p>
          <h2 id="correction-title">Working time #{{ workingTime.id }}</h2>
        </div>
        <button class="correction-close" type="button" aria-label="Close" @click="$emit('close')">×</button>
      </header>

      <div class="correction-current">
        <div class="correction-current-row">
          <span class="label">Current start</span>
          <span class="value">{{ formatForDisplay(workingTime.start) }}</span>
        </div>
        <div class="correction-current-row">
          <span class="label">Current end</span>
          <span class="value">{{ formatForDisplay(workingTime.end) }}</span>
        </div>
      </div>

      <form class="correction-form" @submit.prevent="submit">
        <label>
          Reason <span class="required">*</span>
          <textarea
            v-model="reason"
            rows="3"
            required
            placeholder="Explain why this entry needs to be corrected"
          ></textarea>
        </label>

        <div class="correction-grid">
          <label>
            Proposed start (optional)
            <input v-model="proposedStart" type="datetime-local" />
          </label>
          <label>
            Proposed end (optional)
            <input v-model="proposedEnd" type="datetime-local" />
          </label>
        </div>

        <p class="correction-hint">
          Leave the proposed times blank if you just want a reviewer to decide.
        </p>

        <p v-if="error" class="correction-alert correction-alert-error">{{ error }}</p>

        <div class="correction-actions">
          <button type="button" class="btn-wt btn-outline" :disabled="submitting" @click="$emit('close')">
            Cancel
          </button>
          <button type="submit" class="btn-wt btn-primary" :disabled="submitting || !reason.trim()">
            {{ submitting ? "Submitting..." : "Submit request" }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { apiFetch } from "../services/auth";

const props = defineProps({
  workingTime: { type: Object, required: true }
});

const emit = defineEmits(["close", "submitted"]);

const reason = ref("");
const proposedStart = ref("");
const proposedEnd = ref("");
const error = ref("");
const submitting = ref(false);

function formatForDisplay(value) {
  if (!value) return "—";
  return value.replace("T", " ").substring(0, 19);
}

// Convert a datetime-local input value into the ISO-ish string the API accepts.
function inputToApi(value) {
  if (!value) return null;
  const d = new Date(value);
  if (isNaN(d.getTime())) return null;
  return d.toISOString();
}

async function submit() {
  if (!reason.value.trim()) {
    error.value = "A reason is required.";
    return;
  }

  submitting.value = true;
  error.value = "";

  try {
    const res = await apiFetch(
      `/api/workingtime/${props.workingTime.id}/correction-requests`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          reason: reason.value.trim(),
          proposed_start: inputToApi(proposedStart.value),
          proposed_end: inputToApi(proposedEnd.value)
        })
      }
    );

    const body = await res.json().catch(() => ({}));

    if (!res.ok) {
      error.value = body.error || `Unable to submit request (${res.status})`;
      return;
    }

    emit("submitted");
  } catch (err) {
    error.value = err.message || "Unable to submit request.";
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
.correction-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(36, 51, 50, 0.55);
  display: grid;
  place-items: center;
  z-index: 50;
  padding: 20px;
  overflow-y: auto;
}

.correction-modal {
  width: 100%;
  max-width: 520px;
  background: #fffdf7;
  border: 1px solid #d4d6cc;
  padding: 24px;
  display: grid;
  gap: 18px;
  box-shadow: 0 20px 60px rgba(36, 51, 50, 0.25);
}

.correction-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.correction-header h2 {
  margin: 0;
  font: 600 20px "Manrope", sans-serif;
  letter-spacing: -0.03em;
  color: #243332;
}

.correction-close {
  border: 0;
  background: transparent;
  color: #71807a;
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
  padding: 0 4px;
}

.correction-current {
  display: grid;
  gap: 6px;
  padding: 12px 14px;
  background: #e4e7de;
  border-left: 3px solid #263b38;
}

.correction-current-row {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #71807a;
}

.correction-current-row .value {
  color: #243332;
  font-family: "DM Mono", monospace;
}

.correction-form {
  display: grid;
  gap: 14px;
}

.correction-form label {
  display: grid;
  gap: 6px;
  color: #65746e;
  font: 11px "DM Mono", monospace;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.correction-form textarea,
.correction-form input {
  width: 100%;
  border: 0;
  border-bottom: 1px solid #bcc4b8;
  background: transparent;
  color: #263836;
  padding: 8px 0;
  font: 13px "Manrope", sans-serif;
  outline: 0;
  resize: vertical;
}

.correction-form textarea:focus,
.correction-form input:focus {
  border-color: #bd684c;
  box-shadow: 0 2px 0 #bd684c;
}

.correction-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.correction-hint {
  margin: 0;
  color: #71807a;
  font-size: 11px;
}

.correction-alert {
  margin: 0;
  font-size: 12px;
}

.correction-alert-error {
  color: #a3614a;
}

.correction-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.required {
  color: #a3614a;
}

@media (max-width: 480px) {
  .correction-grid {
    grid-template-columns: 1fr;
  }

  .correction-actions {
    flex-direction: column-reverse;
  }

  .correction-actions > button {
    width: 100%;
  }
}
</style>
<template>
  <main class="wt-wrapper">
    <header class="wt-header">
      <div class="wt-title-group">
        <p class="wt-eyebrow">User ID: {{ currentUserId }}</p>
        <h1>{{ isEditMode ? 'Edit' : 'Create' }} a <em>working-time entry</em></h1>
      </div>
      <div class="wt-actions">
        <RouterLink :to="`/workingTimes/${currentUserId}`" class="btn-wt btn-outline">
          <span>&larr; Back to list</span>
        </RouterLink>
      </div>
    </header>

    <!-- Feedback Alerts -->
    <div v-if="error" class="wt-alert wt-alert-error">
      <span>Error: {{ error }}</span>
      <button class="btn-link" @click="error = ''">Close</button>
    </div>

    <div v-if="successMessage" class="wt-alert wt-alert-success">
      <span>{{ successMessage }}</span>
      <button class="btn-link" @click="successMessage = ''">Close</button>
    </div>

    <!-- Form Card -->
    <section class="wt-form-card">
      <form @submit.prevent="handleSubmit">
        <p class="wt-tz-hint">
          Times are entered and displayed in your browser's timezone ({{ tzLabel }}).
        </p>

        <div class="wt-form-grid">
          <div class="wt-field">
            <label for="wt-start">Start date &amp; time</label>
            <input
              id="wt-start"
              v-model="start"
              type="datetime-local"
              required
            />
          </div>

          <div class="wt-field">
            <label for="wt-end">End date &amp; time</label>
            <input
              id="wt-end"
              v-model="end"
              type="datetime-local"
              required
            />
          </div>
        </div>

        <!-- Calculated Duration Live Preview -->
        <div v-if="start && end" class="wt-preview-box">
          Calculated duration: <strong>{{ calculatedDuration }}</strong>
          <span v-if="apiStartFormatted && apiEndFormatted" class="wt-preview-hint">
            (submitted as {{ apiStartFormatted }} → {{ apiEndFormatted }} UTC)
          </span>
        </div>

        <!-- Action Buttons -->
        <div class="wt-actions wt-actions-end">
          <button
            v-if="!isEditMode"
            type="button"
            class="btn-wt btn-primary"
            :disabled="saving || !start || !end"
            @click="createWorkingTime"
          >
            <span>{{ saving ? 'Creating...' : 'Create working time' }}</span>
          </button>

          <template v-else>
            <button
              type="button"
              class="btn-wt btn-primary"
              :disabled="saving || !start || !end"
              @click="updateWorkingTime"
            >
              <span>{{ saving ? 'Saving...' : 'Update' }}</span>
            </button>
            <button
              type="button"
              class="btn-wt btn-danger"
              :disabled="saving"
              @click="deleteWorkingTime"
            >
              <span>Delete</span>
            </button>
          </template>
        </div>
      </form>
    </section>
  </main>
</template>

<script>
import "./WorkingTime.css";
import { apiFetch } from "../services/auth";
import {
  utcToLocalInput,
  localInputToUtc,
  minutesBetween,
  formatMinutes,
  browserTimezoneLabel
} from "../utils/datetime";

export default {
  name: "WorkingTime",

  props: {
    userId: {
      type: [Number, String],
      default: null
    },
    workingTimeId: {
      type: [Number, String],
      default: null
    },
    workingTimeData: {
      type: Object,
      default: null
    }
  },

  data() {
    return {
      start: "",
      end: "",
      saving: false,
      loading: false,
      error: "",
      successMessage: "",
      tzLabel: browserTimezoneLabel()
    };
  },

  computed: {
    currentUserId() {
      if (this.userId) return this.userId;
      return this.$route.params.userid || this.$route.params.userID || 1;
    },

    currentWorkingTimeId() {
      if (this.workingTimeId) return this.workingTimeId;
      return this.$route.params.workingtimeid || this.$route.params.id || null;
    },

    isEditMode() {
      return !!this.currentWorkingTimeId;
    },

    // Convert the local datetime-local values to UTC ISO strings for the API.
    apiStartFormatted() {
      return localInputToUtc(this.start);
    },

    apiEndFormatted() {
      return localInputToUtc(this.end);
    },

    calculatedDuration() {
      if (!this.start || !this.end) return "—";
      const startUtc = localInputToUtc(this.start);
      const endUtc = localInputToUtc(this.end);
      if (!startUtc || !endUtc) return "Invalid";

      const diff = new Date(endUtc) - new Date(startUtc);
      if (isNaN(diff) || diff < 0) {
        return "Invalid (end must be after start)";
      }
      return formatMinutes(Math.floor(diff / 60000));
    }
  },

  watch: {
    workingTimeData: {
      immediate: true,
      handler(newVal) {
        if (newVal && newVal.start) {
          this.start = utcToLocalInput(newVal.start);
          this.end = utcToLocalInput(newVal.end);
        }
      }
    },
    "$route.params": {
      immediate: true,
      handler() {
        this.fetchExistingWorkingTime();
      }
    }
  },

  mounted() {
    this.fetchExistingWorkingTime();
  },

  methods: {
    async fetchExistingWorkingTime() {
      if (!this.isEditMode) return;
      if (this.workingTimeData && this.workingTimeData.start) return;

      this.loading = true;
      this.error = "";

      try {
        const response = await apiFetch(
          `/api/workingtime/${this.currentUserId}/${this.currentWorkingTimeId}`
        );

        if (!response.ok) {
          // Fallback: list and filter
          const fallback = await apiFetch(`/api/workingtime/${this.currentUserId}`);
          if (!fallback.ok) throw new Error("Unable to fetch entry details.");
          const result = await fallback.json();
          const items = result.data || result || [];
          const match = items.find(
            (item) => String(item.id) === String(this.currentWorkingTimeId)
          );
          if (match) {
            this.start = utcToLocalInput(match.start);
            this.end = utcToLocalInput(match.end);
            return;
          }
          throw new Error("Entry not found.");
        }

        const data = await response.json();
        const wt = data.data || data;
        if (wt && wt.start) {
          this.start = utcToLocalInput(wt.start);
          this.end = utcToLocalInput(wt.end);
        }
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to load entry.";
      } finally {
        this.loading = false;
      }
    },

    handleSubmit() {
      if (this.isEditMode) this.updateWorkingTime();
      else this.createWorkingTime();
    },

    async createWorkingTime() {
      if (!this.start || !this.end) {
        this.error = "Please provide both a start and an end time.";
        return;
      }

      this.saving = true;
      this.error = "";
      this.successMessage = "";

      try {
        const payload = {
          workingtime: {
            start: this.apiStartFormatted,
            end: this.apiEndFormatted
          }
        };

        const response = await apiFetch(`/api/workingtime/${this.currentUserId}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          const errData = await response.json().catch(() => ({}));
          const detail = errData.errors?.user_id
            ? "The specified user does not exist."
            : `Error code: ${response.status}`;
          throw new Error(`Creation failed (${detail})`);
        }

        this.successMessage = "Working time created.";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to create working time.";
      } finally {
        this.saving = false;
      }
    },

    async updateWorkingTime() {
      if (!this.currentWorkingTimeId) return;
      if (!this.start || !this.end) {
        this.error = "Please provide both a start and an end time.";
        return;
      }

      this.saving = true;
      this.error = "";
      this.successMessage = "";

      try {
        const payload = {
          workingtime: {
            start: this.apiStartFormatted,
            end: this.apiEndFormatted
          }
        };

        const response = await apiFetch(
          `/api/workingtime/${this.currentWorkingTimeId}`,
          {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          }
        );

        if (!response.ok) {
          throw new Error(`Update failed (Status: ${response.status})`);
        }

        this.successMessage = "Working time updated.";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to update working time.";
      } finally {
        this.saving = false;
      }
    },

    async deleteWorkingTime() {
      if (!this.currentWorkingTimeId) return;
      if (!confirm("Delete this working-time entry?")) return;

      this.saving = true;
      this.error = "";

      try {
        const response = await apiFetch(
          `/api/workingtime/${this.currentWorkingTimeId}`,
          { method: "DELETE" }
        );

        if (!response.ok) {
          throw new Error(`Delete failed (Status: ${response.status})`);
        }

        this.successMessage = "Working time deleted.";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to delete working time.";
      } finally {
        this.saving = false;
      }
    }
  }
};
</script>
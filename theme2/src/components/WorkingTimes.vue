<template>
  <component :is="layout">
    <main class="wt-wrapper">
    <!-- Header Section -->
    <header class="wt-header">
      <div class="wt-title-group">
        <p class="wt-eyebrow">Times shown in {{ tzLabel }}</p>
        <h1>Working Times <em>History</em></h1>
      </div>
      <p v-if="entriesLockedOffline" class="wt-muted" role="note">Creating, editing and deleting entries requires a connection.</p>
      <div class="wt-actions">
        <button class="btn-wt btn-outline" @click="getWorkingTimes" :disabled="loading">
          <span>Refresh</span>
        </button>
        <button
          v-if="canManageEntries"
          type="button"
          class="btn-wt btn-primary"
          @click="goToCreateEntry"
        >
          <span>+ Create entry</span>
        </button>
      </div>
    </header>

    <!-- Date Range Filter Toolbar -->
    <section class="wt-toolbar" aria-label="Filter working times">
      <div class="wt-field">
        <label for="filter-start">Start date</label>
        <input id="filter-start" v-model="startDateFilter" type="datetime-local" @change="getWorkingTimes" />
      </div>
      <div class="wt-field">
        <label for="filter-end">End date</label>
        <input id="filter-end" v-model="endDateFilter" type="datetime-local" @change="getWorkingTimes" />
      </div>
      <div class="wt-toolbar-actions">
        <button v-if="startDateFilter || endDateFilter" class="btn-wt btn-secondary" @click="clearFilters">
          Reset
        </button>
      </div>
    </section>

    <!-- Feedback Alerts -->
    <div v-if="error" class="wt-alert wt-alert-error">
      <span>Error: {{ error }}</span>
      <button class="btn-link" @click="error = ''">Close</button>
    </div>

    <div v-if="successMessage" class="wt-alert wt-alert-success">
      <span>{{ successMessage }}</span>
      <button class="btn-link" @click="successMessage = ''">Close</button>
    </div>

    <!-- Summary Stats -->
    <div v-if="!loading && workingTimes.length > 0" class="wt-stats">
      <div class="wt-stat-card">
        <div class="wt-stat-label">Total entries</div>
        <div class="wt-stat-value">{{ workingTimes.length }}</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-label">Total time</div>
        <div class="wt-stat-value">{{ totalHoursFormatted }}</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-label">Average / entry</div>
        <div class="wt-stat-value">{{ avgHoursFormatted }}</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-label">Overtime</div>
        <div class="wt-stat-value">{{ totalOvertimeFormatted }}</div>
      </div>
    </div>

    <!-- Working Times Table Card -->
    <section class="wt-table-card">
      <div v-if="loading" class="wt-empty-state">
        <p>Loading working times...</p>
      </div>

      <div v-else-if="workingTimes.length === 0" class="wt-empty-state">
        <h3>No working times recorded</h3>
        <p>No entries match the current criteria for this user.</p>
        <button
          v-if="canManageEntries"
          type="button"
          class="btn-wt btn-primary"
          @click="goToCreateEntry"
        >
          Create first entry
        </button>
      </div>

      <table v-else class="wt-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Start (local)</th>
            <th>End (local)</th>
            <th>Duration</th>
            <th>Overtime</th>
            <th>Source</th>
            <th class="wt-actions-header">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="wt in workingTimes" :key="wt.id">
            <td>
              <span class="wt-badge">#{{ wt.id }}</span>
            </td>
            <td>
              <span class="wt-time-code">{{ formatDate(wt.start) }}</span>
            </td>
            <td>
              <span class="wt-time-code">{{ formatDate(wt.end) }}</span>
            </td>
            <td>
              <strong>{{ getDuration(wt.start, wt.end) }}</strong>
            </td>
            <td>
              <span v-if="wt.overtime_minutes > 0" class="wt-overtime-badge">
                +{{ formatMinutes(wt.overtime_minutes) }}
              </span>
              <span v-else class="wt-muted">—</span>
            </td>
            <td>
              <span class="wt-source-badge" :class="`wt-source-${wt.source}`">{{ wt.source }}</span>
            </td>
            <td>
              <div class="wt-table-actions">
                <RouterLink
                  v-if="canManageEntries"
                  :to="`/workingTime/${currentUserId}/${wt.id}`"
                  class="btn-wt btn-secondary"
                >
                  Edit
                </RouterLink>
                <button
                  v-if="canRequestCorrection"
                  class="btn-wt btn-secondary"
                  @click="openCorrection(wt)"
                >
                  Request correction
                </button>
                <button
                  v-if="canManageEntries"
                  class="btn-wt btn-danger"
                  @click="deleteWorkingTime(wt.id)"
                >
                  Delete
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <!-- Correction Request Modal -->
    <CorrectionRequestModal
      v-if="correctionTarget"
      :working-time="correctionTarget"
      @close="correctionTarget = null"
      @submitted="onCorrectionSubmitted"
      />
    </main>
  </component>
</template>

<script>
import "./WorkingTime.css";
import { apiFetch, authState } from "../services/auth";
import { network } from "../platform/network";
import CorrectionRequestModal from "./CorrectionRequestModal.vue";
import AppLayout from "./AppLayout.vue";
import {
  parseUtc,
  formatDateOnly,
  formatTimeLong,
  formatDateTimeForDisplay,
  formatMinutes,
  minutesBetween,
  localInputToUtc,
  browserTimezoneLabel
} from "../utils/datetime";

export default {
  name: "WorkingTimes",

  components: { AppLayout, CorrectionRequestModal },

  props: {
    userId: {
      type: [Number, String],
      default: null
    }
  },

  data() {
    return {
      workingTimes: [],
      loading: false,
      error: "",
      successMessage: "",
      startDateFilter: "",
      endDateFilter: "",
      correctionTarget: null,
      tzLabel: browserTimezoneLabel()
    };
  },

  computed: {
    // Wrap with AppLayout only when rendered as a standalone route.
    // When rendered as a tab inside User.vue, User.vue provides the layout.
    layout() {
      return this.$route.name === "WorkingTimes" ? "AppLayout" : "div";
    },

    currentUserId() {
      if (this.userId) return this.userId;
      return this.$route.params.userID || this.$route.params.userid || 1;
    },

    // Only employees request corrections to their own records. Managers and
    // administrators use the Edit action directly.
    canRequestCorrection() {
      return authState.user?.role === "employee";
    },

    // Manual creation and direct edit/delete are for reviewers only.
    // Employees get their records from clocking in/out.
    canManageEntries() {
      return authState.user?.role !== "employee" && this.online;
    },

    // Reviewers editing entries offline: explain why the buttons are gone.
    entriesLockedOffline() {
      return authState.user?.role !== "employee" && !this.online;
    },

    online() {
      return network.online.value;
    },

    totalOvertimeFormatted() {
      const total = this.workingTimes.reduce(
        (sum, wt) => sum + (wt.overtime_minutes || 0),
        0
      );
      return this.formatMinutes(total);
    },

    totalHoursFormatted() {
      let totalMinutes = 0;
      for (const wt of this.workingTimes) {
        // An entry still in progress (no end yet) counts as zero.
        const minutes = minutesBetween(wt.start, wt.end);
        if (minutes > 0) {
          totalMinutes += minutes;
        }
      }
      const hrs = Math.floor(totalMinutes / 60);
      const mins = totalMinutes % 60;
      return `${hrs}h ${mins > 0 ? mins + "m" : ""}`;
    },

    avgHoursFormatted() {
      if (this.workingTimes.length === 0) return "0h";
      let totalMinutes = 0;
      let validCount = 0;
      for (const wt of this.workingTimes) {
        // An entry still in progress (no end yet) counts as zero.
        const minutes = minutesBetween(wt.start, wt.end);
        if (minutes > 0) {
          totalMinutes += minutes;
          validCount++;
        }
      }
      if (validCount === 0) return "0h";
      const avgMins = Math.round(totalMinutes / validCount);
      const hrs = Math.floor(avgMins / 60);
      const mins = avgMins % 60;
      return `${hrs}h ${mins > 0 ? mins + "m" : ""}`;
    }
  },

  watch: {
    "$route.params.userID": {
      immediate: true,
      handler() {
        this.getWorkingTimes();
      }
    },
    "$route.params.userid": {
      handler() {
        this.getWorkingTimes();
      }
    }
  },

  mounted() {
    this.getWorkingTimes();
  },

  methods: {
    // Display UTC ISO strings as browser-local "YYYY-MM-DD HH:MM:SS".
    formatDate(dateStr) {
      return formatDateTimeForDisplay(parseUtc(dateStr));
    },

    // Format minutes as "2h 04m" or "34m".
    formatMinutes(mins) {
      return formatMinutes(mins);
    },

    // Convert a datetime-local input value to a UTC ISO string.
    formatInputToApi(inputVal) {
      return localInputToUtc(inputVal);
    },

    // Duration between two UTC ISO strings.
    getDuration(startStr, endStr) {
      const start = parseUtc(startStr);
      const end = parseUtc(endStr);
      if (!start || !end) return "—";
      const diff = Math.floor((end.getTime() - start.getTime()) / 60000);
      if (diff <= 0) return "—";
      return formatMinutes(diff);
    },

    async getWorkingTimes() {
      this.loading = true;
      this.error = "";

      try {
        let url = `/api/workingtime/${this.currentUserId}`;
        const params = new URLSearchParams();

        if (this.startDateFilter) {
          params.append("start", this.formatInputToApi(this.startDateFilter));
        }
        if (this.endDateFilter) {
          params.append("end", this.formatInputToApi(this.endDateFilter));
        }

        const queryString = params.toString();
        if (queryString) {
          url += `?${queryString}`;
        }

        const response = await apiFetch(url);
        if (!response.ok) {
          throw new Error(`Failed to fetch (Status: ${response.status})`);
        }

        const result = await response.json();
        this.workingTimes = result.data || result || [];
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to load working times.";
      } finally {
        this.loading = false;
      }
    },

    async deleteWorkingTime(id) {
      if (!confirm("Delete this working-time entry?")) return;

      try {
        const response = await apiFetch(`/api/workingtime/${id}`, {
          method: "DELETE"
        });

        if (!response.ok) {
          throw new Error(`Delete failed (Status: ${response.status})`);
        }

        this.successMessage = "Working-time entry deleted.";
        this.workingTimes = this.workingTimes.filter((wt) => wt.id !== id);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Unable to delete entry.";
      }
    },

    // Notify the parent (User.vue switches tabs) AND fall back to a direct
    // navigation if we're rendered standalone (no parent listener).
    goToCreateEntry() {
      const hasParentHandler =
        this.$attrs &&
        (this.$attrs.onGoCreateEntry || this.$attrs["onGo-create-entry"]);

      this.$emit("go-create-entry");

      if (!hasParentHandler) {
        // Standalone route: navigate to the dedicated create page.
        this.$router.push(`/workingTime/${this.currentUserId}`);
      }
    },

    openCorrection(wt) {
      this.correctionTarget = wt;
    },

    onCorrectionSubmitted({ queued } = {}) {
      this.correctionTarget = null;
      this.successMessage = queued
        ? "Correction request saved on this device. It will be sent when the connection returns."
        : "Correction request submitted.";
    },

    clearFilters() {
      this.startDateFilter = "";
      this.endDateFilter = "";
      this.getWorkingTimes();
    }
  }
};
</script>
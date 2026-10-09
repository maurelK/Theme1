<template>
  <main class="wt-wrapper">
    <!-- Header Section -->
    <header class="wt-header">
      <div class="wt-title-group">
        <p class="wt-eyebrow">User ID: {{ currentUserId }}</p>
        <h1>Working Times <em>History</em></h1>
      </div>
      <div class="wt-actions">
        <button class="btn-wt btn-outline" @click="getWorkingTimes" :disabled="loading">
          <span>Refresh</span>
        </button>
        <button
          v-if="canManageEntries"
          type="button"
          class="btn-wt btn-primary"
          @click="$emit('go-create-entry')"
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
          style="margin-top: 16px;"
          @click="$emit('go-create-entry')"
        >
          Create first entry
        </button>
      </div>

      <table v-else class="wt-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Start (YYYY-MM-DD hh:mm:ss)</th>
            <th>End (YYYY-MM-DD hh:mm:ss)</th>
            <th>Duration</th>
            <th>Overtime</th>
            <th>Source</th>
            <th style="text-align: right;">Actions</th>
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
                  style="padding: 6px 12px; font-size: 11px;"
                >
                  Edit
                </RouterLink>
                <button
                  v-if="canRequestCorrection"
                  class="btn-wt btn-secondary"
                  style="padding: 6px 12px; font-size: 11px;"
                  @click="openCorrection(wt)"
                >
                  Request correction
                </button>
                <button
                  v-if="canManageEntries"
                  class="btn-wt btn-danger"
                  style="padding: 6px 12px; font-size: 11px;"
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
</template>

<script>
import "./WorkingTime.css";
import { apiFetch, authState } from "../services/auth";
import CorrectionRequestModal from "./CorrectionRequestModal.vue";

export default {
  name: "WorkingTimes",

  components: { CorrectionRequestModal },

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
      correctionTarget: null
    };
  },

  computed: {
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
      return authState.user?.role !== "employee";
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
        const ms = new Date(wt.end.replace(" ", "T")) - new Date(wt.start.replace(" ", "T"));
        if (!isNaN(ms) && ms > 0) {
          totalMinutes += Math.floor(ms / 60000);
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
        const ms = new Date(wt.end.replace(" ", "T")) - new Date(wt.start.replace(" ", "T"));
        if (!isNaN(ms) && ms > 0) {
          totalMinutes += Math.floor(ms / 60000);
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
    formatDate(dateStr) {
      if (!dateStr) return "";
      const formatted = dateStr.replace("T", " ").substring(0, 19);
      if (formatted.length === 16) return formatted + ":00";
      return formatted;
    },

    formatMinutes(mins) {
      if (!mins) return "0m";
      const h = Math.floor(mins / 60);
      const m = mins % 60;
      if (h === 0) return `${m}m`;
      return `${h}h ${String(m).padStart(2, "0")}m`;
    },

    formatInputToApi(inputVal) {
      if (!inputVal) return "";
      const d = new Date(inputVal);
      if (isNaN(d.getTime())) return inputVal;
      const pad = (n) => String(n).padStart(2, "0");
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    },

    getDuration(startStr, endStr) {
      if (!startStr || !endStr) return "-";
      const start = new Date(startStr.replace(" ", "T"));
      const end = new Date(endStr.replace(" ", "T"));
      const diffMs = end - start;
      if (isNaN(diffMs) || diffMs < 0) return "-";
      const mins = Math.floor(diffMs / 60000);
      return this.formatMinutes(mins);
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

    openCorrection(wt) {
      this.correctionTarget = wt;
    },

    onCorrectionSubmitted() {
      this.correctionTarget = null;
      this.successMessage = "Correction request submitted.";
    },

    clearFilters() {
      this.startDateFilter = "";
      this.endDateFilter = "";
      this.getWorkingTimes();
    }
  }
};
</script>
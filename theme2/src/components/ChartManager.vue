<template>
  <component :is="layout">
    <main id="charts" class="chart-page">
      <header class="chart-hero">
        <div>
          <p class="chart-kicker">Working hours</p>
          <h1>Hours per day<br><em>and per week.</em></h1>
        </div>
        <p class="chart-subtitle">Completed entries over the selected period. Leave the dates empty to see everything.</p>
      </header>

      <section class="date-toolbar" aria-label="Filter working times">
        <label class="date-field">
          From
          <input v-model="startDate" type="date">
        </label>
        <label class="date-field">
          To
          <input v-model="endDate" type="date">
        </label>
        <button class="clear-dates" type="button" @click="startDate = ''; endDate = ''">Clear dates</button>
      </section>

      <p v-if="loading" class="chart-status">Loading working times...</p>
      <p v-if="error" class="chart-status chart-status-error">{{ error }}</p>

      <section v-if="!loading && !error" class="chart-grid" aria-label="Working time charts">
        <article class="chart-card chart-card-wide"><WorkingHoursBarChart :workingTimes="filteredWorkingTimes" /></article>
        <article class="chart-card"><WorkingHoursLineChart :workingTimes="filteredWorkingTimes" /></article>
        <article class="chart-card chart-card-pie"><WorkingHoursPieChart :workingTimes="filteredWorkingTimes" /></article>
      </section>

      <!-- Text equivalent of the charts, for screen readers and low-vision users. -->
      <section v-if="!loading && !error && dailyHours.length > 0" class="chart-tables" aria-label="Working hours as tables">
        <p class="chart-averages">
          Average: <strong>{{ averageDaily }} h</strong> per day worked,
          <strong>{{ averageWeekly }} h</strong> per week.
        </p>
        <table class="chart-table">
          <caption>Hours per week</caption>
          <thead><tr><th scope="col">Week starting</th><th scope="col">Hours</th></tr></thead>
          <tbody>
            <tr v-for="week in weeklyHours" :key="week.key"><td>{{ week.key }}</td><td>{{ week.hours.toFixed(1) }}</td></tr>
          </tbody>
        </table>
        <table class="chart-table">
          <caption>Hours per day</caption>
          <thead><tr><th scope="col">Date</th><th scope="col">Hours</th></tr></thead>
          <tbody>
            <tr v-for="day in dailyHours" :key="day.key"><td>{{ day.key }}</td><td>{{ day.hours.toFixed(1) }}</td></tr>
          </tbody>
        </table>
      </section>
      </main>
  </component>
</template>

<script>
import WorkingHoursBarChart from "./WorkingHoursBarChart.vue";
import WorkingHoursLineChart from "./WorkingHoursLineChart.vue";
import WorkingHoursPieChart from "./WorkingHoursPieChart.vue";
import AppLayout from "./AppLayout.vue";
// Route chart data requests through the shared authenticated API helper.
import { apiFetch } from "../services/auth";
import { parseUtc } from "../utils/datetime";
import { hoursByDay, hoursByWeek, localDateKey } from "../utils/workingHours";

const average = (buckets) =>
  buckets.length ? (buckets.reduce((sum, b) => sum + b.hours, 0) / buckets.length).toFixed(1) : "0.0";

export default {
  name: "ChartManager",

  components: {
    AppLayout,
    WorkingHoursBarChart,
    WorkingHoursLineChart,
    WorkingHoursPieChart
  },

  props: {
    userId: {
      type: [Number, String],
      default: null
    }
  },

  data() {
    return {
      workingTimes: [],
      startDate: "",
      endDate: "",
      loading: false,
      error: ""
    };
  },

  computed: {
    targetUserId() {
      const u = this.userId;
      if (u !== null && u !== undefined && u !== 'null' && u !== 'undefined' && u !== '') {
        return u;
      }
      const rp = this.$route && this.$route.params ? (this.$route.params.userid || this.$route.params.userID) : null;
      if (rp !== null && rp !== undefined && rp !== 'null' && rp !== 'undefined' && rp !== '') {
        return rp;
      }
      return null;
    },

    // Wrap with AppLayout only when rendered as a standalone route.
    // When rendered as a tab inside User.vue, User.vue already provides the layout.
    layout() {
      return this.$route.name === "ChartManager" ? "AppLayout" : "div";
    },

    filteredWorkingTimes() {
      return this.workingTimes.filter((workingTime) => {
        const start = parseUtc(workingTime?.start);
        if (!start) return false;
        // Compare in the browser timezone, like the charts do.
        const workingDate = localDateKey(start);

        if (this.startDate && workingDate < this.startDate) {
          return false;
        }

        if (this.endDate && workingDate > this.endDate) {
          return false;
        }

        return true;
      });
    },

    dailyHours() {
      return hoursByDay(this.filteredWorkingTimes);
    },

    weeklyHours() {
      return hoursByWeek(this.filteredWorkingTimes);
    },

    averageDaily() {
      return average(this.dailyHours);
    },

    averageWeekly() {
      return average(this.weeklyHours);
    }
  },

  watch: {
    targetUserId: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.getWorkingTimes();
        }
      }
    }
  },

  mounted() {
    if (this.targetUserId) {
      this.getWorkingTimes();
    }
  },

  methods: {
    async getWorkingTimes() {
      const uid = this.targetUserId;
      if (!uid || uid === "undefined" || uid === "null") return;
      this.loading = true;
      this.error = "";
      this.workingTimes = [];
      this.startDate = "";
      this.endDate = "";

      try {
        const response = await apiFetch(`/api/workingtime/${uid}`);

        if (!response.ok) {
          throw new Error("Failed to get working times");
        }

        const result = await response.json();
        this.workingTimes = Array.isArray(result.data) ? result.data : (Array.isArray(result) ? result : []);
      } catch (error) {
        console.error(error);
        this.error = "Could not load working times.";
      } finally {
        this.loading = false;
      }
    }
  }
};
</script>

<style src="./ChartManager.css"></style>
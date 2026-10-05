<template>
  <main id="charts" class="chart-page">
    <header class="chart-hero">
      <div>
        <p class="chart-kicker">Time Manager / Insights</p>
        <h1>See how your<br><em>time moves.</em></h1>
      </div>
      <p class="chart-subtitle">A clear view of your working rhythm, day by day and over time.</p>
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
  </main>
</template>

<script>
import WorkingHoursBarChart from "./WorkingHoursBarChart.vue";
import WorkingHoursLineChart from "./WorkingHoursLineChart.vue";
import WorkingHoursPieChart from "./WorkingHoursPieChart.vue";
// Route chart data requests through the shared authenticated API helper.
import { apiFetch } from "../services/auth";

export default {
  name: "ChartManager",

  components: {
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

    filteredWorkingTimes() {
      return this.workingTimes.filter((workingTime) => {
        if (!workingTime || !workingTime.start) return false;
        const workingDate = workingTime.start.substring(0, 10);

        if (this.startDate && workingDate < this.startDate) {
          return false;
        }

        if (this.endDate && workingDate > this.endDate) {
          return false;
        }

        return true;
      });
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

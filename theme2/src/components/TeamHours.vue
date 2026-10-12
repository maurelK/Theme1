<template>
  <section class="team-hours" aria-labelledby="team-hours-title">
    <h3 id="team-hours-title">Working hours</h3>

    <div class="date-toolbar" role="group" aria-label="Period">
      <label class="date-field">From<input v-model="startDate" type="date"></label>
      <label class="date-field">To<input v-model="endDate" type="date"></label>
    </div>

    <p v-if="loading" class="chart-status">Loading working times...</p>
    <p v-else-if="error" class="chart-status chart-status-error" role="alert">{{ error }}</p>

    <template v-else>
      <p v-if="memberStats.length === 0" class="chart-status">This team has no members.</p>

      <template v-else>
        <dl class="team-hours-summary">
          <div>
            <dt>Team average per day</dt>
            <dd>{{ teamDailyAverage }} h</dd>
          </div>
          <div>
            <dt>Team average per week</dt>
            <dd>{{ teamWeeklyAverage }} h</dd>
          </div>
          <div>
            <dt>Total over the period</dt>
            <dd>{{ teamTotal }} h</dd>
          </div>
        </dl>
        <p class="team-hours-note">
          Averages per member, counting only the days and weeks where the member worked.
        </p>

        <table class="chart-table">
          <caption>Hours per member</caption>
          <thead>
            <tr>
              <th scope="col">Member</th>
              <th scope="col">Total</th>
              <th scope="col">Average per day</th>
              <th scope="col">Average per week</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="member in memberStats" :key="member.id">
              <th scope="row">{{ member.username }}</th>
              <td>{{ member.total }} h</td>
              <td>{{ member.dailyAverage }} h</td>
              <td>{{ member.weeklyAverage }} h</td>
            </tr>
          </tbody>
        </table>

        <div v-if="allWorkingTimes.length > 0" class="chart-grid team-hours-charts">
          <article class="chart-card chart-card-wide"><WorkingHoursBarChart :workingTimes="allWorkingTimes" /></article>
          <article class="chart-card chart-card-wide"><WorkingHoursLineChart :workingTimes="allWorkingTimes" /></article>
        </div>
      </template>
    </template>
  </section>
</template>

<script>
import WorkingHoursBarChart from "./WorkingHoursBarChart.vue";
import WorkingHoursLineChart from "./WorkingHoursLineChart.vue";
import { apiFetch } from "../services/auth";
import { parseUtc } from "../utils/datetime";
import { hoursByDay, hoursByWeek, localDateKey } from "../utils/workingHours";

const sum = (buckets) => buckets.reduce((total, b) => total + b.hours, 0);
const mean = (buckets) => (buckets.length ? sum(buckets) / buckets.length : 0);

// Default period: the last four full weeks plus the current one.
function defaultStart() {
  const now = new Date();
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - ((now.getDay() + 6) % 7) - 28);
  return localDateKey(monday);
}

export default {
  name: "TeamHours",

  components: { WorkingHoursBarChart, WorkingHoursLineChart },

  props: {
    teamId: { type: [Number, String], required: true }
  },

  data() {
    return {
      members: [],
      startDate: defaultStart(),
      endDate: localDateKey(new Date()),
      loading: false,
      error: ""
    };
  },

  computed: {
    // Members with their entries restricted to the period, in local dates.
    filteredMembers() {
      return this.members.map((member) => ({
        ...member,
        working_times: member.working_times.filter((wt) => {
          const start = parseUtc(wt.start);
          if (!start) return false;
          const day = localDateKey(start);
          return (!this.startDate || day >= this.startDate) && (!this.endDate || day <= this.endDate);
        })
      }));
    },

    memberStats() {
      return this.filteredMembers.map((member) => {
        const days = hoursByDay(member.working_times);
        const weeks = hoursByWeek(member.working_times);
        return {
          id: member.id,
          username: member.username,
          days,
          weeks,
          total: sum(days).toFixed(1),
          dailyAverage: mean(days).toFixed(1),
          weeklyAverage: mean(weeks).toFixed(1)
        };
      });
    },

    allWorkingTimes() {
      return this.filteredMembers.flatMap((member) => member.working_times);
    },

    // Mean over every (member, worked day) and (member, worked week) pair.
    teamDailyAverage() {
      return mean(this.memberStats.flatMap((m) => m.days)).toFixed(1);
    },

    teamWeeklyAverage() {
      return mean(this.memberStats.flatMap((m) => m.weeks)).toFixed(1);
    },

    teamTotal() {
      return this.memberStats.reduce((total, m) => total + Number(m.total), 0).toFixed(1);
    }
  },

  watch: {
    teamId: { immediate: true, handler: "load" },
    startDate: "load",
    endDate: "load"
  },

  methods: {
    async load() {
      if (!this.teamId) return;
      this.loading = true;
      this.error = "";

      const query = new URLSearchParams();
      if (this.startDate) query.set("start", this.startDate);
      if (this.endDate) query.set("end", this.endDate);

      try {
        const response = await apiFetch(`/api/teams/${this.teamId}/working-times?${query}`);
        const body = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(body.error || "Unable to load the team's working times.");
        this.members = body.data?.members || [];
      } catch (err) {
        this.members = [];
        this.error = err.message;
      } finally {
        this.loading = false;
      }
    }
  }
};
</script>

<style src="./ChartManager.css"></style>

<style scoped>
.team-hours { margin-top: 32px; padding-top: 24px; border-top: 1px solid #d4d6cc; }
.team-hours h3 { margin: 0 0 16px; color: #243332; font-size: 18px; }
.team-hours-summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; margin: 20px 0 8px; }
.team-hours-summary div { padding: 16px; border: 1px solid #d4d6cc; background: #fffdf7; }
.team-hours-summary dt { color: #4f5d58; font-size: 13px; }
.team-hours-summary dd { margin: 6px 0 0; color: #243332; font-size: 26px; font-weight: 700; }
.team-hours-note { margin: 0 0 16px; color: #4f5d58; font-size: 13px; }
.team-hours-charts { margin-top: 22px; }

@media (max-width: 760px) {
  .team-hours-summary { grid-template-columns: 1fr; }
}
</style>

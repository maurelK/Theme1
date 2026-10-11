<template>
  <div class="chart-content">
    <h2>Working Hours Distribution</h2>

    <Pie
      v-if="chartData.labels.length > 0"
      :data="chartData"
      :options="chartOptions"
    />

    <p v-else>No working time data available.</p>
  </div>
</template>

<script>
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  Legend,
  ArcElement
} from "chart.js";

import { Pie } from "vue-chartjs";
import { parseUtc, minutesBetween, browserTimezoneLabel } from "../utils/datetime";

ChartJS.register(Title, Tooltip, Legend, ArcElement);

const SLICE_COLORS = [
  "#df7959",
  "#287c78",
  "#e5a35a",
  "#7ba6a0",
  "#c77a68",
  "#8b9c68"
];

export default {
  components: { Pie },

  props: {
    workingTimes: {
      type: Array,
      required: true
    }
  },

  computed: {
    // Same daily aggregation as the bar and line charts. Each slice is
    // "hours worked on day YYYY-MM-DD", chronologically sorted.
    aggregatedByDay() {
      const buckets = new Map();

      for (const wt of this.workingTimes) {
        const start = parseUtc(wt.start);
        const end = parseUtc(wt.end);
        if (!start || !end) continue;

        const y = start.getFullYear();
        const m = String(start.getMonth() + 1).padStart(2, "0");
        const d = String(start.getDate()).padStart(2, "0");
        const key = `${y}-${m}-${d}`;

        const mins = minutesBetween(wt.start, wt.end);
        buckets.set(key, (buckets.get(key) || 0) + mins);
      }

      return Array.from(buckets.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, minutes]) => ({
          date,
          hours: +(minutes / 60).toFixed(2)
        }));
    },

    chartData() {
      return {
        labels: this.aggregatedByDay.map((d) => d.date),
        datasets: [
          {
            label: `Working Hours (${browserTimezoneLabel()})`,
            data: this.aggregatedByDay.map((d) => d.hours),
            backgroundColor: this.aggregatedByDay.map(
              (_, i) => SLICE_COLORS[i % SLICE_COLORS.length]
            ),
            borderColor: "#fffdf7",
            borderWidth: 3,
            hoverOffset: 8
          }
        ]
      };
    },

    chartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: "right",
            labels: {
              color: "#52645f",
              padding: 14,
              usePointStyle: true
            }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const hrs = ctx.parsed;
                return `${hrs.toFixed(1)} h`;
              }
            }
          }
        }
      };
    }
  }
};
</script>
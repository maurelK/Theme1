<template>
  <div class="chart-content">
    <h2>Working Hours Trend</h2>

    <Line
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
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale
} from "chart.js";

import { Line } from "vue-chartjs";
import { parseUtc, minutesBetween, browserTimezoneLabel } from "../utils/datetime";

ChartJS.register(
  Title,
  Tooltip,
  Legend,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale
);

export default {
  components: {
    Line
  },

  props: {
    workingTimes: {
      type: Array,
      required: true
    }
  },

  computed: {
    // Same daily aggregation as the bar chart, sorted ascending. This ensures
    // the trend line advances chronologically from left to right.
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
            tension: 0.3,
            borderColor: "#287c78",
            backgroundColor: "rgba(40, 124, 120, .14)",
            pointBackgroundColor: "#df7959",
            pointBorderColor: "#fffdf7",
            pointBorderWidth: 2,
            pointRadius: 5,
            fill: true
          }
        ]
      };
    },

    chartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: true }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: "#eadfd3" },
            title: { display: true, text: "Hours", color: "#71807a" }
          },
          x: {
            grid: { color: "#f0e7dc" },
            title: { display: true, text: "Date", color: "#71807a" }
          }
        }
      };
    }
  }
};
</script>
<template>
  <div class="chart-content">
    <h2>Working Hours per Day</h2>

    <Bar
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
  BarElement,
  CategoryScale,
  LinearScale
} from "chart.js";

import { Bar } from "vue-chartjs";
import { parseUtc, minutesBetween, browserTimezoneLabel } from "../utils/datetime";

ChartJS.register(
  Title,
  Tooltip,
  Legend,
  BarElement,
  CategoryScale,
  LinearScale
);

export default {
  components: {
    Bar
  },

  props: {
    workingTimes: {
      type: Array,
      required: true
    }
  },

  computed: {
    // Group hours by browser-local date, then sort ascending.
    aggregatedByDay() {
      const buckets = new Map(); // "YYYY-MM-DD" -> total minutes

      for (const wt of this.workingTimes) {
        const start = parseUtc(wt.start);
        const end = parseUtc(wt.end);
        if (!start || !end) continue;

        // Local date key.
        const y = start.getFullYear();
        const m = String(start.getMonth() + 1).padStart(2, "0");
        const d = String(start.getDate()).padStart(2, "0");
        const key = `${y}-${m}-${d}`;

        const mins = minutesBetween(wt.start, wt.end);
        buckets.set(key, (buckets.get(key) || 0) + mins);
      }

      // Sort by date ascending.
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
            backgroundColor: "#df7959",
            borderColor: "#b75c43",
            borderWidth: 1,
            borderRadius: 5
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
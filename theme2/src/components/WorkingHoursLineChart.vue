<template>
  <div class="chart-content">
    <h2>Hours per week</h2>

    <Line
      v-if="chartData.labels.length > 0"
      :data="chartData"
      :options="chartOptions"
      aria-label="Working hours per week. Detailed values are in the Hours per week table below."
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
import { browserTimezoneLabel } from "../utils/datetime";
import { hoursByWeek } from "../utils/workingHours";

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
    // Weekly totals (weeks start on Monday), complementing the daily bar chart.
    weeks() {
      return hoursByWeek(this.workingTimes);
    },

    chartData() {
      return {
        labels: this.weeks.map((w) => `Week of ${w.key}`),
        datasets: [
          {
            label: `Hours per week (${browserTimezoneLabel()})`,
            data: this.weeks.map((w) => w.hours),
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
            title: { display: true, text: "Week", color: "#71807a" }
          }
        }
      };
    }
  }
};
</script>
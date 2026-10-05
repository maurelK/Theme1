<script setup lang="ts">
  import moment from "moment";
  import { onMounted, ref, watch } from "vue";
  // Route clock requests through the shared cookie and CSRF-aware API helper.
  import { apiFetch } from "../services/auth";

  const props = defineProps<{
    userId?: number | string;
  }>();

  const current_time = ref(moment().format("HH:mm:ss"));

  setInterval(() => {
    current_time.value = moment().format("HH:mm:ss");
  }, 1000);

  const clockedIn = ref(false);
  const loading = ref(false);

  async function loadClockStatus() {
    if (!props.userId || props.userId === 'undefined') return;
    try {
      const response = await apiFetch(`/api/clocks/${props.userId}`);

      if (!response.ok) {
        throw new Error("Failed to load clock status");
      }

      const clocks = await response.json();
      const list = Array.isArray(clocks) ? clocks : (clocks.data || []);
      const latestClock = list.at(-1);

      clockedIn.value = latestClock?.status ?? false;
    } catch (err) {
      console.error(err);
    }
  }

  async function handleButtonClick() {
    if (!props.userId || props.userId === 'undefined') return;
    loading.value = true;

    try {
      const response = await apiFetch(`/api/clocks/${props.userId}`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            time: new Date().toISOString(),
            status: !clockedIn.value
          })
      })

      if (!response.ok) {
          loading.value = false;
          throw new Error("Failed to clock in");
      }

      const data = await response.json();
      clockedIn.value = data.status;
    } catch (err) {
      console.error(err);
    } finally {
      loading.value = false;
    }
  }

  watch(() => props.userId, (newId) => {
    if (newId) {
      loadClockStatus();
    }
  });

  onMounted(loadClockStatus);
</script>

<template>
  <div class="current-time">
    <p>{{ current_time }}</p>
  </div>
  <div class="clock_in_clock_out" style="text-align: center; margin-top: 20px;">
    <button :disabled="loading" @click="handleButtonClick" style="padding: 12px 24px; font-size: 16px; cursor: pointer;">
      {{ loading ? "Loading..." : clockedIn ? "Clock Out" : "Clock In" }}
    </button>
  </div>
</template>

<style scoped>
.current-time {
  font-size: 2rem;
  font-weight: bold;
  color: #333;
  text-align: center;
  margin-top: 20px;
}
</style>

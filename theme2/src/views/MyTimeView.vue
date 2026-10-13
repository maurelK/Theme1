<template>
  <AppLayout>
    <main class="page-shell">
      <section class="user-dashboard-section my-time">
        <div class="section-title section-title-spaced">
          <div>
            <p class="eyebrow">My time</p>
            <h2>Hours, clock and corrections</h2>
          </div>
        </div>

        <div class="tab-nav" role="tablist" aria-label="My time">
          <button
            v-for="tab in TABS"
            :key="tab.id"
            type="button"
            role="tab"
            class="btn-wt"
            :class="activeTab === tab.id ? 'btn-primary' : 'btn-outline'"
            :aria-selected="activeTab === tab.id"
            @click="activeTab = tab.id"
          >{{ tab.label }}</button>
        </div>

        <div v-if="userId" class="tab-content-area" role="tabpanel">
          <WorkingTimes v-if="activeTab === 'entries'" :userId="userId" />
          <ClockManager v-else-if="activeTab === 'clock'" :userId="userId" />
          <MyCorrectionRequests v-else-if="activeTab === 'corrections'" />
        </div>
      </section>
    </main>
  </AppLayout>
</template>

<script setup>
import { computed, ref } from "vue";
import { authState } from "../services/auth";
import AppLayout from "../components/AppLayout.vue";
import WorkingTimes from "../components/WorkingTimes.vue";
import ClockManager from "../components/ClockManager.vue";
import MyCorrectionRequests from "../components/MyCorrectionRequests.vue";

const TABS = [
  { id: "clock", label: "Clock in / out" },
  { id: "entries", label: "Time entries" },
  { id: "corrections", label: "Correction requests" }
];
// Charts live on their own web-only page (My hours).

// Clocking is the most frequent action, so it opens first.
const activeTab = ref("clock");
const userId = computed(() => authState.user?.id);
</script>

<style src="../components/User.css"></style>

<style scoped>
.my-time { margin-top: 8px; }
</style>

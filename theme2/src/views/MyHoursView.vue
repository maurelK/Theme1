<template>
  <AppLayout>
    <main class="page-shell">
      <ChartManager v-if="userId" :userId="userId" />
    </main>
  </AppLayout>
</template>

<script setup>
import { computed } from "vue";
import { authState } from "../services/auth";
import AppLayout from "../components/AppLayout.vue";
import ChartManager from "../components/ChartManager.vue";

// The signed-in user's own hours dashboard (web only).
const userId = computed(() => authState.user?.id);
</script>

<style scoped>
/* ChartManager has its own page spacing; avoid doubling it. */
.page-shell { padding-top: 0; }
</style>

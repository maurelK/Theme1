<template>
  <div class="app-layout">
    <AppTopbar />
    <main class="app-layout-content">
      <slot />
    </main>
    <AppBottomNav />
  </div>
</template>

<script setup>
import AppTopbar from "./AppTopbar.vue";
import AppBottomNav from "./AppBottomNav.vue";
</script>

<style scoped>
.app-layout {
  min-height: 100dvh;
  background: var(--color-bg);
}

.app-layout-content {
  max-width: var(--content-max);
  margin: 0 auto;
  padding: 0 var(--content-padding);
}

/* Reserve space for the fixed bottom nav on mobile. */
@media (max-width: 900px) {
  .app-layout-content {
    padding-bottom: calc(76px + env(safe-area-inset-bottom, 0px));
  }
}
</style>
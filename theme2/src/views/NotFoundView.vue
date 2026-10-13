<template>
  <AppLayout>
    <main class="nf-shell">
      <p class="eyebrow">404 / Not found</p>
      <h1>This page does not <em>exist.</em></h1>
      <p class="nf-copy">
        The page you tried to open isn't here. It may have been moved or the URL is wrong.
      </p>
      <div class="nf-actions">
        <RouterLink class="btn-wt btn-primary" to="/">Go to home</RouterLink>
        <RouterLink class="btn-wt btn-outline" to="/my-time">Open my time</RouterLink>
      </div>
    </main>
  </AppLayout>
</template>

<script setup>
import AppLayout from "../components/AppLayout.vue";
</script>

<style scoped>
.nf-shell {
  max-width: 720px;
  margin: 0 auto;
  padding: 80px 24px 60px;
}

.nf-shell h1 {
  margin: 0 0 16px;
  color: #243332;
  font-size: clamp(36px, 6vw, 64px);
  font-weight: 500;
  line-height: 1;
  letter-spacing: -0.05em;
}

.nf-shell h1 em {
  color: #b5684b;
  font-family: "Playfair Display", Georgia, serif;
  font-style: italic;
}

.nf-copy {
  max-width: 480px;
  color: #71807a;
  font-size: 15px;
  line-height: 1.6;
  margin: 0 0 28px;
}

.nf-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

@media (max-width: 480px) {
  .nf-actions {
    flex-direction: column;
  }
  .nf-actions > * {
    width: 100%;
    text-align: center;
    justify-content: center;
  }
}
</style>
<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Account recovery</p>
      <h1>Reset your password.</h1>
      <form class="search-form" @submit.prevent="submit">
        <label for="forgot-email">Email address</label>
        <input id="forgot-email" v-model="email" type="email" required autocomplete="email">
        <p class="muted">If the account exists, reset instructions will be sent.</p>
        <button class="button button-primary" type="submit" :disabled="loading">{{ loading ? "Sending..." : "Send instructions" }}</button>
      </form>
      <p v-if="message" class="wt-alert wt-alert-success">{{ message }}</p>
      <p v-if="developmentToken" class="muted">Local development token: {{ developmentToken }}</p>
      <p class="muted"><RouterLink to="/login">Back to sign in</RouterLink></p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { requestPasswordReset } from "../services/auth";

// The generic response prevents account enumeration while keeping a local test token visible in development.
const email = ref("");
const message = ref("");
const developmentToken = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  const data = await requestPasswordReset(email.value);
  message.value = data.message;
  developmentToken.value = data.development_reset_token || "";
  loading.value = false;
}
</script>
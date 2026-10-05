<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Time Manager</p>
      <h1>Sign in to your workspace.</h1>
      <form class="search-form" @submit.prevent="submit">
        <label for="login-email">Email address</label>
        <input id="login-email" v-model="email" type="email" required autocomplete="email">
        <label for="login-password">Password</label>
        <input id="login-password" v-model="password" type="password" required autocomplete="current-password">
        <p v-if="error" class="wt-alert wt-alert-error">{{ error }}</p>
        <button class="button button-primary" type="submit" :disabled="loading">
          {{ loading ? "Signing in..." : "Sign in" }}
        </button>
      </form>
      <p class="muted"><RouterLink to="/forgot-password">Forgot password?</RouterLink></p>
      <p class="muted">Need an account? <RouterLink to="/register">Register</RouterLink></p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { login } from "../services/auth";

// This view owns the credential form and hands successful sessions to the router.
const router = useRouter();
const email = ref("");
const password = ref("");
const error = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  error.value = "";

  try {
    await login({ email: email.value, password: password.value });
    await router.push("/");
  } catch (reason) {
    error.value = reason.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Time Manager</p>
      <h1>Sign in to your workspace.</h1>

      <!-- Why the user is here: expired session, too long offline... -->
      <p v-if="authState.notice" class="wt-alert" role="status">{{ authState.notice }}</p>

      <!-- Mobile: a session is stored on this phone but the unlock was cancelled. -->
      <div v-if="authState.locked" class="unlock-panel">
        <p>Your session is saved on this phone.</p>
        <button class="button button-primary" type="button" :disabled="unlocking" @click="unlock">
          {{ unlocking ? "Unlocking..." : "Unlock with fingerprint or PIN" }}
        </button>
        <p class="muted">Or sign in again below.</p>
      </div>

      <form class="search-form" @submit.prevent="submit">
        <label for="login-email">Email address</label>
        <input id="login-email" v-model="email" type="email" required autocomplete="email" :aria-describedby="error ? 'login-error' : undefined">
        <label for="login-password">Password</label>
        <input id="login-password" v-model="password" type="password" required autocomplete="current-password" :aria-describedby="error ? 'login-error' : undefined">
        <p v-if="error" id="login-error" class="wt-alert wt-alert-error" role="alert" aria-atomic="true">{{ error }}</p>
        <button class="button button-primary" type="submit" :disabled="loading">
          {{ loading ? "Signing in..." : "Sign in" }}
        </button>
      </form>
      <p class="muted"><RouterLink to="/forgot-password">Forgot password?</RouterLink></p>
      <p class="muted">Accounts are created by invitation. Contact your administrator.</p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { authState, login, unlockSession } from "../services/auth";

// This view owns the credential form and hands successful sessions to the router.
const router = useRouter();
const email = ref("");
const password = ref("");
const error = ref("");
const loading = ref(false);
const unlocking = ref(false);

async function unlock() {
  unlocking.value = true;
  error.value = "";
  try {
    if (await unlockSession()) await router.push("/");
    else if (!authState.notice) error.value = "Unlock cancelled.";
  } finally {
    unlocking.value = false;
  }
}

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

<style scoped>
.unlock-panel {
  display: grid;
  gap: 10px;
  margin: 0 0 24px;
  padding: 16px;
  border: 1px solid #d4d6cc;
  background: #e4e7de;
}
.unlock-panel p { margin: 0; }
</style>

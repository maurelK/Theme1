<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Account recovery</p>
      <h1>Choose a new password.</h1>
      <form class="search-form" @submit.prevent="submit">
        <label for="reset-token">Reset token</label>
        <input id="reset-token" v-model="token" type="text" required>
        <label for="reset-password">New password</label>
        <input id="reset-password" v-model="password" type="password" minlength="8" required autocomplete="new-password">
        <p v-if="message" class="wt-alert wt-alert-success">{{ message }}</p>
        <p v-if="error" class="wt-alert wt-alert-error">{{ error }}</p>
        <button class="button button-primary" type="submit" :disabled="loading">{{ loading ? "Updating..." : "Update password" }}</button>
      </form>
      <p class="muted"><RouterLink to="/login">Back to sign in</RouterLink></p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { resetPassword } from "../services/auth";

// Accept tokens from the recovery link while allowing local development to paste one manually.
const route = useRoute();
const router = useRouter();
const token = ref(route.query.token || "");
const password = ref("");
const message = ref("");
const error = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  error.value = "";

  try {
    await resetPassword(token.value, password.value);
    message.value = "Password updated. You can sign in now.";
    password.value = "";
    await router.push("/login");
  } catch (reason) {
    error.value = reason.message;
  } finally {
    loading.value = false;
  }
}
</script>
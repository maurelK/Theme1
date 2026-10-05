<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Time Manager</p>
      <h1>Create an employee account.</h1>
      <form class="search-form" @submit.prevent="submit">
        <label for="register-name">Full name</label>
        <input id="register-name" v-model="username" type="text" required autocomplete="name">
        <label for="register-email">Email address</label>
        <input id="register-email" v-model="email" type="email" required autocomplete="email">
        <label for="register-password">Password</label>
        <input id="register-password" v-model="password" type="password" minlength="8" required autocomplete="new-password">
        <p v-if="error" class="wt-alert wt-alert-error">{{ error }}</p>
        <button class="button button-primary" type="submit" :disabled="loading">
          {{ loading ? "Creating account..." : "Create account" }}
        </button>
      </form>
      <p class="muted">Already registered? <RouterLink to="/login">Sign in</RouterLink></p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { register } from "../services/auth";

// Registration intentionally creates only the default employee role.
const router = useRouter();
const username = ref("");
const email = ref("");
const password = ref("");
const error = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  error.value = "";

  try {
    await register({ username: username.value, email: email.value, password: password.value });
    await router.push("/login");
  } catch (reason) {
    error.value = reason.message;
  } finally {
    loading.value = false;
  }
}
</script>

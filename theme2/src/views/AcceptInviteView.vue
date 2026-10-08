<template>
  <main class="page-shell auth-shell">
    <section class="auth-panel">
      <p class="eyebrow">Welcome</p>
      <h1>Set up your account.</h1>
      <form class="search-form" @submit.prevent="submit">
        <label for="invite-token">Invitation token</label>
        <input id="invite-token" v-model="token" type="text" required>
        <PasswordField
          v-model="password"
          label="Choose a password"
          input-id="invite-password"
          autocomplete="new-password"
        />
        <p v-if="message" class="wt-alert wt-alert-success">{{ message }}</p>
        <p v-if="error" class="wt-alert wt-alert-error">{{ error }}</p>
        <button class="button button-primary" type="submit" :disabled="loading">{{ loading ? "Creating account..." : "Create account" }}</button>
      </form>
      <p class="muted"><RouterLink to="/login">Back to sign in</RouterLink></p>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { acceptInvitation } from "../services/auth";
import PasswordField from "../components/PasswordField.vue";

// Accept tokens from the invitation link while allowing local development to paste one manually.
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
    await acceptInvitation(token.value, password.value);
    message.value = "Account ready. Redirecting to sign in...";
    password.value = "";
    setTimeout(() => router.push("/login"), 1200);
  } catch (reason) {
    error.value = reason.message;
  } finally {
    loading.value = false;
  }
}
</script>
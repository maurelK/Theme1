<template>
  <AppLayout>
    <main class="page-shell profile-page">
      <header class="profile-header">
        <div class="avatar" aria-hidden="true">{{ initials }}</div>
        <div>
          <p class="eyebrow">Profile</p>
          <h2>{{ authState.user?.username }}</h2>
          <p class="muted">{{ authState.user?.email }}</p>
        </div>
        <span class="member-tag">{{ formatRole(authState.user?.role) }}</span>
      </header>

      <form class="editor" @submit.prevent="updateAccount">
        <div class="section-title">
          <div><p class="eyebrow">Account</p><h3>Edit my details</h3></div>
        </div>
        <div class="form-grid">
          <label>Full name<input v-model="username" type="text" autocomplete="name" required></label>
          <label>Email address<input v-model="email" type="email" autocomplete="email" required></label>
        </div>
        <p v-if="accountMessage.text" class="editor-alert" :class="alertClass(accountMessage)" role="status">{{ accountMessage.text }}</p>
        <div class="editor-actions">
          <button class="button button-primary" type="submit" :disabled="savingAccount">
            {{ savingAccount ? "Saving..." : "Save changes" }}
          </button>
        </div>
      </form>

      <form class="editor" @submit.prevent="changePassword">
        <div class="section-title">
          <div><p class="eyebrow">Security</p><h3>Change my password</h3></div>
        </div>
        <div class="form-grid">
          <!-- Plain field: the strength rules only apply to the new password. -->
          <label>Current password<input v-model="currentPassword" type="password" autocomplete="current-password" required></label>
          <PasswordField
            v-model="newPassword"
            label="New password"
            input-id="profile-new-password"
            autocomplete="new-password"
          />
        </div>
        <p v-if="passwordMessage.text" class="editor-alert" :class="alertClass(passwordMessage)" role="status">{{ passwordMessage.text }}</p>
        <div class="editor-actions">
          <button class="button button-primary" type="submit">Update password</button>
          <button class="text-button" type="button" @click="signOut">Sign out</button>
        </div>
      </form>

      <section class="danger-zone">
        <div>
          <p class="eyebrow">Danger zone</p>
          <h3>Delete my account</h3>
          <p class="muted">You will no longer be able to sign in. Your working-time records are kept for reporting.</p>
        </div>
        <button class="danger-button" type="button" :disabled="deleting" @click="deleteAccount">
          {{ deleting ? "Deleting..." : "Delete my account" }}
        </button>
        <p v-if="deleteError" class="editor-alert editor-alert-error" role="alert">{{ deleteError }}</p>
      </section>
    </main>
  </AppLayout>
</template>

<script setup>
import { computed, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { apiFetch, authState, logout } from "../services/auth";
import { signOutWithConfirmation } from "../services/signOut";
import { formatRole } from "../utils/roles";
import AppLayout from "../components/AppLayout.vue";
import PasswordField from "../components/PasswordField.vue";

const router = useRouter();

const username = ref(authState.user?.username || "");
const email = ref(authState.user?.email || "");
const savingAccount = ref(false);
const accountMessage = reactive({ text: "", error: false });

const currentPassword = ref("");
const newPassword = ref("");
const passwordMessage = reactive({ text: "", error: false });

const deleting = ref(false);
const deleteError = ref("");

const initials = computed(() => {
  const parts = (authState.user?.username || "").trim().split(/\s+/);
  return ((parts[0]?.[0] || "") + (parts[1]?.[0] || "")).toUpperCase() || "?";
});

function setMessage(target, text, error = false) {
  target.text = text;
  target.error = error;
}

function alertClass(message) {
  return message.error ? "editor-alert-error" : "editor-alert-success";
}

// Readable message from {error: "..."} or {errors: {field: [...]}}.
async function errorText(response, fallback) {
  const body = await response.json().catch(() => ({}));
  if (typeof body.error === "string") return body.error;
  if (body.errors) {
    return Object.entries(body.errors)
      .flatMap(([field, messages]) => [].concat(messages).map((m) => `${field}: ${m}`))
      .join(", ");
  }
  return fallback;
}

async function updateAccount() {
  const name = username.value.trim();
  const address = email.value.trim();
  if (!name) return setMessage(accountMessage, "Full name cannot be blank.", true);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(address)) return setMessage(accountMessage, "Enter a valid email address.", true);

  savingAccount.value = true;
  setMessage(accountMessage, "");
  try {
    const response = await apiFetch(`/api/users/${authState.user.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: name, email: address })
    });
    if (!response.ok) return setMessage(accountMessage, await errorText(response, "Unable to update your details."), true);

    const body = await response.json();
    const updated = body.data || body;
    // Keep the header and navigation in sync with the saved values.
    authState.user = { ...authState.user, username: updated.username, email: updated.email };
    setMessage(accountMessage, "Details updated.");
  } finally {
    savingAccount.value = false;
  }
}

async function changePassword() {
  setMessage(passwordMessage, "");
  const response = await apiFetch("/api/auth/password", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ current_password: currentPassword.value, new_password: newPassword.value })
  });
  if (!response.ok) return setMessage(passwordMessage, await errorText(response, "Unable to update your password."), true);

  currentPassword.value = "";
  newPassword.value = "";
  setMessage(passwordMessage, "Password updated.");
}

// Warns first when offline actions are still waiting to be sent.
function signOut() {
  return signOutWithConfirmation(router);
}

// Two-step confirmation: a dialog, then typing the account email.
async function deleteAccount() {
  deleteError.value = "";
  if (!window.confirm("Delete your account? You will not be able to sign in again.")) return;

  const typed = window.prompt(`Type your email to confirm (${authState.user.email}):`, "");
  if (typed === null) return;
  if (typed.trim().toLowerCase() !== (authState.user.email || "").toLowerCase()) {
    deleteError.value = "Email did not match. Your account was not deleted.";
    return;
  }

  deleting.value = true;
  try {
    const response = await apiFetch(`/api/users/${authState.user.id}`, { method: "DELETE" });
    if (!response.ok) {
      deleteError.value = await errorText(response, "Unable to delete your account.");
      return;
    }
    // The account no longer exists: sign out without asking.
    await logout();
    await router.push({ name: "Login" });
  } finally {
    deleting.value = false;
  }
}
</script>

<style src="../components/User.css"></style>

<style scoped>
.profile-page { display: grid; gap: 32px; }
.profile-page .editor { margin: 0; }
</style>

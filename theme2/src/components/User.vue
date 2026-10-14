<template>
  <AppLayout>
    <main class="page-shell">

      <!-- Directory for managers, HR and the general manager (employees use My time / My team / Profile). -->
      <div class="content-grid">
        <!-- Search & Quick Selection Panel -->
        <aside class="search-panel">
          <div class="panel-heading">
            <div><p class="eyebrow">Directory</p><h2>Find a person</h2></div>
          </div>
          <form class="search-form" @submit.prevent="getUser">
            <label for="search-email">Email address</label>
            <div class="input-with-icon">
              <input 
                id="search-email" 
                v-model="searchEmail" 
                type="email" 
                placeholder="name@company.com" 
                required
              >
            </div>
            <button class="button button-primary" type="submit">
              Search directory
            </button>
          </form>
          <p class="helper-text">Enter the user's email address (e.g. axel.ogouchi@epitech.eu).</p>

          <div v-if="allUsers.length > 0" class="recent-accounts">
            <p class="eyebrow">Recent accounts</p>
            <div class="recent-accounts-list">
              <button 
                v-for="u in allUsers" 
                :key="u.id" 
                type="button" 
                class="btn-link recent-account"
                @click="selectUser(u)"
              >
                <strong>{{ u.username }}</strong> ({{ u.email }})
              </button>
            </div>
          </div>
        </aside>

        <section class="main-panel" aria-live="polite">
          <div v-if="user" class="profile-view">
            <div class="profile-header">
              <div class="avatar">{{ userInitials }}</div>
              <div>
                <p class="eyebrow">Selected account</p>
                <h2>{{ user.username }}</h2>
                <p class="muted">{{ user.email }}</p>
              </div>
              <span class="member-tag">Active</span>
            </div>

            <form class="editor" @submit.prevent="updateUser">
              <div class="section-title">
                <div><p class="eyebrow">Profile details</p><h3>Edit account</h3></div>
              </div>
              <div class="form-grid">
                <label>Full name<input v-model="editUsername" type="text" placeholder="Full name" required></label>
                <label>Email address<input v-model="editEmail" type="email" placeholder="name@company.com" required></label>
              </div>

              <p v-if="editError" class="editor-alert editor-alert-error">{{ editError }}</p>
              <p v-else-if="editSuccess" class="editor-alert editor-alert-success">{{ editSuccess }}</p>

              <div class="editor-actions">
                <button class="button button-primary" type="submit" :disabled="editSaving || !online">
                  {{ editSaving ? "Saving..." : "Save changes" }}
                </button>
                <button v-if="isAdministrator" class="text-button" type="button" :disabled="!online" @click="deleteUser">Remove account</button>
              </div>
              <p v-if="removeError" class="editor-alert editor-alert-error">{{ removeError }}</p>
              <OnlineOnlyNote />
            </form>

          </div>

          <div v-else class="empty-state">
            <p class="eyebrow">No account selected</p>
            <h2>Search or select an account<br>to get started.</h2>
            <p class="muted">The person's working times, clock status, and charts will appear here.</p>
          </div>

          <p v-if="isAdministrator" class="helper-text">
            To invite someone, go to <RouterLink to="/admin">Administration</RouterLink>.
          </p>
        </section>
      </div>

      <!-- Full width so tables and charts are not squeezed into the right column -->
      <section v-if="user" class="user-dashboard-section workspace-full">
        <div class="section-title section-title-spaced">
          <div>
            <p class="eyebrow">Time Management &amp; Insights</p>
            <h3>{{ user.username }}'s Workspace</h3>
          </div>
        </div>

        <div class="tab-nav">
          <button type="button" class="btn-wt" :class="activeTab === 'workingTimes' ? 'btn-primary' : 'btn-outline'" @click="activeTab = 'workingTimes'">Time entries</button>
          <button type="button" class="btn-wt" :class="activeTab === 'clock' ? 'btn-primary' : 'btn-outline'" @click="activeTab = 'clock'">Clock in / out</button>
          <button v-if="!isMobileApp" type="button" class="btn-wt" :class="activeTab === 'charts' ? 'btn-primary' : 'btn-outline'" @click="activeTab = 'charts'">Hours per day and week</button>
          <button type="button" class="btn-wt" :class="activeTab === 'create' ? 'btn-primary' : 'btn-outline'" @click="activeTab = 'create'">New entry</button>
        </div>

        <div class="tab-content-area">
          <WorkingTimes v-if="activeTab === 'workingTimes'" :userId="user.id" @go-create-entry="activeTab = 'create'" />
          <ClockManager v-else-if="activeTab === 'clock'" :userId="user.id" />
          <ChartManager v-else-if="activeTab === 'charts'" :userId="user.id" />
          <WorkingTime v-else-if="activeTab === 'create'" :userId="user.id" />
        </div>
      </section>

    </main>
  </AppLayout>
</template>

<script>
import WorkingTimes from "./WorkingTimes.vue";
import WorkingTime from "./WorkingTime.vue";
import ClockManager from "./ClockManager.vue";
import ChartManager from "./ChartManager.vue";
import AppLayout from "./AppLayout.vue";
// Route profile requests through the shared authenticated API helper.
import { apiFetch, authState } from "../services/auth";
import { isMobileApp } from "../utils/platform";
import { network } from "../platform/network";
import OnlineOnlyNote from "./OnlineOnlyNote.vue";

export default {
  name: "User",

  components: {
    WorkingTimes,
    WorkingTime,
    ClockManager,
    ChartManager,
    AppLayout,
    OnlineOnlyNote
  },

  data() {
    return {
      user: null,
      searchEmail: "",
      editUsername: "",
      editEmail: "",
      editSaving: false,
      editError: "",
      editSuccess: "",
      removeError: "",
      activeTab: "workingTimes",
      allUsers: [],
      // Charts are a dashboard: web only.
      isMobileApp
    };
  },

  computed: {
    // Editing or removing someone else's account needs live data.
    online() {
      return network.online.value;
    },

    // Reflect the server-authorized role in the authenticated workspace header.
    authUser() {
      return authState.user;
    },

    isAdministrator() {
      return this.authUser?.role === "administrator";
    },

    userInitials() {
      if (!this.user || !this.user.username) return "TM";
      const parts = this.user.username.trim().split(" ");
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return this.user.username.substring(0, 2).toUpperCase();
    }
  },

  watch: {
    '$route.params': {
      immediate: true,
      handler(params) {
        const routeUserId = params.userID || params.userid;
        if (routeUserId) {
          this.fetchUserById(routeUserId);
          if (this.$route.name === 'ClockManager') this.activeTab = 'clock';
          else if (this.$route.name === 'WorkingTimeCreate') this.activeTab = 'create';
          else this.activeTab = 'workingTimes';
        }
      }
    }
  },

  mounted() {
    this.fetchAllUsers();
  },

  methods: {
    async fetchAllUsers() {
      try {
        const response = await apiFetch("/api/users");
        if (response.ok) {
          const data = await response.json();
          this.allUsers = Array.isArray(data) ? data : (data.data || []);
        }
      } catch (err) {
        console.error(err);
      }
    },

    async fetchUserById(id) {
      try {
        const response = await apiFetch(`/api/users/${id}`);
        if (response.ok) {
          const data = await response.json();
          const found = data.data || data;
          if (found && found.id) {
            this.user = found;
            this.editUsername = found.username;
            this.editEmail = found.email;
            this.searchEmail = found.email;
          }
        }
      } catch (err) {
        console.error(err);
      }
    },

    selectUser(u) {
      this.user = u;
      this.editUsername = u.username;
      this.editEmail = u.email;
      this.searchEmail = u.email;
    },


    async updateUser() {
      // Client-side validation to avoid the round trip on obvious issues.
      const trimmedName = (this.editUsername || "").trim();
      const trimmedEmail = (this.editEmail || "").trim();

      if (trimmedName.length === 0) {
        this.editError = "Full name cannot be blank.";
        this.editSuccess = "";
        return;
      }
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(trimmedEmail)) {
        this.editError = "Enter a valid email address.";
        this.editSuccess = "";
        return;
      }

      this.editSaving = true;
      this.editError = "";
      this.editSuccess = "";

      try {
        const response = await apiFetch(`/api/users/${this.user.id}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            username: trimmedName,
            email: trimmedEmail
          })
        });

        if (!response.ok) {
          const body = await response.json().catch(() => ({}));
          const detail = this.extractError(body) || `Update failed (${response.status})`;
          throw new Error(detail);
        }

        const updated = await response.json();
        this.selectUser(updated.data || updated);
        this.editSuccess = "Profile updated.";
        setTimeout(() => (this.editSuccess = ""), 2500);
        this.fetchAllUsers();
      } catch (err) {
        console.error(err);
        this.editError = err.message || "Unable to update profile.";
      } finally {
        this.editSaving = false;
      }
    },

    // Extract a user-friendly message from either {errors: {...}} or {error: "..."}.
    extractError(body) {
      if (!body) return null;

      if (typeof body.error === "string" && body.error.length > 0) {
        return body.error;
      }

      if (body.errors && typeof body.errors === "object") {
        // Flatten {field: [msg1, msg2], ...} into a single string.
        const parts = Object.entries(body.errors).flatMap(([field, msgs]) => {
          const list = Array.isArray(msgs) ? msgs : [msgs];
          return list.map((m) => `${field}: ${m}`);
        });
        return parts.length > 0 ? parts.join(" · ") : null;
      }

      return null;
    },

    async getUser() {
      const response = await apiFetch(
        `/api/users?email=${encodeURIComponent(this.searchEmail)}`
      );

      if (!response.ok) {
        throw new Error("Failed to find user");
      }

      const users = await response.json();

      if (users.length === 0) {
        this.user = null;
        alert("User not found");
        return;
      }

      this.selectUser(users[0]);
    },

    // Only the general manager can remove other accounts; always ask first.
    async deleteUser() {
      this.removeError = "";
      if (!window.confirm(`Remove ${this.user.username}'s account? This cannot be undone.`)) return;

      const response = await apiFetch(`/api/users/${this.user.id}`, {
        method: "DELETE"
      });

      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        this.removeError = body.error || "Unable to remove this account.";
        return;
      }

      this.user = null;
      this.searchEmail = "";
      this.editUsername = "";
      this.editEmail = "";
      this.fetchAllUsers();
    }
  }
};
</script>

<style src="./User.css"></style>
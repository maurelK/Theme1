<template>
  <main class="page-shell">
    <header class="topbar">
      <a class="brand" href="#" aria-label="Time Manager home">
        <span class="brand-mark">T</span><span>Time Manager</span>
      </a>
      <div class="workspace-actions">
        <span class="workspace-label">{{ authUser?.role || "WORKSPACE" }} <span class="status-dot"></span></span>
        <!-- Let authenticated users terminate the server-side session explicitly. -->
        <button class="text-button" type="button" @click="signOut">Sign out</button>
      </div>
    </header>

    <section class="hero">
      <p class="eyebrow">User Workspace</p>
      <h1>Make time for<br><em>the right people.</em></h1>
      <p class="hero-copy">Manage users, clocking, working times, and charts in one unified dashboard.</p>
    </section>

    <div class="content-grid">
      <!-- Search & Quick Selection Panel -->
      <aside class="search-panel">
        <div class="panel-heading">
          <span class="step-number">01</span>
          <div><p class="eyebrow">Directory</p><h2>Find a person</h2></div>
        </div>
        <form class="search-form" @submit.prevent="getUser">
          <label for="search-email">Email address</label>
          <div class="input-with-icon">
            <span aria-hidden="true">@</span>
            <input 
              id="search-email" 
              v-model="searchEmail" 
              type="email" 
              placeholder="name@company.com" 
              required
            >
          </div>
          <button class="button button-primary" type="submit">
            <span>Search directory</span><span class="button-arrow" aria-hidden="true">&#8599;</span>
          </button>
        </form>
        <p class="helper-text">Enter the user's email address (e.g. axel.ogouchi@epitech.eu).</p>

        <!-- Quick Pick list -->
        <div v-if="allUsers.length > 0" style="margin-top: 24px; border-top: 1px solid #bcc4b8; padding-top: 16px;">
          <p class="eyebrow" style="font-size: 10px; margin-bottom: 8px;">Recent accounts:</p>
          <div style="display: flex; flex-direction: column; gap: 6px;">
            <button 
              v-for="u in allUsers" 
              :key="u.id" 
              type="button" 
              class="btn-link" 
              style="text-align: left; font-size: 12px; color: #263836; text-decoration: none;"
              @click="selectUser(u)"
            >
              &bull; <strong>{{ u.username }}</strong> ({{ u.email }})
            </button>
          </div>
        </div>
      </aside>

      <!-- Main Profile & Connected Dashboard Panel -->
      <section class="main-panel" aria-live="polite">
        <div v-if="user" class="profile-view">
          <!-- Profile Header -->
          <div class="profile-header">
            <div class="avatar">{{ userInitials }}</div>
            <div>
              <p class="eyebrow">Selected account</p>
              <h2>{{ user.username }}</h2>
              <p class="muted">{{ user.email }}</p>
            </div>
            <span class="member-tag">Active</span>
          </div>

          <!-- Edit Account Form -->
          <form class="editor" @submit.prevent="updateUser">
            <div class="section-title">
              <span class="step-number">02</span>
              <div><p class="eyebrow">Profile details</p><h3>Edit account</h3></div>
            </div>
            <div class="form-grid">
              <label>Full name<input v-model="editUsername" type="text" placeholder="Full name" required></label>
              <label>Email address<input v-model="editEmail" type="email" placeholder="name@company.com" required></label>
            </div>
            <div class="editor-actions">
              <button class="button button-primary" type="submit">Save changes<span class="button-arrow" aria-hidden="true">&#8599;</span></button>
              <button class="text-button" type="button" @click="deleteUser">Remove account</button>
            </div>
          </form>

          <!-- Connected Application Dashboard Section -->
          <div class="user-dashboard-section" style="margin-top: 36px;">
            <div class="section-title" style="margin-bottom: 20px;">
              <span class="step-number">03</span>
              <div>
                <p class="eyebrow">Time Management &amp; Insights</p>
                <h3>{{ user.username }}'s Workspace</h3>
              </div>
            </div>

            <!-- Tab Navigation Bar -->
            <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 24px; border-bottom: 2px solid #273a37; padding-bottom: 12px;">
              <button 
                type="button" 
                class="btn-wt" 
                :class="activeTab === 'workingTimes' ? 'btn-primary' : 'btn-outline'"
                @click="activeTab = 'workingTimes'"
              >
                Working Times
              </button>

              <button 
                type="button" 
                class="btn-wt" 
                :class="activeTab === 'clock' ? 'btn-primary' : 'btn-outline'"
                @click="activeTab = 'clock'"
              >
                Clock Manager
              </button>

              <button 
                type="button" 
                class="btn-wt" 
                :class="activeTab === 'charts' ? 'btn-primary' : 'btn-outline'"
                @click="activeTab = 'charts'"
              >
                Charts
              </button>

              <button 
                type="button" 
                class="btn-wt" 
                :class="activeTab === 'create' ? 'btn-primary' : 'btn-outline'"
                @click="activeTab = 'create'"
              >
                Create Entry
              </button>
            </div>

            <!-- Tab Content Views -->
            <div class="tab-content-area">
              <WorkingTimes
                v-if="activeTab === 'workingTimes'"
                :userId="user.id"
                @go-create-entry="activeTab = 'create'"
              />
              <ClockManager v-else-if="activeTab === 'clock'" :userId="user.id" />
              <ChartManager v-else-if="activeTab === 'charts'" :userId="user.id" />
              <WorkingTime v-else-if="activeTab === 'create'" :userId="user.id" />
            </div>
          </div>
        </div>

        <div v-else class="empty-state">
          <div class="empty-orbit"><span></span></div>
          <p class="eyebrow">Your directory awaits</p>
          <h2>Search or select an account<br>to get started.</h2>
          <p class="muted">The person's working times, clock status, and charts will appear here.</p>
        </div>

        <!-- Add New Person Panel -->
        <div class="create-panel" style="margin-top: 40px;">
          <div class="section-title">
            <span class="step-number">04</span>
            <div><p class="eyebrow">New entry</p><h3>Add someone</h3></div>
          </div>
          <form class="create-form" @submit.prevent="createUser">
            <input v-model="newUsername" type="text" placeholder="Full name" aria-label="New user name" required>
            <input v-model="newEmail" type="email" placeholder="Email address" aria-label="New user email" required>
            <button class="button button-secondary" type="submit">Add person <span aria-hidden="true">+</span></button>
          </form>
        </div>
      </section>
    </div>
    
    <footer class="footer">
      <span>Time Manager directory &amp; Working Time System</span>
      <span>Made for focused teams &middot; 2026</span>
    </footer>
  </main>
</template>

<script>
import WorkingTimes from "./WorkingTimes.vue";
import WorkingTime from "./WorkingTime.vue";
import ClockManager from "./ClockManager.vue";
import ChartManager from "./ChartManager.vue";
// Route profile requests through the shared authenticated API helper.
import { apiFetch, authState, logout } from "../services/auth";

export default {
  name: "User",

  components: {
    WorkingTimes,
    WorkingTime,
    ClockManager,
    ChartManager
  },

  data() {
    return {
      user: null,
      searchEmail: "",
      newUsername: "",
      newEmail: "",
      editUsername: "",
      editEmail: "",
      activeTab: "workingTimes",
      allUsers: []
    };
  },

  computed: {
    // Reflect the server-authorized role in the authenticated workspace header.
    authUser() {
      return authState.user;
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
          else if (this.$route.name === 'ChartManager') this.activeTab = 'charts';
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

    // Clear authentication state and return to the public login route.
    async signOut() {
      await logout();
      this.user = null;
      await this.$router.push({ name: "Login" });
    },

    async createUser() {
      const response = await apiFetch("/api/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: this.newUsername,
          email: this.newEmail
        })
      });

      if (!response.ok) {
        throw new Error("Failed to create user");
      }

      const createdUser = await response.json();
      const u = createdUser.data || createdUser;

      this.selectUser(u);
      this.newUsername = "";
      this.newEmail = "";
      this.fetchAllUsers();
      this.activeTab = "workingTimes";
    },

    async updateUser() {
      const response = await apiFetch(`/api/users/${this.user.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: this.editUsername,
          email: this.editEmail
        })
      });

      if (!response.ok) {
        throw new Error("Failed to update user");
      }

      const updated = await response.json();
      this.selectUser(updated.data || updated);
      this.fetchAllUsers();
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

    async deleteUser() {
      const response = await apiFetch(`/api/users/${this.user.id}`, {
        method: "DELETE"
      });

      if (!response.ok) {
        throw new Error("Failed to delete user");
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

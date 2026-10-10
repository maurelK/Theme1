<template>
  <AppLayout>
    <main class="admin-teams-shell">
      <header class="admin-teams-header">
        <div>
          <p class="eyebrow">Teams</p>
          <h1>Organization <em>teams</em></h1>
          <p class="lede">Browse teams and their members. Add or remove members inline.</p>
        </div>
      </header>

      <div class="admin-teams-layout">
        <!-- Team list -->
        <aside class="team-list-panel">
          <p class="eyebrow">All teams ({{ teams.length }})</p>
          <input
            v-model="filter"
            type="text"
            class="team-filter"
            placeholder="Filter by team name"
          />
          <ul class="team-list">
            <li v-if="filteredTeams.length === 0" class="team-list-empty">
              No teams match.
            </li>
            <li v-for="team in filteredTeams" :key="team.id">
              <button
                class="team-list-item"
                :class="{ active: selectedTeamId === team.id }"
                type="button"
                @click="selectTeam(team)"
              >
                <span class="team-list-item-name">{{ team.name }}</span>
                <span class="team-list-item-count">{{ team.users.length }}</span>
              </button>
            </li>
          </ul>
        </aside>

        <!-- Team detail -->
        <section class="team-detail-panel">
          <div v-if="!selectedTeam" class="team-detail-empty">
            <p class="eyebrow">Select a team</p>
            <p>Pick a team on the left to view and manage its members.</p>
          </div>

          <div v-else>
            <header class="team-detail-header">
              <h2>{{ selectedTeam.name }}</h2>
              <span class="team-detail-count">{{ selectedTeam.users.length }} members</span>
            </header>

            <p v-if="actionError" class="alert alert-error">{{ actionError }}</p>
            <p v-if="actionMessage" class="alert alert-success">{{ actionMessage }}</p>

            <!-- Add member -->
            <div class="add-member-row">
              <input
                v-model="addMemberQuery"
                type="text"
                class="add-member-input"
                placeholder="Search a user by name or email"
              />
              <button
                class="btn-wt btn-primary"
                type="button"
                :disabled="!selectedUserId || addingMember"
                @click="addMember"
              >
                {{ addingMember ? "Adding..." : "Add member" }}
              </button>
            </div>

            <ul v-if="filteredCandidateUsers.length > 0 && addMemberQuery" class="candidate-list">
              <li v-for="candidate in filteredCandidateUsers" :key="candidate.id">
                <button type="button" @click="pickCandidate(candidate)">
                  <span>{{ candidate.username }}</span>
                  <span class="candidate-email">{{ candidate.email }}</span>
                </button>
              </li>
            </ul>
            <p v-if="selectedUserId && !addMemberQuery" class="add-member-hint">
              Selected: <strong>{{ candidateLabel }}</strong>
              <button type="button" class="link-button" @click="clearCandidate">change</button>
            </p>

            <!-- Member list -->
            <ul class="member-list">
              <li v-for="member in selectedTeam.users" :key="member.id">
                <div>
                  <p class="member-name">{{ member.username }}</p>
                  <p class="member-email">{{ member.email }}</p>
                </div>
                <span class="member-role">{{ member.role || "—" }}</span>
                <button
                  class="btn-wt btn-danger small"
                  type="button"
                  :disabled="removingMemberId === member.id"
                  @click="removeMember(member)"
                >
                  {{ removingMemberId === member.id ? "..." : "Remove" }}
                </button>
              </li>
              <li v-if="selectedTeam.users.length === 0" class="member-empty">
                No members yet.
              </li>
            </ul>
          </div>
        </section>
      </div>
    </main>
  </AppLayout>
</template>

<script>
import AppLayout from "../components/AppLayout.vue";
import { apiFetch } from "../services/auth";

export default {
  name: "AdminTeamsView",

  components: { AppLayout },

  data() {
    return {
      teams: [],
      users: [],
      filter: "",
      selectedTeamId: null,
      addMemberQuery: "",
      selectedUserId: null,
      addingMember: false,
      removingMemberId: null,
      actionMessage: "",
      actionError: ""
    };
  },

  computed: {
    filteredTeams() {
      const q = this.filter.trim().toLowerCase();
      if (!q) return this.teams;
      return this.teams.filter((t) => t.name.toLowerCase().includes(q));
    },

    selectedTeam() {
      return this.teams.find((t) => t.id === this.selectedTeamId) || null;
    },

    // Users not already in the selected team, filtered by the query.
    filteredCandidateUsers() {
      if (!this.selectedTeam) return [];
      const memberIds = new Set(this.selectedTeam.users.map((u) => u.id));
      const q = this.addMemberQuery.trim().toLowerCase();

      return this.users
        .filter((u) => !memberIds.has(u.id))
        .filter((u) => {
          if (!q) return true;
          return (
            (u.username || "").toLowerCase().includes(q) ||
            (u.email || "").toLowerCase().includes(q)
          );
        })
        .slice(0, 8);
    },

    candidateLabel() {
      const u = this.users.find((x) => x.id === this.selectedUserId);
      return u ? `${u.username} (${u.email})` : "";
    }
  },

  mounted() {
    this.loadTeams();
    this.loadUsers();
  },

  methods: {
    async loadTeams() {
      const res = await apiFetch("/api/teams");
      if (res.ok) {
        const data = await res.json();
        this.teams = Array.isArray(data) ? data : (data.data || []);
      }
    },

    async loadUsers() {
      const res = await apiFetch("/api/users");
      if (res.ok) {
        const data = await res.json();
        this.users = Array.isArray(data) ? data : (data.data || []);
      }
    },

    selectTeam(team) {
      this.selectedTeamId = team.id;
      this.addMemberQuery = "";
      this.selectedUserId = null;
      this.actionError = "";
      this.actionMessage = "";
    },

    pickCandidate(user) {
      this.selectedUserId = user.id;
      this.addMemberQuery = "";
    },

    clearCandidate() {
      this.selectedUserId = null;
    },

    async addMember() {
      if (!this.selectedUserId) return;
      this.addingMember = true;
      this.actionError = "";

      try {
        const res = await apiFetch(
          `/api/admin/teams/${this.selectedTeamId}/members/${this.selectedUserId}`,
          { method: "POST" }
        );
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          throw new Error(body.error || `Add failed (${res.status})`);
        }
        this.actionMessage = "Member added.";
        this.selectedUserId = null;
        await this.loadTeams();
        setTimeout(() => (this.actionMessage = ""), 2500);
      } catch (err) {
        this.actionError = err.message;
      } finally {
        this.addingMember = false;
      }
    },

    async removeMember(member) {
      if (!confirm(`Remove ${member.username} from ${this.selectedTeam.name}?`)) return;
      this.removingMemberId = member.id;
      this.actionError = "";

      try {
        const res = await apiFetch(
          `/api/admin/teams/${this.selectedTeamId}/members/${member.id}`,
          { method: "DELETE" }
        );
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          throw new Error(body.error || `Remove failed (${res.status})`);
        }
        this.actionMessage = "Member removed.";
        await this.loadTeams();
        setTimeout(() => (this.actionMessage = ""), 2500);
      } catch (err) {
        this.actionError = err.message;
      } finally {
        this.removingMemberId = null;
      }
    }
  }
};
</script>

<style scoped>
.admin-teams-shell {
  max-width: var(--content-max, 1240px);
  margin: 0 auto;
  padding: 24px var(--content-padding, 24px) 60px;
}

.admin-teams-header h1 {
  margin: 0 0 6px;
  color: #243332;
  font-size: clamp(30px, 5vw, 48px);
  font-weight: 500;
  letter-spacing: -0.05em;
}

.admin-teams-header h1 em {
  color: #b5684b;
  font-family: "Playfair Display", Georgia, serif;
  font-style: italic;
}

.admin-teams-header .lede {
  color: #71807a;
  font-size: 14px;
  max-width: 640px;
  margin: 0 0 28px;
}

.admin-teams-layout {
  display: grid;
  grid-template-columns: minmax(240px, 0.8fr) minmax(0, 1.8fr);
  gap: 24px;
  align-items: start;
}

.team-list-panel {
  border: 1px solid #d4d6cc;
  background: #fffdf7;
  padding: 20px;
}

.team-filter {
  width: 100%;
  border: 0;
  border-bottom: 1px solid #bcc4b8;
  background: transparent;
  color: #263836;
  padding: 8px 0;
  font: 13px "Manrope", sans-serif;
  outline: 0;
  margin: 10px 0 14px;
}

.team-filter:focus {
  border-color: #bd684c;
}

.team-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0;
}

.team-list-item {
  width: 100%;
  border: 0;
  border-bottom: 1px solid #e4e7de;
  background: transparent;
  color: #243332;
  padding: 12px 6px;
  text-align: left;
  cursor: pointer;
  font: 500 14px "Manrope", sans-serif;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  transition: background 0.15s;
}

.team-list-item:hover {
  background: #f3f0e9;
}

.team-list-item.active {
  background: #e4e7de;
  font-weight: 600;
}

.team-list-item-count {
  color: #71807a;
  font: 10px "DM Mono", monospace;
  letter-spacing: 0.08em;
}

.team-list-empty {
  color: #71807a;
  font-size: 13px;
  padding: 12px 0;
}

.team-detail-panel {
  border: 1px solid #d4d6cc;
  background: #fffdf7;
  padding: 24px;
  min-height: 300px;
}

.team-detail-empty {
  color: #71807a;
  font-size: 14px;
}

.team-detail-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 20px;
  padding-bottom: 14px;
  border-bottom: 1px solid #d4d6cc;
}

.team-detail-header h2 {
  margin: 0;
  font: 600 22px "Manrope", sans-serif;
  letter-spacing: -0.04em;
  color: #243332;
}

.team-detail-count {
  color: #71807a;
  font: 10px "DM Mono", monospace;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.add-member-row {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
}

.add-member-input {
  flex: 1;
  border: 0;
  border-bottom: 1px solid #bcc4b8;
  background: transparent;
  color: #263836;
  padding: 8px 0;
  font: 13px "Manrope", sans-serif;
  outline: 0;
}

.add-member-input:focus {
  border-color: #bd684c;
}

.candidate-list {
  list-style: none;
  margin: 0 0 12px;
  padding: 0;
  border: 1px solid #e4e7de;
  background: #fbf9f4;
  max-height: 180px;
  overflow-y: auto;
}

.candidate-list li + li {
  border-top: 1px solid #e4e7de;
}

.candidate-list button {
  width: 100%;
  border: 0;
  background: transparent;
  text-align: left;
  padding: 10px;
  cursor: pointer;
  font: 13px "Manrope", sans-serif;
  display: flex;
  justify-content: space-between;
  gap: 8px;
}

.candidate-list button:hover {
  background: #f3f0e9;
}

.candidate-email {
  color: #71807a;
  font-size: 12px;
}

.add-member-hint {
  margin: 0 0 16px;
  color: #71807a;
  font-size: 12px;
}

.link-button {
  border: 0;
  background: transparent;
  color: #a3614a;
  cursor: pointer;
  text-decoration: underline;
  padding: 0 6px;
  font: inherit;
}

.alert {
  margin: 0 0 14px;
  padding: 10px 12px;
  font-size: 12px;
}

.alert-error {
  color: #a3614a;
  background: #f6e6de;
  border-left: 3px solid #a3614a;
}

.alert-success {
  color: #287c78;
  background: #d9eae8;
  border-left: 3px solid #287c78;
}

.member-list {
  list-style: none;
  margin: 16px 0 0;
  padding: 0;
  display: grid;
  gap: 0;
}

.member-list li {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 12px;
  align-items: center;
  padding: 12px 0;
  border-top: 1px solid #e4e7de;
}

.member-name {
  margin: 0;
  color: #243332;
  font-size: 14px;
  font-weight: 500;
}

.member-email {
  margin: 2px 0 0;
  color: #71807a;
  font-size: 12px;
}

.member-role {
  color: #71807a;
  font: 10px "DM Mono", monospace;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.member-empty {
  grid-template-columns: 1fr;
  color: #71807a;
  font-size: 13px;
}

.btn-wt.small {
  padding: 6px 12px;
  font-size: 11px;
}

@media (max-width: 760px) {
  .admin-teams-layout {
    grid-template-columns: 1fr;
  }

  .member-list li {
    grid-template-columns: 1fr auto;
  }

  .member-role {
    grid-column: 1 / -1;
  }
}
</style>
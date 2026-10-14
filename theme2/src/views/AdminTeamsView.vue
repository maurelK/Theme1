<template>
  <AppLayout>
    <main class="admin-teams-shell">
      <header class="admin-teams-header">
        <div>
          <p class="eyebrow">Teams</p>
          <h1>Organization <em>teams</em></h1>
          <p class="lede">Select a team to manage its members and see its working hours.</p>
        </div>
      </header>

      <div class="admin-teams-layout">
        <!-- Team list -->
        <aside class="team-list-panel">
          <!-- Works offline: queued and created when the connection returns. -->
          <form v-if="canManageMembers" class="create-team-form" @submit.prevent="createTeam">
            <label for="new-team-name" class="eyebrow">New team (works offline)</label>
            <div class="add-member-row">
              <input id="new-team-name" v-model="newTeamName" type="text" class="add-member-input" placeholder="Team name" required>
              <button class="btn-wt btn-primary" type="submit" :disabled="creatingTeam">
                {{ creatingTeam ? "Creating..." : "Create" }}
              </button>
            </div>
          </form>

          <p class="eyebrow">All teams ({{ displayTeams.length }})</p>
          <input
            v-model="filter"
            type="text"
            class="team-filter"
            placeholder="Filter by team name"
            aria-label="Filter by team name"
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
                <span class="team-list-item-name">
                  {{ team.name }}
                  <span v-if="team.pending" class="pending-tag">Not sent yet</span>
                </span>
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

            <p v-if="actionError" class="alert alert-error" role="alert">{{ actionError }}</p>
            <p v-if="actionMessage" class="alert alert-success" role="status">{{ actionMessage }}</p>

            <!-- A team created offline has no server id yet: members come after the sync. -->
            <p v-if="selectedTeam.pending" class="alert">
              This team will be created when the connection returns. You can add members once it exists.
            </p>

            <!-- Add member (works offline) -->
            <div v-else-if="canManageMembers" ref="candidatesRef" class="candidates-wrap">
              <div class="add-member-row">
                <input
                  v-model="addMemberQuery"
                  type="text"
                  class="add-member-input"
                  placeholder="Search a user by name or email"
                  aria-label="Search a user to add"
                  @focus="addMemberFocused = true"
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

              <p
                v-if="addMemberFocused && availableUserCount > 0"
                class="candidate-hint"
              >
                Showing {{ filteredCandidateUsers.length }} of
                {{ availableUserCount }} available user{{ availableUserCount === 1 ? "" : "s" }}.
                <span v-if="!addMemberQuery">Type to filter.</span>
              </p>

              <ul
                v-if="addMemberFocused && filteredCandidateUsers.length > 0"
                class="candidate-list"
              >
                <li v-for="candidate in filteredCandidateUsers" :key="candidate.id">
                  <button type="button" @mousedown.prevent="pickCandidate(candidate)">
                    <span>{{ candidate.username }}</span>
                    <span v-if="candidate.email" class="candidate-email">{{ candidate.email }}</span>
                  </button>
                </li>
              </ul>

              <p
                v-else-if="addMemberFocused && availableUserCount === 0"
                class="candidate-hint"
              >
                No users available to add.
              </p>

              <p v-if="selectedUserId && !addMemberFocused" class="add-member-hint">
                Selected: <strong>{{ candidateLabel }}</strong>
                <button type="button" class="link-button" @click="clearCandidate">change</button>
              </p>
            </div>

            <!-- Member list -->
            <ul class="member-list">
              <li v-for="member in selectedTeam.users" :key="member.id">
                <div>
                  <p class="member-name">
                    {{ member.username }}
                    <span v-if="member.pending" class="pending-tag">Not sent yet</span>
                  </p>
                  <p class="member-email">{{ member.email }}</p>
                </div>
                <span class="member-role">{{ formatRole(member.role) }}</span>
                <button
                  v-if="canManageMembers && !member.pending"
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

            <TeamHours v-if="!selectedTeam.pending" :teamId="selectedTeam.id" />
          </div>
        </section>
      </div>
    </main>
  </AppLayout>
</template>

<script>
import AppLayout from "../components/AppLayout.vue";
import TeamHours from "../components/TeamHours.vue";
import { apiFetch, authState } from "../services/auth";
import { formatRole } from "../utils/roles";
import { outboxChanges, pendingItems, sendOrQueue } from "../data/mutations";
import { sync } from "../data/sync";
import { confirmDialog } from "../platform/native";

const TYPE = "team";
const QUEUED_MESSAGE = "Saved on this device. It will be applied when the connection returns.";

export default {
  name: "AdminTeamsView",

  components: { AppLayout, TeamHours },

  data() {
    return {
      teams: [],
      users: [],
      // Team actions queued offline, shown on top of the server data.
      pending: [],
      filter: "",
      selectedTeamId: null,
      newTeamName: "",
      creatingTeam: false,
      addMemberQuery: "",
      addMemberFocused: false,
      selectedUserId: null,
      addingMember: false,
      removingMemberId: null,
      actionMessage: "",
      actionError: ""
    };
  },

  computed: {
    // HR can read teams but only administrators and managers change membership (enforced by the API too).
    canManageMembers() {
      return ["administrator", "manager"].includes(authState.user?.role);
    },

    // Bumped when the outbox changes (action queued or synced).
    outboxVersion() {
      return outboxChanges.value;
    },

    // Server teams with queued changes applied: new teams, added and removed members.
    displayTeams() {
      const created = this.pending
        .filter((item) => item.meta.kind === "create")
        .map((item) => ({ id: `pending-${item.id}`, name: item.meta.name, users: [], pending: true }));

      const withChanges = this.teams.map((team) => {
        const changes = this.pending.filter((item) => String(item.meta.teamId) === String(team.id));
        const removed = new Set(changes.filter((c) => c.meta.kind === "remove").map((c) => c.meta.userId));
        const added = changes
          .filter((c) => c.meta.kind === "add" && !team.users.some((u) => u.id === c.meta.user.id))
          .map((c) => ({ ...c.meta.user, pending: true }));
        return { ...team, users: [...team.users.filter((u) => !removed.has(u.id)), ...added] };
      });

      return [...withChanges, ...created];
    },

    filteredTeams() {
      const q = this.filter.trim().toLowerCase();
      if (!q) return this.displayTeams;
      return this.displayTeams.filter((t) => t.name.toLowerCase().includes(q));
    },

    selectedTeam() {
      return this.displayTeams.find((t) => t.id === this.selectedTeamId) || null;
    },

    // Total candidates available (users not already in the selected team).
    availableUserCount() {
      if (!this.selectedTeam) return 0;
      const memberIds = new Set(this.selectedTeam.users.map((u) => u.id));
      return this.users.filter((u) => !memberIds.has(u.id)).length;
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
        .slice(0, 20);
    },

    candidateLabel() {
      const u = this.users.find((x) => x.id === this.selectedUserId);
      return u ? `${u.username}${u.email ? ` (${u.email})` : ""}` : "";
    }
  },

  watch: {
    outboxVersion() {
      this.loadPending();
    }
  },

  mounted() {
    this.loadTeams();
    this.loadUsers();
    this.loadPending();
    // Once queued actions reach the server, show the real teams.
    this.stopSyncListener = sync.onSynced(() => this.loadTeams());
    document.addEventListener("click", this.onDocumentClick);
  },

  beforeUnmount() {
    this.stopSyncListener?.();
    document.removeEventListener("click", this.onDocumentClick);
  },

  methods: {
    formatRole,

    // Offline, apiFetch answers with the copy saved on the phone.
    async loadTeams() {
      try {
        const res = await apiFetch("/api/teams", { silent: true });
        if (res.ok) {
          const data = await res.json();
          this.teams = Array.isArray(data) ? data : (data.data || []);
        }
      } catch {
        this.actionError = "Teams are not saved on this device yet. Open this page once with a connection.";
      }
    },

    async loadUsers() {
      try {
        const res = await apiFetch("/api/users", { silent: true });
        if (res.ok) {
          const data = await res.json();
          this.users = Array.isArray(data) ? data : (data.data || []);
        }
      } catch {
        // No saved copy offline: there are simply no candidates to add.
      }
    },

    async loadPending() {
      this.pending = await pendingItems(TYPE);
    },

    selectTeam(team) {
      this.selectedTeamId = team.id;
      this.addMemberQuery = "";
      this.addMemberFocused = false;
      this.selectedUserId = null;
      this.actionError = "";
      this.actionMessage = "";
    },

    // Close the candidate dropdown when clicking outside it.
    onDocumentClick(e) {
      const wrap = this.$refs.candidatesRef;
      if (wrap && !wrap.contains(e.target)) {
        this.addMemberFocused = false;
      }
    },

    pickCandidate(user) {
      this.selectedUserId = user.id;
      this.addMemberQuery = "";
      this.addMemberFocused = false;
    },

    clearCandidate() {
      this.selectedUserId = null;
      this.addMemberFocused = true;
    },

    flash(message) {
      this.actionMessage = message;
      setTimeout(() => (this.actionMessage = ""), 3000);
    },

    async createTeam() {
      const name = this.newTeamName.trim();
      if (!name) return;
      this.creatingTeam = true;
      this.actionError = "";

      try {
        const { queued, data } = await sendOrQueue({
          type: TYPE,
          label: `Create team "${name}"`,
          method: "POST",
          path: "/api/teams",
          body: { name },
          meta: { kind: "create", name }
        });
        this.newTeamName = "";
        await this.loadPending();
        if (queued) {
          this.flash(QUEUED_MESSAGE);
        } else {
          await this.loadTeams();
          if (data?.id) this.selectedTeamId = data.id;
          this.flash(`Team "${name}" created.`);
        }
      } catch (err) {
        this.actionError = err.message;
      } finally {
        this.creatingTeam = false;
      }
    },

    async addMember() {
      if (!this.selectedUserId) return;
      const user = this.users.find((u) => u.id === this.selectedUserId);
      const team = this.selectedTeam;
      this.addingMember = true;
      this.actionError = "";

      try {
        const { queued } = await sendOrQueue({
          type: TYPE,
          label: `Add ${user.username} to ${team.name}`,
          method: "POST",
          path: `/api/teams/${team.id}/members/${user.id}`,
          meta: {
            kind: "add",
            teamId: team.id,
            user: { id: user.id, username: user.username, email: user.email, role: user.role }
          }
        });
        this.selectedUserId = null;
        await this.loadPending();
        if (!queued) await this.loadTeams();
        this.flash(queued ? QUEUED_MESSAGE : "Member added.");
      } catch (err) {
        this.actionError = err.message;
      } finally {
        this.addingMember = false;
      }
    },

    async removeMember(member) {
      const team = this.selectedTeam;
      const confirmed = await confirmDialog(`Remove ${member.username} from ${team.name}?`, {
        title: "Remove member",
        confirmLabel: "Remove"
      });
      if (!confirmed) return;

      this.removingMemberId = member.id;
      this.actionError = "";

      try {
        const { queued } = await sendOrQueue({
          type: TYPE,
          label: `Remove ${member.username} from ${team.name}`,
          method: "DELETE",
          path: `/api/teams/${team.id}/members/${member.id}`,
          // Already removed by someone else: the goal is reached.
          okStatuses: [404],
          meta: { kind: "remove", teamId: team.id, userId: member.id }
        });
        await this.loadPending();
        if (!queued) await this.loadTeams();
        this.flash(queued ? QUEUED_MESSAGE : "Member removed.");
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

.candidates-wrap {
  position: relative;
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

.candidate-hint {
  margin: 4px 0 8px;
  color: #71807a;
  font-size: 11px;
  font-family: "DM Mono", monospace;
  letter-spacing: 0.05em;
}

.candidate-list {
  list-style: none;
  margin: 0 0 12px;
  padding: 0;
  border: 1px solid #e4e7de;
  background: #fbf9f4;
  max-height: 220px;
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

/* Offline: team creation form and actions not sent yet. */
.create-team-form {
  display: grid;
  gap: 8px;
  margin-bottom: 20px;
}

.pending-tag {
  display: inline-block;
  margin-left: 6px;
  padding: 1px 6px;
  border: 1px solid #8a5a00;
  color: #5c3d00;
  font-size: 11px;
  font-weight: 600;
  vertical-align: middle;
}
</style>
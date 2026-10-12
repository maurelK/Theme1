<template>
  <AppLayout>
    <main class="dashboard-shell">
      <section class="dashboard-hero">
        <p class="dashboard-eyebrow">General manager</p>
        <h1>Administration</h1>
        <p class="hero-description">Invite people, assign roles, organise teams and set working shifts.</p>
      </section>

      <p v-if="loadError" class="dashboard-error" role="alert">{{ loadError }}</p>

      <section class="dashboard-grid admin-grid">
        <!-- Users -->
        <article class="dashboard-card dashboard-admin-card">
          <h2>Invite a user</h2>
          <p>They receive an email link to set their password.</p>
          <form class="dashboard-admin-form" @submit.prevent="inviteUser">
            <label>Full name<input v-model="invite.username" type="text" autocomplete="off" required></label>
            <label>Email address<input v-model="invite.email" type="email" autocomplete="off" required></label>
            <label>Role<select v-model="invite.role" required>
              <option v-for="name in INVITABLE_ROLES" :key="name" :value="name">{{ formatRole(name) }}</option>
            </select></label>
            <button class="dashboard-button" type="submit" :disabled="inviting">
              {{ inviting ? "Sending..." : "Send invite" }}
            </button>
          </form>
          <p v-if="inviteFeedback.text" :class="feedbackClass(inviteFeedback)" role="status">{{ inviteFeedback.text }}</p>
        </article>

        <article class="dashboard-card dashboard-admin-card">
          <h2>Change a role</h2>
          <p>Promote an employee to manager, or change any user's role.</p>
          <form class="dashboard-admin-form" @submit.prevent="changeRole">
            <label>User<select v-model="roleForm.userId" required>
              <option disabled value="">Select a user</option>
              <option v-for="user in users" :key="user.id" :value="user.id">
                {{ user.username }} ({{ formatRole(user.role) }})
              </option>
            </select></label>
            <label>New role<select v-model="roleForm.role" required>
              <option v-for="availableRole in roles" :key="availableRole.id" :value="availableRole.name">
                {{ formatRole(availableRole.name) }}
              </option>
            </select></label>
            <button class="dashboard-button" type="submit">Save role</button>
          </form>
          <p v-if="roleFeedback.text" :class="feedbackClass(roleFeedback)" role="status">{{ roleFeedback.text }}</p>
        </article>

        <!-- Teams -->
        <article class="dashboard-card dashboard-admin-card">
          <h2>Teams</h2>
          <p>{{ teams.length }} team{{ teams.length === 1 ? "" : "s" }}. Add or remove members from the teams page.</p>
          <form class="dashboard-admin-form" @submit.prevent="createTeam">
            <label>New team name<input v-model="newTeamName" type="text" required></label>
            <button class="dashboard-button" type="submit">Create team</button>
          </form>
          <p v-if="teamFeedback.text" :class="feedbackClass(teamFeedback)" role="status">{{ teamFeedback.text }}</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Manage team members</RouterLink>
        </article>

        <!-- Shifts -->
        <article class="dashboard-card dashboard-admin-card">
          <h2>Shifts</h2>
          <p>Set the shift for a user or a team. Users inherit their team's shift, or the default one.</p>
          <div class="shift-config-targets">
            <button class="dashboard-button" type="button" @click="pickerMode = 'user'">Set a user's shift</button>
            <button class="dashboard-button" type="button" @click="pickerMode = 'team'">Set a team's shift</button>
          </div>
          <p v-if="shiftFeedback" class="dashboard-feedback" role="status">{{ shiftFeedback }}</p>
        </article>
      </section>
    </main>

    <ShiftTargetPicker
      v-if="pickerMode"
      :mode="pickerMode"
      :users="users"
      :teams="teams"
      @close="pickerMode = null"
      @selected="onPickerSelected"
    />

    <ShiftEditorModal
      v-if="shiftTarget"
      :target="shiftTarget"
      @close="shiftTarget = null"
      @saved="onShiftSaved"
    />
  </AppLayout>
</template>

<script setup>
import { onMounted, reactive, ref } from "vue";
import { apiFetch } from "../services/auth";
import { formatRole } from "../utils/roles";
import AppLayout from "../components/AppLayout.vue";
import ShiftEditorModal from "../components/ShiftEditorModal.vue";
import ShiftTargetPicker from "../components/ShiftTargetPicker.vue";
import "./Dashboard.css";

// Administrator is left out on purpose: granting it is a separate, deliberate role change.
const INVITABLE_ROLES = ["employee", "manager", "hr_payroll"];

const users = ref([]);
const roles = ref([]);
const teams = ref([]);
const loadError = ref("");

const invite = reactive({ username: "", email: "", role: "employee" });
const inviting = ref(false);
const inviteFeedback = reactive({ text: "", error: false });

const roleForm = reactive({ userId: "", role: "" });
const roleFeedback = reactive({ text: "", error: false });

const newTeamName = ref("");
const teamFeedback = reactive({ text: "", error: false });

const pickerMode = ref(null); // null | "user" | "team"
const shiftTarget = ref(null);
const shiftFeedback = ref("");

onMounted(async () => {
  const [usersOk, rolesOk, teamsOk] = await Promise.all([loadUsers(), loadRoles(), loadTeams()]);
  if (!usersOk || !rolesOk || !teamsOk) loadError.value = "Some data could not be loaded. Refresh the page to try again.";
});

async function loadUsers() {
  const response = await apiFetch("/api/users");
  if (response.ok) users.value = await response.json();
  return response.ok;
}

async function loadRoles() {
  const response = await apiFetch("/api/roles");
  if (response.ok) {
    roles.value = await response.json();
    roleForm.role = roles.value[0]?.name || "";
  }
  return response.ok;
}

async function loadTeams() {
  const response = await apiFetch("/api/teams");
  if (response.ok) teams.value = await response.json();
  return response.ok;
}

function setFeedback(target, text, error = false) {
  target.text = text;
  target.error = error;
}

function feedbackClass(feedback) {
  return feedback.error ? "dashboard-error" : "dashboard-feedback";
}

// Turn an API error body into a readable sentence.
async function errorText(response, fallback) {
  const body = await response.json().catch(() => ({}));
  if (body.errors) return Object.values(body.errors).flat().join(", ");
  return body.error || fallback;
}

async function inviteUser() {
  inviting.value = true;
  setFeedback(inviteFeedback, "");

  try {
    const response = await apiFetch("/api/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...invite })
    });

    if (!response.ok) {
      setFeedback(inviteFeedback, await errorText(response, "Unable to send the invite."), true);
      return;
    }

    setFeedback(inviteFeedback, `Invite sent to ${invite.email}.`);
    Object.assign(invite, { username: "", email: "", role: "employee" });
    await loadUsers();
  } finally {
    inviting.value = false;
  }
}

async function changeRole() {
  const response = await apiFetch(`/api/admin/users/${roleForm.userId}/role`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ role: roleForm.role })
  });

  if (!response.ok) {
    setFeedback(roleFeedback, await errorText(response, "Unable to update the role."), true);
    return;
  }

  setFeedback(roleFeedback, "Role updated.");
  await loadUsers();
}

async function createTeam() {
  const response = await apiFetch("/api/teams", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: newTeamName.value })
  });

  if (!response.ok) {
    setFeedback(teamFeedback, await errorText(response, "Unable to create the team."), true);
    return;
  }

  setFeedback(teamFeedback, `Team "${newTeamName.value}" created.`);
  newTeamName.value = "";
  await loadTeams();
}

function onPickerSelected(item) {
  shiftTarget.value = pickerMode.value === "user"
    ? { type: "user", id: item.id, label: `${item.label} (${item.sub})` }
    : { type: "team", id: item.id, label: item.label };
  pickerMode.value = null;
  shiftFeedback.value = "";
}

function onShiftSaved() {
  shiftTarget.value = null;
  shiftFeedback.value = "Shift saved.";
}
</script>

<style scoped>
.admin-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
/* Half-width cards: stack form fields instead of the dashboard's single row. */
.admin-grid .dashboard-admin-form { flex-direction: column; align-items: stretch; }
.admin-grid .dashboard-admin-form label { display: grid; gap: 6px; }

@media (max-width: 760px) {
  .admin-grid { grid-template-columns: 1fr; }
}
</style>

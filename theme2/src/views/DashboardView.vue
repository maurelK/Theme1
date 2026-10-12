<template>
  <AppLayout>
    <main class="dashboard-shell">
      <section class="dashboard-hero">
        <p class="dashboard-eyebrow hero-role">{{ roleLabel }}</p>
        <h1 class="hero-title" aria-label="Dashboard overview">
          <span class="hero-title-line">
            <span
              v-for="(character, index) in heroTitleCharacters"
              :key="`title-${index}`"
              class="hero-letter"
              aria-hidden="true"
              :style="{ animationDelay: `${index * 35}ms` }"
            >{{ character === " " ? "\u00a0" : character }}</span>
          </span>
          <br>
          <em class="hero-title-line">
            <span
              v-for="(character, index) in heroAccentCharacters"
              :key="`accent-${index}`"
              class="hero-letter"
              aria-hidden="true"
              :style="{ animationDelay: `${(heroTitleCharacters.length * 35) + 180 + index * 45}ms` }"
            >{{ character === " " ? "\u00a0" : character }}</span>
          </em>
        </h1>
        <p class="hero-description" aria-label="Dashboard description">
          <span
            v-for="(word, index) in heroDescriptionWords"
            :key="`description-${index}`"
            class="hero-word"
            aria-hidden="true"
            :style="{ animationDelay: `${(heroTitleCharacters.length + heroAccentCharacters.length) * 35 + 500 + index * 55}ms` }"
          >{{ word }}</span>
        </p>
      </section>

      <section class="dashboard-note">
        <strong>{{ noteTitle }}</strong>
        <span>{{ noteText }}</span>
      </section>

      <section v-if="role === 'employee'" class="dashboard-grid">
        <article class="dashboard-card dashboard-clock-card">
          <p class="dashboard-eyebrow">Today's clock</p>
          <strong class="dashboard-time">{{ currentTime }}</strong>
          <p>Recorded working time belongs to you.</p>
          <RouterLink class="dashboard-button" to="/directory">View my records</RouterLink>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <p class="dashboard-eyebrow">This week (Mon–Sun)</p>
          <div class="dashboard-metric-row">
            <strong v-if="!recordsError">{{ employeeHours }} h</strong>
            <strong v-else>—</strong>
            <span>recorded hours</span>
          </div>
          <div class="dashboard-progress"><span :style="{ width: `${employeeProgress}%` }"></span></div>
          <p>Recorded time, not a performance score.</p>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Recent time entries</h2>
          <p>Review your records and manage working-time entries.</p>
          <div v-if="recordsError" class="dashboard-error">{{ recordsError }}</div>
          <div v-else-if="records.length === 0" class="dashboard-empty">No working-time entries yet.</div>
          <div v-for="record in records.slice(0, 3)" :key="record.id" class="dashboard-row">
            <span>{{ formatDate(record.start) }}</span>
            <strong>{{ duration(record.start, record.end) }}</strong>
          </div>
        </article>
        <article class="dashboard-card dashboard-rhythm-card">
          <h2>Hours by day</h2>
          <p>Recorded time, not a performance score.</p>
          <div v-for="day in weekDays" :key="day.label" class="dashboard-bar-row">
            <span>{{ day.label }}</span>
            <div class="dashboard-bar-track"><span :style="{ width: `${day.percent}%` }"></span></div>
            <strong>{{ day.hours.toFixed(1) }} h</strong>
          </div>
        </article>
      </section>

      <section v-else-if="role === 'manager'" class="dashboard-grid">
        <article class="dashboard-card dashboard-metric-card">
          <p class="dashboard-eyebrow">Assigned teams</p>
          <strong class="dashboard-stat">{{ teams.length }}</strong>
          <span>Team groups in scope</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>Team snapshot</h2>
          <p>Review assigned members and recorded hours with context.</p>
          <div v-for="team in teams.slice(0, 4)" :key="team.id" class="team-snapshot-block">
            <div class="dashboard-row team-snapshot-header">
              <span>{{ team.name }}</span>
              <strong>{{ team.users.length }} member{{ team.users.length === 1 ? "" : "s" }}</strong>
            </div>
            <ul v-if="team.users.length > 0" class="team-snapshot-members">
              <li v-for="member in team.users" :key="member.id">
                <span class="team-snapshot-name">{{ member.username }}</span>
                <span class="team-snapshot-role">{{ member.role || "—" }}</span>
              </li>
            </ul>
            <p v-else class="team-snapshot-empty">No members yet.</p>
          </div>
        </article>
        <article class="dashboard-card dashboard-admin-card">
          <h2>Create a team</h2>
          <p>Managers can create teams for their own employees. You will be added as the first member.</p>
          <p v-if="adminMessage" class="dashboard-feedback">{{ adminMessage }}</p>
          <form class="dashboard-admin-form" @submit.prevent="createTeam">
            <label>Team name<input v-model="newTeamName" type="text" required placeholder="Team name"></label>
            <button class="dashboard-button" type="submit">Create team</button>
          </form>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Manage your teams</h2>
          <p>Add or remove members of the teams you belong to.</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Browse teams</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Review queue</h2>
          <p>Open the directory to inspect team records and exceptions.</p>
          <RouterLink class="dashboard-button" to="/directory">Open directory</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Needs attention</h2>
          <p>Prompts for review, not findings of misconduct.</p>
          <div class="dashboard-row"><span>Assigned members</span><strong>{{ managerMemberCount }}</strong></div>
          <div class="dashboard-row"><span>Review scope</span><strong>{{ teams.length }} teams</strong></div>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Correction requests</h2>
          <p>Review employee explanations and keep decisions traceable.</p>
          <div v-if="correctionRequests.length === 0" class="dashboard-empty">No pending requests.</div>
          <div v-for="request in correctionRequests" :key="request.id" class="dashboard-review-row">
            <div><strong>{{ request.reason }}</strong><span>Entry #{{ request.working_time_id }}</span></div>
            <div class="dashboard-review-actions">
              <button class="dashboard-mini-button" type="button" @click="reviewCorrection(request.id, 'approved')">Approve</button>
              <button class="dashboard-mini-button dashboard-mini-button-danger" type="button" @click="reviewCorrection(request.id, 'rejected')">Reject</button>
            </div>
          </div>
        </article>
      </section>

      <section v-else-if="role === 'hr_payroll'" class="dashboard-grid">
        <article class="dashboard-card dashboard-metric-card">
          <p class="dashboard-eyebrow">Approved reports</p>
          <strong class="dashboard-stat">{{ teams.length }}</strong>
          <span>Team scopes available</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>Time &amp; payroll categories</h2>
          <p>Keep recorded hours separate from pay calculations.</p>
          <div v-for="category in payrollCategories" :key="category.name" class="dashboard-row">
            <span>{{ category.name }}</span><strong>{{ category.status }}</strong>
          </div>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Audit and oversight</h2>
          <p>Reports remain access-scoped and traceable to approved records.</p>
          <RouterLink class="dashboard-button" to="/directory">Review records</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Organization teams</h2>
          <p>Browse all teams and members for reporting and auditing.</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Browse teams</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Correction requests</h2>
          <p>Review employee explanations and keep decisions traceable.</p>
          <div v-if="correctionRequests.length === 0" class="dashboard-empty">No pending requests.</div>
          <div v-for="request in correctionRequests" :key="request.id" class="dashboard-review-row">
            <div><strong>{{ request.reason }}</strong><span>Entry #{{ request.working_time_id }}</span></div>
            <div class="dashboard-review-actions">
              <button class="dashboard-mini-button" type="button" @click="reviewCorrection(request.id, 'approved')">Approve</button>
              <button class="dashboard-mini-button dashboard-mini-button-danger" type="button" @click="reviewCorrection(request.id, 'rejected')">Reject</button>
            </div>
          </div>
        </article>
      </section>

      <section v-else class="dashboard-grid">
        <article class="dashboard-card dashboard-metric-card">
          <p class="dashboard-eyebrow">Employees</p>
          <strong class="dashboard-stat">{{ userCount }}</strong>
          <span>Accounts in the system</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>Roles &amp; permissions</h2>
          <p>Predefined access is enforced by the API and visible here for governance.</p>
          <div v-for="availableRole in roles" :key="availableRole.id" class="dashboard-row">
            <span>{{ availableRole.name }}</span>
            <strong>Defined</strong>
          </div>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Teams and oversight</h2>
          <p>{{ teams.length }} teams currently exist. Membership changes are administrator-only.</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Browse teams</RouterLink>
        </article>
        <article class="dashboard-card dashboard-admin-card">
          <h2>Administrator controls</h2>
          <p>Manage predefined roles and create team groups from this protected workspace.</p>
          <p v-if="adminMessage" class="dashboard-feedback">{{ adminMessage }}</p>
          <form class="dashboard-admin-form" @submit.prevent="createTeam">
            <label>New team name<input v-model="newTeamName" type="text" required placeholder="Team name"></label>
            <button class="dashboard-button" type="submit">Create team</button>
          </form>
          <form class="dashboard-admin-form" @submit.prevent="changeRole">
            <label>User<select v-model="selectedUserId" required>
              <option disabled value="">Select user</option>
              <option v-for="user in users" :key="user.id" :value="user.id">{{ user.username }} ({{ user.email }})</option>
            </select></label>
            <label>Role<select v-model="selectedRole" required>
              <option v-for="availableRole in roles" :key="availableRole.id" :value="availableRole.name">{{ availableRole.name }}</option>
            </select></label>
            <button class="dashboard-button" type="submit">Save role</button>
          </form>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Reports and audit</h2>
          <p>System governance should explain who acted and when.</p>
          <div class="dashboard-row"><span>Role catalog</span><strong>{{ roles.length }} roles</strong></div>
          <div class="dashboard-row"><span>Team groups</span><strong>{{ teams.length }} teams</strong></div>
          <div class="dashboard-row"><span>Account changes</span><strong>Traceable</strong></div>
        </article>

        <!-- Shift configuration -->
        <article class="dashboard-card dashboard-records-card">
          <h2>Shift configuration</h2>
          <p>Set the shift for a user or a team. Users inherit from their team, or fall back to the default.</p>

          <div class="shift-config-targets">
            <button class="dashboard-button" type="button" @click="openUserShiftPicker">
              Configure a user's shift
            </button>
            <button class="dashboard-button" type="button" @click="openTeamShiftPicker">
              Configure a team's shift
            </button>
          </div>

          <p v-if="shiftFeedback" class="dashboard-feedback">{{ shiftFeedback }}</p>
        </article>
      </section>

      <section class="dashboard-password-card">
        <div>
          <p class="dashboard-eyebrow">Account security</p>
          <h2>Change password</h2>
          <p>Update your password without exposing it to the application.</p>
        </div>
        <form class="dashboard-password-form" @submit.prevent="changePassword">
          <input v-model="currentPassword" type="password" placeholder="Current password" autocomplete="current-password" required>
          <PasswordField
            v-model="newPassword"
            label="New password"
            input-id="dashboard-new-password"
            autocomplete="new-password"
          />
          <button class="dashboard-button" type="submit">Update password</button>
        </form>
        <p v-if="passwordMessage" class="dashboard-feedback">{{ passwordMessage }}</p>
      </section>

      <footer class="dashboard-footer">
        <span>Time Manager · access and responsibilities</span>
        <RouterLink to="/directory">Open directory</RouterLink>
      </footer>
    </main>

    <!-- Target picker -->
    <ShiftTargetPicker
      v-if="pickerMode"
      :mode="pickerMode"
      :users="users"
      :teams="teams"
      @close="onPickerCancelled"
      @selected="onPickerSelected"
    />

    <!-- Shift editor -->
    <ShiftEditorModal
      v-if="shiftTarget"
      :target="shiftTarget"
      @close="shiftTarget = null"
      @saved="onShiftSaved"
    />
  </AppLayout>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { apiFetch, authState, logout } from "../services/auth";
import { parseUtc } from "../utils/datetime";
import AppLayout from "../components/AppLayout.vue";
import PasswordField from "../components/PasswordField.vue";
import ShiftEditorModal from "../components/ShiftEditorModal.vue";
import ShiftTargetPicker from "../components/ShiftTargetPicker.vue";
import "./Dashboard.css";

// The dashboard reads the server-authorized role and never trusts a client-selected role.
const router = useRouter();
const role = computed(() => authState.user?.role || "employee");
const roleLabel = computed(() => role.value.replace("_", " "));
const roleIndex = computed(() => ({ employee: " ", manager: "02", hr_payroll: "03", administrator: "04" }[role.value] || "01"));
const heroTitle = computed(() => ({ employee: "Your time,", manager: "A clearer view of", hr_payroll: "Approved records,", administrator: "Clear rules for" }[role.value] || "Your workspace,"));
const heroAccent = computed(() => ({ employee: "clearly yours.", manager: "team time.", hr_payroll: "with context.", administrator: "time records." }[role.value] || "clearly yours."));
const heroDescription = computed(() => ({ employee: "A simple place to record your hours, review your records, and flag anything that needs a second look.", manager: "Plan coverage, review exceptions, and understand team records without checking every profile manually.", hr_payroll: "Review approved reports and time categories with a clear audit trail.", administrator: "Set fair access, approved categories, and accountable reporting across the system." }[role.value] || "A clear place to manage time."));
const heroTitleCharacters = computed(() => Array.from(heroTitle.value));
const heroAccentCharacters = computed(() => Array.from(heroAccent.value));
const heroDescriptionWords = computed(() => heroDescription.value.split(" "));
const noteTitle = computed(() => role.value === "employee" ? "A clear promise" : "Access and responsibility");
const noteText = computed(() => role.value === "employee" ? "Time Manager records working time, not every action on your computer." : "Access is scoped by role, ownership, and team membership.");
const currentTime = ref("--:--");
const records = ref([]);
const recordsError = ref("");
const teams = ref([]);
const roles = ref([]);
const users = ref([]);
const userCount = ref(0);
const newTeamName = ref("");
const selectedUserId = ref("");
const selectedRole = ref("");
const adminMessage = ref("");
const currentPassword = ref("");
const newPassword = ref("");
const passwordMessage = ref("");
const correctionRequests = ref([]);
const shiftTarget = ref(null);
const shiftFeedback = ref("");
const pickerMode = ref(null); // null | "user" | "team"

// Total hours worked in the current week (Monday 00:00 → Sunday 23:59:59
// in browser-local time). Uses the same UTC parsing as the rest of the app.
const employeeHours = computed(() => {
  const now = new Date();
  const day = now.getDay(); // 0 = Sunday, 1 = Monday, ...
  const daysFromMonday = day === 0 ? 6 : day - 1;
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysFromMonday);
  monday.setHours(0, 0, 0, 0);

  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 7);

  const totalMinutes = records.value.reduce((sum, record) => {
    const start = parseUtc(record.start);
    const end = parseUtc(record.end);
    if (!start || !end) return sum;
    if (start < monday || start >= sunday) return sum;
    return sum + Math.max(0, Math.floor((end.getTime() - start.getTime()) / 60000));
  }, 0);

  return (totalMinutes / 60).toFixed(1);
});
const employeeProgress = computed(() => Math.min(100, Math.round((Number(employeeHours.value) / 40) * 100)));
const weekDays = computed(() => {
  const labels = ["Mon", "Tue", "Wed", "Thu", "Fri"];
  return labels.map((label, index) => {
    const hours = records.value.reduce((total, record) => {
      const date = record.start ? new Date(record.start.replace(" ", "T")) : null;
      return date && date.getDay() === index + 1 ? total + durationHours(record.start, record.end) : total;
    }, 0);
    return { label, hours, percent: Math.min(100, Math.round((hours / 8) * 100)) };
  });
});
const managerMemberCount = computed(() => teams.value.reduce((total, team) => total + team.users.length, 0));
const payrollCategories = [
  { name: "Ordinary hours", status: "Standard category" },
  { name: "Night-shift hours", status: "Review policy" },
  { name: "Overtime", status: "Approval required" },
  { name: "Compensation time", status: "Approval required" }
];

onMounted(async () => {
  currentTime.value = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  const userId = authState.user?.id;

  if (role.value === "employee" && userId) {
    try {
      const response = await apiFetch(`/api/workingtime/${userId}`);
      if (!response.ok) {
        throw new Error(`Failed to load working times (${response.status})`);
      }
      const payload = await response.json();
      records.value = Array.isArray(payload) ? payload : (payload.data || []);
    } catch (err) {
      console.error(err);
      recordsError.value = err.message || "Unable to load working-time data.";
    }
  }

  if (role.value === "manager" || role.value === "administrator" || role.value === "hr_payroll") {
    const teamsResponse = await apiFetch("/api/teams");
    if (teamsResponse.ok) teams.value = await teamsResponse.json();

    const requestsResponse = await apiFetch("/api/reviews/correction-requests");
    if (requestsResponse.ok) correctionRequests.value = (await requestsResponse.json()).data || [];
  }

  if (role.value === "administrator") {
    const [usersResponse, rolesResponse] = await Promise.all([
      apiFetch("/api/users"),
      apiFetch("/api/roles")
    ]);
    if (usersResponse.ok) {
      users.value = await usersResponse.json();
      userCount.value = users.value.length;
    }
    if (rolesResponse.ok) {
      roles.value = await rolesResponse.json();
      selectedRole.value = roles.value[0]?.name || "";
    }
  }
});

// Create a team. The backend allows managers and administrators.
// Managers are auto-added; admins are not.
async function createTeam() {
  const response = await apiFetch("/api/teams", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: newTeamName.value })
  });

  const body = await response.json().catch(() => ({}));

  if (response.ok) {
    adminMessage.value = "Team created.";
    newTeamName.value = "";
    const teamsResponse = await apiFetch("/api/teams");
    if (teamsResponse.ok) teams.value = await teamsResponse.json();
  } else {
    const detail = body.errors
      ? Object.values(body.errors).flat().join(", ")
      : (body.error || "Unable to create team.");
    adminMessage.value = detail;
  }

  setTimeout(() => (adminMessage.value = ""), 3000);
}

// Promote or demote a user through the administrator-only role endpoint.
async function changeRole() {
  const response = await apiFetch(`/api/admin/users/${selectedUserId.value}/role`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ role: selectedRole.value })
  });

  adminMessage.value = response.ok ? "Role updated." : "Unable to update role.";
  if (response.ok) {
    const usersResponse = await apiFetch("/api/users");
    if (usersResponse.ok) users.value = await usersResponse.json();
  }
}

// Submit password changes through the CSRF-protected authentication endpoint.
async function changePassword() {
  const response = await apiFetch("/api/auth/password", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ current_password: currentPassword.value, new_password: newPassword.value })
  });

  passwordMessage.value = response.ok ? "Password updated." : "Unable to update password.";
  if (response.ok) {
    currentPassword.value = "";
    newPassword.value = "";
  }
}

// Reviewers approve or reject requests without exposing the JWT to the browser.
async function reviewCorrection(id, status) {
  const response = await apiFetch(`/api/reviews/correction-requests/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status })
  });

  if (response.ok) correctionRequests.value = correctionRequests.value.filter((request) => request.id !== id);
}

async function signOut() {
  await logout();
  await router.push({ name: "Login" });
}

// --- Shift configuration ---------------------------------------------------

function openUserShiftPicker() {
  pickerMode.value = "user";
  shiftFeedback.value = "";
}

function openTeamShiftPicker() {
  pickerMode.value = "team";
  shiftFeedback.value = "";
}

function onPickerSelected(item) {
  if (pickerMode.value === "user") {
    shiftTarget.value = {
      type: "user",
      id: item.id,
      label: `${item.label} (${item.sub})`
    };
  } else {
    shiftTarget.value = {
      type: "team",
      id: item.id,
      label: item.label
    };
  }
  pickerMode.value = null;
}

function onPickerCancelled() {
  pickerMode.value = null;
}

function onShiftSaved() {
  shiftTarget.value = null;
  shiftFeedback.value = "Shift saved.";
  setTimeout(() => {
    shiftFeedback.value = "";
  }, 2500);
}

function durationHours(start, end) {
  if (!start || !end) return 0;
  const milliseconds = new Date(end.replace(" ", "T")) - new Date(start.replace(" ", "T"));
  return milliseconds > 0 ? milliseconds / 3_600_000 : 0;
}

function duration(start, end) {
  const hours = durationHours(start, end);
  return `${hours.toFixed(1)} h`;
}

function formatDate(value) {
  return value ? new Date(value.replace(" ", "T")).toLocaleDateString() : "Unknown date";
}
</script>
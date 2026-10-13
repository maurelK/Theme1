<template>
  <AppLayout>
    <main class="dashboard-shell">
      <section class="dashboard-hero">
        <p class="dashboard-eyebrow">{{ roleLabel }}</p>
        <h1>Hello, <em>{{ firstName }}</em></h1>
        <p class="hero-description">{{ heroDescription }}</p>
      </section>

      <section class="dashboard-note">
        <strong>{{ noteTitle }}</strong>
        <span>{{ noteText }}</span>
      </section>

      <section v-if="role === 'employee'" class="dashboard-grid">
        <article class="dashboard-card dashboard-clock-card">
          <p class="dashboard-eyebrow">Current time</p>
          <strong class="dashboard-time">{{ currentTime }}</strong>
          <p>Clock in and out from My time.</p>
          <RouterLink class="dashboard-button" to="/my-time">Open my time</RouterLink>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <p class="dashboard-eyebrow">This week, Monday to Sunday</p>
          <div class="dashboard-metric-row">
            <strong v-if="!recordsError">{{ employeeHours }} h</strong>
            <strong v-else>-</strong>
            <span>of {{ WEEKLY_HOURS }} h</span>
          </div>
          <div
            class="dashboard-progress"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            :aria-valuenow="employeeProgress"
            :aria-label="`${employeeHours} of ${WEEKLY_HOURS} hours this week`"
          ><span :style="{ width: `${employeeProgress}%` }"></span></div>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Recent time entries</h2>
          <div v-if="recordsError" class="dashboard-error">{{ recordsError }}</div>
          <div v-else-if="recentRecords.length === 0" class="dashboard-empty">No working-time entries yet.</div>
          <div v-for="record in recentRecords" :key="record.id" class="dashboard-row">
            <span>{{ formatDate(record.start) }}</span>
            <strong>{{ duration(record.start, record.end) }}</strong>
          </div>
        </article>
        <article class="dashboard-card dashboard-rhythm-card">
          <h2>Hours by day this week</h2>
          <div v-for="day in weekDays" :key="day.label" class="dashboard-bar-row">
            <span>{{ day.label }}</span>
            <div class="dashboard-bar-track" aria-hidden="true"><span :style="{ width: `${day.percent}%` }"></span></div>
            <strong>{{ day.hours.toFixed(1) }} h</strong>
          </div>
        </article>
      </section>

      <section v-else-if="role === 'manager'" class="dashboard-grid">
        <article class="dashboard-card dashboard-metric-card">
          <p class="dashboard-eyebrow">Teams</p>
          <strong class="dashboard-stat">{{ teams.length }}</strong>
          <span>{{ managerMemberCount }} members in total</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>My teams</h2>
          <p v-if="teams.length === 0" class="dashboard-empty">No team assigned yet.</p>
          <div v-for="team in teams.slice(0, 4)" :key="team.id" class="team-snapshot-block">
            <div class="dashboard-row team-snapshot-header">
              <span>{{ team.name }}</span>
              <strong>{{ team.users.length }} member{{ team.users.length === 1 ? "" : "s" }}</strong>
            </div>
            <ul v-if="team.users.length > 0" class="team-snapshot-members">
              <li v-for="member in team.users" :key="member.id">
                <span class="team-snapshot-name">{{ member.username }}</span>
                <span class="team-snapshot-role">{{ formatRole(member.role) }}</span>
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
          <h2>Team members' hours</h2>
          <p>Open the directory to see an employee's working times and clock status.</p>
          <RouterLink class="dashboard-button" to="/directory">Open directory</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Correction requests</h2>
          <div v-if="correctionRequests.length === 0" class="dashboard-empty">No pending requests.</div>
          <div v-for="request in correctionRequests" :key="request.id" class="dashboard-review-row">
            <div>
              <strong>{{ request.requester_name || "Unknown employee" }}</strong>
              <span>Recorded: {{ formatRange(request.current_start, request.current_end) }}</span>
              <span v-if="request.proposed_start || request.proposed_end">Proposed: {{ formatRange(request.proposed_start || request.current_start, request.proposed_end || request.current_end) }}</span>
              <span>Reason: {{ request.reason }}</span>
            </div>
            <div class="dashboard-review-actions">
              <button class="dashboard-mini-button" type="button" @click="reviewCorrection(request.id, 'approved')">Approve</button>
              <button class="dashboard-mini-button dashboard-mini-button-danger" type="button" @click="reviewCorrection(request.id, 'rejected')">Reject</button>
            </div>
          </div>
        </article>
      </section>

      <section v-else-if="role === 'hr_payroll'" class="dashboard-grid">
        <article class="dashboard-card dashboard-metric-card">
          <p class="dashboard-eyebrow">Teams</p>
          <strong class="dashboard-stat">{{ teams.length }}</strong>
          <span>{{ managerMemberCount }} members in total</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>Working-time records</h2>
          <p>Open the directory to review an employee's entries and hours.</p>
          <RouterLink class="dashboard-button" to="/directory">Open directory</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Organization teams</h2>
          <p>Browse all teams and their members.</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Browse teams</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Correction requests</h2>
          <div v-if="correctionRequests.length === 0" class="dashboard-empty">No pending requests.</div>
          <div v-for="request in correctionRequests" :key="request.id" class="dashboard-review-row">
            <div>
              <strong>{{ request.requester_name || "Unknown employee" }}</strong>
              <span>Recorded: {{ formatRange(request.current_start, request.current_end) }}</span>
              <span v-if="request.proposed_start || request.proposed_end">Proposed: {{ formatRange(request.proposed_start || request.current_start, request.proposed_end || request.current_end) }}</span>
              <span>Reason: {{ request.reason }}</span>
            </div>
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
          <strong class="dashboard-stat">{{ employeeCount }}</strong>
          <span>{{ users.length }} accounts in total</span>
        </article>
        <article class="dashboard-card dashboard-wide-card">
          <h2>Accounts by role</h2>
          <div v-for="entry in accountsByRole" :key="entry.role" class="dashboard-row">
            <span>{{ formatRole(entry.role) }}</span>
            <strong>{{ entry.count }}</strong>
          </div>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Teams</h2>
          <p>{{ teams.length }} team{{ teams.length === 1 ? "" : "s" }}, {{ managerMemberCount }} members in total.</p>
          <RouterLink class="dashboard-button" to="/admin/teams">Browse teams</RouterLink>
        </article>
        <article class="dashboard-card dashboard-records-card">
          <h2>Administration</h2>
          <p>Invite users, change roles, create teams and set shifts.</p>
          <RouterLink class="dashboard-button" to="/admin">Open administration</RouterLink>
        </article>
      </section>

    </main>
  </AppLayout>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { apiFetch, authState } from "../services/auth";
import { formatRange, parseUtc } from "../utils/datetime";
import AppLayout from "../components/AppLayout.vue";
import { formatRole } from "../utils/roles";
import "./Dashboard.css";

// The dashboard reads the server-authorized role and never trusts a client-selected role.
const WEEKLY_HOURS = 40;
const DAILY_HOURS = 8;
const HERO_DESCRIPTIONS = {
  employee: "Your working hours this week and your latest entries.",
  manager: "Your teams, their members and pending correction requests.",
  hr_payroll: "Teams, working-time records and pending correction requests.",
  administrator: "Accounts, roles, teams and shifts across the organisation."
};

const role = computed(() => authState.user?.role || "employee");
const roleLabel = computed(() => formatRole(role.value));
const firstName = computed(() => (authState.user?.username || "").split(" ")[0]);
const heroDescription = computed(() => HERO_DESCRIPTIONS[role.value] || HERO_DESCRIPTIONS.employee);
// Tells employees exactly what is collected about them, as a guard against misuse.
const noteTitle = computed(() => role.value === "employee" ? "What is recorded" : "Your access");
const noteText = computed(() => role.value === "employee"
  ? "Only your clock-in and clock-out times. No other activity is tracked."
  : "You only see the people your role and teams give you access to.");
const currentTime = ref("--:--");
const records = ref([]);
const recordsError = ref("");
const teams = ref([]);
const users = ref([]);
const newTeamName = ref("");
const adminMessage = ref("");
const correctionRequests = ref([]);

// Entries started in the current week (Monday 00:00 to next Monday 00:00, browser-local time).
const thisWeekRecords = computed(() => {
  const now = new Date();
  const daysFromMonday = (now.getDay() + 6) % 7;
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysFromMonday);
  const nextMonday = new Date(monday);
  nextMonday.setDate(monday.getDate() + 7);

  return records.value.filter((record) => {
    const start = parseUtc(record.start);
    return start && start >= monday && start < nextMonday;
  });
});
const employeeHours = computed(() =>
  thisWeekRecords.value.reduce((total, record) => total + durationHours(record.start, record.end), 0).toFixed(1)
);
const employeeProgress = computed(() => Math.min(100, Math.round((Number(employeeHours.value) / WEEKLY_HOURS) * 100)));
const weekDays = computed(() => {
  const labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  return labels.map((label, index) => {
    const hours = thisWeekRecords.value.reduce((total, record) => {
      const day = (parseUtc(record.start).getDay() + 6) % 7;
      return day === index ? total + durationHours(record.start, record.end) : total;
    }, 0);
    return { label, hours, percent: Math.min(100, Math.round((hours / DAILY_HOURS) * 100)) };
  });
});
const recentRecords = computed(() =>
  [...records.value]
    .sort((a, b) => (parseUtc(b.start)?.getTime() || 0) - (parseUtc(a.start)?.getTime() || 0))
    .slice(0, 3)
);
const managerMemberCount = computed(() => teams.value.reduce((total, team) => total + team.users.length, 0));
const employeeCount = computed(() => users.value.filter((user) => user.role === "employee").length);
const accountsByRole = computed(() => {
  const counts = {};
  for (const user of users.value) {
    const key = user.role || "none";
    counts[key] = (counts[key] || 0) + 1;
  }
  return Object.entries(counts).map(([role, count]) => ({ role, count }));
});

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
    const usersResponse = await apiFetch("/api/users");
    if (usersResponse.ok) users.value = await usersResponse.json();
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

// Reviewers approve or reject requests without exposing the JWT to the browser.
async function reviewCorrection(id, status) {
  const response = await apiFetch(`/api/reviews/correction-requests/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status })
  });

  if (response.ok) correctionRequests.value = correctionRequests.value.filter((request) => request.id !== id);
}

// Open entries (no end yet) count as zero until they are closed.
function durationHours(start, end) {
  const startDate = parseUtc(start);
  const endDate = parseUtc(end);
  if (!startDate || !endDate) return 0;
  const milliseconds = endDate - startDate;
  return milliseconds > 0 ? milliseconds / 3_600_000 : 0;
}

function duration(start, end) {
  return parseUtc(end) ? `${durationHours(start, end).toFixed(1)} h` : "In progress";
}

function formatDate(value) {
  const date = parseUtc(value);
  return date ? date.toLocaleDateString() : "Unknown date";
}
</script>
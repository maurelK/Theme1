<template>
  <AppLayout>
    <main class="page-shell my-team">
      <header class="my-team-header">
        <p class="eyebrow">My team</p>
        <h2>Who you work with</h2>
        <p class="my-team-intro">
          Contact your manager for absences or questions about your hours.
          Colleagues cannot see your hours, and you cannot see theirs.
        </p>
      </header>

      <p v-if="loading" class="my-team-status">Loading your teams...</p>
      <p v-else-if="error" class="my-team-status my-team-error" role="alert">{{ error }}</p>
      <p v-else-if="teams.length === 0" class="my-team-status">
        You are not in a team yet. Your manager or the general manager can add you to one.
      </p>

      <article v-for="team in teams" :key="team.id" class="my-team-card" :aria-labelledby="`team-${team.id}`">
        <h3 :id="`team-${team.id}`">{{ team.name }}</h3>

        <section class="my-team-managers" :aria-label="`Managers of ${team.name}`">
          <p class="my-team-label">{{ managersOf(team).length > 1 ? "Managers" : "Manager" }}</p>
          <p v-if="managersOf(team).length === 0" class="my-team-status">No manager assigned to this team.</p>
          <ul v-else>
            <li v-for="manager in managersOf(team)" :key="manager.id" class="my-team-manager">
              <span class="my-team-avatar" aria-hidden="true">{{ initials(manager.username) }}</span>
              <div>
                <p class="my-team-name">{{ manager.username }}</p>
                <a :href="`mailto:${manager.email}`" class="my-team-email">{{ manager.email }}</a>
              </div>
            </li>
          </ul>
        </section>

        <section :aria-label="`Colleagues in ${team.name}`">
          <p class="my-team-label">Colleagues ({{ colleaguesOf(team).length }})</p>
          <p v-if="colleaguesOf(team).length === 0" class="my-team-status">No other members yet.</p>
          <ul v-else class="my-team-colleagues">
            <li v-for="member in colleaguesOf(team)" :key="member.id">
              <span>{{ member.username }}</span>
              <span class="my-team-role">{{ formatRole(member.role) }}</span>
            </li>
          </ul>
        </section>
      </article>
    </main>
  </AppLayout>
</template>

<script setup>
import { onMounted, ref } from "vue";
import { apiFetch, authState } from "../services/auth";
import { formatRole } from "../utils/roles";
import AppLayout from "../components/AppLayout.vue";

// Roles that supervise a team; shown apart with their contact email.
const SUPERVISOR_ROLES = ["manager", "administrator"];

const teams = ref([]);
const loading = ref(true);
const error = ref("");

onMounted(async () => {
  try {
    // The API only returns the teams the caller belongs to.
    const response = await apiFetch("/api/teams");
    if (!response.ok) throw new Error("Unable to load your teams.");
    teams.value = await response.json();
  } catch (err) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
});

function others(team) {
  return (team.users || []).filter((member) => member.id !== authState.user?.id);
}

function managersOf(team) {
  return others(team).filter((member) => SUPERVISOR_ROLES.includes(member.role));
}

function colleaguesOf(team) {
  return others(team).filter((member) => !SUPERVISOR_ROLES.includes(member.role));
}

function initials(name = "") {
  const parts = name.trim().split(/\s+/);
  return ((parts[0]?.[0] || "") + (parts[1]?.[0] || "")).toUpperCase() || "?";
}
</script>

<style src="../components/User.css"></style>

<style scoped>
.my-team { display: grid; gap: 24px; }
.my-team-header h2 { margin-bottom: 8px; }
.my-team-intro { max-width: 640px; margin: 0; color: #4f5d58; font-size: 14px; line-height: 1.6; }
.my-team-status { margin: 0; color: #4f5d58; font-size: 14px; }
.my-team-error { color: #a33b2b; }
.my-team-card { display: grid; gap: 20px; padding: 24px; border: 1px solid #d4d6cc; background: #fffdf7; }
.my-team-card h3 { margin: 0; color: #243332; font-size: 20px; }
.my-team-card ul { display: grid; gap: 10px; margin: 0; padding: 0; list-style: none; }
.my-team-label { margin: 0 0 10px; color: #4f5d58; font-size: 13px; font-weight: 700; }
.my-team-manager { display: flex; gap: 14px; align-items: center; padding: 14px; background: #e4e7de; }
.my-team-avatar {
  display: grid;
  place-items: center;
  flex: none;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #263836;
  color: #fffdf7;
  font-weight: 700;
}
.my-team-name { margin: 0; color: #243332; font-size: 15px; font-weight: 700; }
.my-team-email { color: #1f6b66; font-size: 14px; word-break: break-all; }
.my-team-colleagues li {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid #e4e7de;
  color: #243332;
  font-size: 14px;
}
.my-team-role { color: #4f5d58; }
</style>

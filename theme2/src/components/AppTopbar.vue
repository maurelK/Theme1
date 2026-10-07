<template>
  <header class="app-topbar">
    <div class="app-topbar-inner">
      <RouterLink class="app-brand" to="/" aria-label="Time Manager home">
        <span class="app-brand-mark">t</span>
        <span>timemanager</span>
      </RouterLink>

      <!-- Desktop inline nav -->
      <nav class="app-nav-desktop" aria-label="Primary">
        <RouterLink
          v-for="link in navLinks"
          :key="link.to"
          :to="link.to"
          class="app-nav-link"
          active-class="app-nav-link-active"
        >
          {{ link.label }}
        </RouterLink>
      </nav>

      <!-- Desktop actions -->
      <div class="app-actions">
        <span class="app-role">
          {{ roleLabel }} workspace <span class="status-dot"></span>
        </span>
        <button class="app-signout" type="button" @click="signOut">Sign out</button>
      </div>
    </div>
  </header>
</template>

<script setup>
import { computed } from "vue";
import { useRouter } from "vue-router";
import { authState, logout } from "../services/auth";

const router = useRouter();

const roleLabel = computed(() => (authState.user?.role || "workspace").replace("_", " "));

// Administrators see "Workspace"; everyone else sees "Overview".
const dashboardLabel = computed(() =>
  authState.user?.role === "administrator" ? "Workspace" : "Overview"
);

// Employees see "Profile" (their own); other roles see "Directory".
const directoryLabel = computed(() =>
  authState.user?.role === "employee" ? "Profile" : "Directory"
);

const navLinks = computed(() => [
  { label: dashboardLabel.value, to: "/" },
  { label: directoryLabel.value, to: "/directory" }
]);

async function signOut() {
  await logout();
  await router.push({ name: "Login" });
}
</script>

<style scoped>
.app-topbar {
  background: var(--color-bg);
  border-bottom: 1px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 20;
}

.app-topbar-inner {
  max-width: var(--content-max);
  margin: 0 auto;
  padding: 14px var(--content-padding);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  min-height: 56px;
}

.app-brand {
  display: flex;
  align-items: center;
  gap: 9px;
  color: var(--color-ink);
  font: 700 19px var(--font-body);
  letter-spacing: -.07em;
  text-decoration: none;
  text-transform: lowercase;
}

.app-brand-mark {
  display: grid;
  place-items: center;
  width: 29px;
  height: 29px;
  background: #e5a35a;
  border-radius: 50%;
  color: var(--color-surface);
  font: 500 15px Georgia, serif;
  letter-spacing: 0;
}

.app-nav-desktop {
  display: flex;
  gap: 22px;
  align-items: center;
  flex: 1;
  justify-content: center;
}

.app-nav-link {
  color: var(--color-ink-soft);
  font: 500 12px var(--font-mono);
  letter-spacing: .12em;
  text-transform: uppercase;
  text-decoration: none;
  padding: 10px 4px;
  border-bottom: 1px solid transparent;
  transition: color .2s, border-color .2s;
}

.app-nav-link:hover {
  color: var(--color-ink);
}

.app-nav-link-active {
  color: var(--color-ink);
  border-bottom-color: var(--color-accent);
}

.app-actions {
  display: flex;
  gap: 18px;
  align-items: center;
}

.app-role {
  color: var(--color-ink-soft);
  font: 10px var(--font-mono);
  letter-spacing: .12em;
  text-transform: uppercase;
}

.status-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  margin-left: 7px;
  border-radius: 50%;
  background: var(--color-positive);
  box-shadow: 0 0 0 3px #dce9d9;
}

.app-signout {
  border: 0;
  padding: 10px 6px;
  background: transparent;
  color: var(--color-accent-soft);
  cursor: pointer;
  font-size: 12px;
  text-decoration: underline;
  text-underline-offset: 4px;
  min-height: var(--tap-min);
}

/* Mobile: hide inline nav and desktop actions — bottom bar takes over. */
@media (max-width: 900px) {
  .app-nav-desktop,
  .app-actions {
    display: none;
  }
}
</style>
<template>
  <nav class="app-bottom-nav" aria-label="Primary mobile">
    <RouterLink
      v-for="link in navLinks"
      :key="link.to"
      :to="link.to"
      class="app-bottom-link"
      active-class="app-bottom-link-active"
    >
      <span class="app-bottom-icon" v-html="link.icon"></span>
      <span class="app-bottom-label">{{ link.label }}</span>
    </RouterLink>

    <button class="app-bottom-link app-bottom-signout" type="button" @click="signOut">
      <span class="app-bottom-icon" v-html="signOutIcon"></span>
      <span class="app-bottom-label">Sign out</span>
    </button>
  </nav>
</template>

<script setup>
import { computed } from "vue";
import { useRouter } from "vue-router";
import { authState, logout } from "../services/auth";

const router = useRouter();

// Administrators see "Workspace"; everyone else sees "Overview".
const dashboardLabel = computed(() =>
  authState.user?.role === "administrator" ? "Workspace" : "Overview"
);

// Employees see "Profile"; other roles see "Directory".
const directoryLabel = computed(() =>
  authState.user?.role === "employee" ? "Profile" : "Directory"
);

const navLinks = computed(() => [
  {
    label: dashboardLabel.value,
    to: "/",
    icon: `
      <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M3 10.2 12 3l9 7.2V20a1.5 1.5 0 0 1-1.5 1.5h-4.75V14.5h-5.5v7H4.5A1.5 1.5 0 0 1 3 20V10.2Z"/>
      </svg>
    `
  },
  {
    label: directoryLabel.value,
    to: "/directory",
    icon: `
      <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M4 4.5A1.5 1.5 0 0 1 5.5 3h5A1.5 1.5 0 0 1 12 4.5v15A1.5 1.5 0 0 1 10.5 21h-5A1.5 1.5 0 0 1 4 19.5v-15Zm10 3A1.5 1.5 0 0 1 15.5 6h3A1.5 1.5 0 0 1 20 7.5v12a1.5 1.5 0 0 1-1.5 1.5h-3a1.5 1.5 0 0 1-1.5-1.5v-12Z"/>
      </svg>
    `
  }
]);

const signOutIcon = `
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M10 3.5a1 1 0 0 1 1 1v9a1 1 0 1 1-2 0v-9a1 1 0 0 1 1-1Zm-4.6 2.3a1 1 0 0 1 .1 1.4A6 6 0 1 0 12 18a6 6 0 0 0 4.5-2.1 1 1 0 1 1 1.5 1.3A8 8 0 1 1 5.3 6.3a1 1 0 0 1 1.4-.1l.7.6Z"/>
  </svg>
`;

async function signOut() {
  await logout();
  await router.push({ name: "Login" });
}
</script>

<style scoped>
.app-bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 30;
  display: none;
  background: var(--color-surface);
  border-top: 1px solid var(--color-border);
  border-top-left-radius: 18px;
  border-top-right-radius: 18px;
  box-shadow: 0 -6px 24px rgba(36, 51, 50, .08);
  padding: 6px 6px calc(6px + env(safe-area-inset-bottom, 0px));
  grid-template-columns: repeat(3, 1fr);
}

.app-bottom-link {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  padding: 10px 6px;
  min-height: 56px;
  border: 0;
  background: transparent;
  color: var(--color-ink-soft);
  font: 500 10px var(--font-mono);
  letter-spacing: .08em;
  text-transform: uppercase;
  text-decoration: none;
  cursor: pointer;
  border-radius: 12px;
  transition: color .2s, background .2s;
}

.app-bottom-icon {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
}

.app-bottom-icon svg {
  width: 100%;
  height: 100%;
  opacity: .78;
}

.app-bottom-link-active {
  color: var(--color-accent);
  background: rgba(181, 104, 75, .10);
}

.app-bottom-link-active .app-bottom-icon svg {
  opacity: 1;
}

.app-bottom-signout {
  color: var(--color-accent-soft);
}

.app-bottom-signout:hover {
  background: rgba(163, 97, 74, .08);
}

@media (max-width: 900px) {
  .app-bottom-nav {
    display: grid;
  }
}
</style>
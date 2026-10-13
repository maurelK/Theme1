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
import { ICONS, navLinksFor } from "../utils/navigation";

const router = useRouter();

const navLinks = computed(() => navLinksFor(authState.user?.role));
const signOutIcon = ICONS.signOut;

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
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
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
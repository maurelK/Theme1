<template>
  <div class="picker-backdrop" @click.self="$emit('close')">
    <div class="picker-modal" role="dialog" aria-modal="true" aria-labelledby="picker-title">
      <header class="picker-header">
        <div>
          <p class="eyebrow">Select target</p>
          <h2 id="picker-title">{{ mode === "user" ? "Choose a user" : "Choose a team" }}</h2>
        </div>
        <button class="picker-close" type="button" aria-label="Close" @click="$emit('close')">×</button>
      </header>

      <input
        v-model="query"
        class="picker-search"
        type="text"
        :placeholder="mode === 'user' ? 'Search by name or email' : 'Search teams'"
        autofocus
      />

      <ul class="picker-list">
        <li v-if="filtered.length === 0" class="picker-empty">
          No matches.
        </li>
        <li v-for="item in filtered" :key="item.id">
          <button type="button" class="picker-item" @click="pick(item)">
            <span class="picker-primary">{{ item.label }}</span>
            <span v-if="item.sub" class="picker-secondary">{{ item.sub }}</span>
          </button>
        </li>
      </ul>

      <footer class="picker-footer">
        <button type="button" class="btn-wt btn-outline" @click="$emit('close')">Cancel</button>
      </footer>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from "vue";

const props = defineProps({
  mode: { type: String, required: true }, // "user" | "team"
  users: { type: Array, default: () => [] },
  teams: { type: Array, default: () => [] }
});

const emit = defineEmits(["close", "selected"]);

const query = ref("");

// Normalize both sources into a common shape: { id, label, sub }
const items = computed(() => {
  if (props.mode === "user") {
    return props.users.map((u) => ({
      id: u.id,
      label: u.username || `User #${u.id}`,
      sub: u.email || ""
    }));
  }
  return props.teams.map((t) => ({
    id: t.id,
    label: t.name || `Team #${t.id}`,
    sub: `${t.users?.length ?? 0} members`
  }));
});

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase();
  if (!q) return items.value;
  return items.value.filter(
    (item) =>
      item.label.toLowerCase().includes(q) ||
      (item.sub && item.sub.toLowerCase().includes(q))
  );
});

function pick(item) {
  emit("selected", item);
}
</script>

<style scoped>
.picker-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(36, 51, 50, 0.55);
  display: grid;
  place-items: center;
  z-index: 60;
  padding: 20px;
  overflow-y: auto;
}

.picker-modal {
  width: 100%;
  max-width: 480px;
  background: #fffdf7;
  border: 1px solid #d4d6cc;
  padding: 24px;
  display: grid;
  gap: 16px;
  box-shadow: 0 20px 60px rgba(36, 51, 50, 0.25);
  max-height: 80vh;
}

.picker-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.picker-header h2 {
  margin: 0;
  font: 600 20px "Manrope", sans-serif;
  letter-spacing: -0.03em;
  color: #243332;
}

.picker-close {
  border: 0;
  background: transparent;
  color: #71807a;
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
}

.picker-search {
  width: 100%;
  border: 0;
  border-bottom: 1px solid #bcc4b8;
  background: transparent;
  color: #263836;
  padding: 10px 0;
  font: 14px "Manrope", sans-serif;
  outline: 0;
}

.picker-search:focus {
  border-color: #bd684c;
  box-shadow: 0 2px 0 #bd684c;
}

.picker-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0;
  overflow-y: auto;
  max-height: 50vh;
  border-top: 1px solid #d4d6cc;
}

.picker-empty {
  padding: 20px 0;
  color: #71807a;
  font-size: 13px;
  text-align: center;
}

.picker-item {
  width: 100%;
  text-align: left;
  border: 0;
  border-bottom: 1px solid #e4e7de;
  background: transparent;
  cursor: pointer;
  padding: 14px 6px;
  display: grid;
  gap: 3px;
  transition: background 0.15s;
}

.picker-item:hover {
  background: #f3f0e9;
}

.picker-primary {
  color: #243332;
  font-size: 14px;
  font-weight: 600;
}

.picker-secondary {
  color: #71807a;
  font-size: 12px;
}

.picker-footer {
  display: flex;
  justify-content: flex-end;
}
</style>
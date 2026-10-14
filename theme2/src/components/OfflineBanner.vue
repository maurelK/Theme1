<template>
  <div v-if="!online || pending > 0 || rejected.length || authState.sessionWarning" class="offline-banner" role="status">
    <p v-if="authState.sessionWarning">{{ authState.sessionWarning }}</p>
    <p v-if="!online">
      <strong>Offline.</strong> You are seeing the data last saved on this device.
      Actions marked "works offline" are kept and sent when the connection returns.
    </p>
    <p v-if="pending > 0">
      {{ syncing ? "Sending" : "Waiting to send" }} {{ pending }} action{{ pending === 1 ? "" : "s" }} saved on this device.
    </p>
    <ul v-if="rejected.length" class="offline-rejected" role="alert">
      <li v-for="item in rejected" :key="item.id">
        <span>"{{ item.label }}" made offline was refused: {{ item.message }}</span>
        <button type="button" @click="dismiss(item.id)">Dismiss</button>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { network } from "../platform/network";
import { authState } from "../services/auth";
import { outbox } from "../data/outbox";
import { sync } from "../data/sync";

const online = network.online;
const pending = outbox.pending;
const syncing = sync.syncing;
const rejected = sync.rejected;
const dismiss = sync.dismissRejected;
</script>

<style scoped>
.offline-banner {
  display: grid;
  gap: 6px;
  margin: 12px 0 0;
  padding: 10px 14px;
  border: 1px solid #8a5a00;
  background: #fff4dc;
  color: #5c3d00;
  font-size: 14px;
}
.offline-banner p { margin: 0; }
.offline-rejected { display: grid; gap: 6px; margin: 0; padding: 0; list-style: none; }
.offline-rejected li {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  color: #7a2a1e;
}
.offline-rejected button { border: 0; background: none; color: inherit; font-weight: 700; text-decoration: underline; cursor: pointer; }
</style>

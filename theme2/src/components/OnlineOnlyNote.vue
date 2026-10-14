<template>
  <!-- Shown under actions that must not run on possibly outdated offline data. -->
  <p v-if="!online" class="online-only-note" role="note">Connection required for this action.</p>
</template>

<script setup>
import { network } from "../platform/network";

const online = network.online;
</script>

<style scoped>
.online-only-note {
  margin: 8px 0 0;
  color: #5c3d00;
  font-size: 13px;
  font-weight: 600;
}
</style>

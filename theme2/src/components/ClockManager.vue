<template>
  <component :is="layout">
    <main class="clock-manager-shell">
      <Clock :userId="targetUserId" />
    </main>
  </component>
</template>

<script>
import Clock from "./Clock.vue";
import AppLayout from "./AppLayout.vue";

export default {
  name: "ClockManager",

  components: {
    Clock,
    AppLayout
  },

  props: {
    userId: {
      type: [Number, String],
      default: null
    }
  },

  computed: {
    layout() {
      return this.$route.name === "ClockManager" ? "AppLayout" : "div";
    },
    
    targetUserId() {
      const u = this.userId;
      if (u !== null && u !== undefined && u !== "null" && u !== "undefined" && u !== "") {
        return u;
      }
      return this.$route && this.$route.params
        ? (this.$route.params.userid || this.$route.params.userID || 1)
        : 1;
    }
  }
};
</script>

<style scoped>
.clock-manager-shell {
  max-width: var(--content-max, 1240px);
  margin: 0 auto;
  padding: 0 var(--content-padding, 24px) 60px;
}
</style>
// Reactive connectivity. Mobile: cordova-plugin-network-information; web: navigator.onLine.
// "Online" only means a network is available: the server may still be
// unreachable, so callers must also handle failed requests.

import { readonly, ref } from "vue";

const online = ref(detect());
const listeners = new Set();

function detect() {
  if (typeof navigator === "undefined") return true;
  const connection = navigator.connection;
  if (connection && typeof window.Connection !== "undefined") {
    return connection.type !== window.Connection.NONE;
  }
  return navigator.onLine !== false;
}

function update() {
  const wasOnline = online.value;
  online.value = detect();
  if (!wasOnline && online.value) listeners.forEach((listener) => listener());
}

if (typeof document !== "undefined") {
  // Cordova fires these on `document`, browsers on `window`.
  for (const target of [document, window]) {
    target.addEventListener("online", update);
    target.addEventListener("offline", update);
  }
}

export const network = {
  online: readonly(online),

  isOnline() {
    online.value = detect();
    return online.value;
  },

  // Called each time the connection comes back. Returns an unsubscribe function.
  onReconnect(listener) {
    listeners.add(listener);
    return () => listeners.delete(listener);
  }
};

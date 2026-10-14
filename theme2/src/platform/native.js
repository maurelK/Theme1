// Native dialogs through cordova-plugin-dialogs, with browser fallbacks.

// Resolves true when the user picks the confirm button.
export function confirmDialog(message, { title = "Time Manager", confirmLabel = "OK", cancelLabel = "Cancel" } = {}) {
  const notification = typeof navigator !== "undefined" ? navigator.notification : undefined;
  if (!notification?.confirm) return Promise.resolve(window.confirm(message));

  return new Promise((resolve) => {
    // Buttons are 1-based; 0 means the dialog was dismissed.
    notification.confirm(message, (index) => resolve(index === 1), title, [confirmLabel, cancelLabel]);
  });
}

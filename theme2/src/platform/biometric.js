// Local unlock with fingerprint/face, falling back to the phone's PIN or pattern,
// via cordova-plugin-fingerprint-aio. Android performs the check in its secure
// hardware; the app only receives "unlocked" or "not unlocked".
//
// This proves to the phone that its owner is present. It does not prove the
// identity to the server: the server checks the token on every request.

function plugin() {
  return typeof window !== "undefined" ? window.Fingerprint : undefined;
}

function isAvailable() {
  return new Promise((resolve) => {
    const fingerprint = plugin();
    if (!fingerprint) return resolve(false);
    fingerprint.isAvailable(() => resolve(true), () => resolve(false));
  });
}

export const biometric = {
  // Resolves true when the user unlocked, false when they cancelled or failed.
  // Without biometrics enrolled or without the plugin, there is nothing to
  // unlock with: the Keystore already requires a secured phone, so we allow it.
  async unlock() {
    if (!(await isAvailable())) return true;

    return new Promise((resolve) => {
      plugin().show(
        {
          title: "Unlock Time Manager",
          description: "Confirm it is you to open your session",
          // Offer the phone's PIN/pattern when the fingerprint is not recognised.
          disableBackup: false
        },
        () => resolve(true),
        () => resolve(false)
      );
    });
  }
};

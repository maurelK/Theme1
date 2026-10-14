// Encrypted storage for secrets (JWT, refresh token), backed by the Android
// Keystore through cordova-plugin-secure-storage-echo.
//
// The plugin refuses to work on a phone without a screen lock. In that case,
// and on the web, secrets are kept in memory only: the session then lasts as
// long as the app is open and the user signs in again after a restart. We
// never fall back to unencrypted storage.

const NAMESPACE = "timemanager";

let storagePromise = null;
const memory = new Map();

function openStorage() {
  storagePromise ||= new Promise((resolve) => {
    const SecureStorage = typeof window !== "undefined" && window.cordova?.plugins?.SecureStorage;
    if (!SecureStorage) return resolve(null);
    const storage = new SecureStorage(
      () => resolve(storage),
      (error) => {
        console.warn("Secure storage unavailable (no screen lock?):", error);
        resolve(null);
      },
      NAMESPACE
    );
  });
  return storagePromise;
}

export const secureStore = {
  async get(key) {
    const storage = await openStorage();
    if (!storage) return memory.get(key) ?? null;
    // The plugin rejects missing keys: treat that as "no value".
    return new Promise((resolve) => storage.get(resolve, () => resolve(null), key));
  },

  async set(key, value) {
    const storage = await openStorage();
    if (!storage) {
      memory.set(key, value);
      return;
    }
    await new Promise((resolve, reject) => storage.set(resolve, reject, key, value));
  },

  async remove(key) {
    memory.delete(key);
    const storage = await openStorage();
    if (!storage) return;
    await new Promise((resolve) => storage.remove(resolve, resolve, key));
  },

  // True when secrets survive an app restart (Keystore available).
  async isPersistent() {
    return Boolean(await openStorage());
  }
};

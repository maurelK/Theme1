import { reactive } from "vue";
import { notifyError } from "./feedback";
import { isMobileApp } from "../utils/platform";
import { localDb } from "../platform/localDb";
import { secureStore } from "../platform/secureStore";
import { biometric } from "../platform/biometric";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

// Two session models share this module:
//  * Web: the JWT lives in an HttpOnly cookie; requests carry the CSRF token.
//  * Mobile: the WebView never sends that cross-site cookie. The app holds a
//    1-hour JWT (Authorization: Bearer) and a revocable 7-day refresh token,
//    both encrypted in the Android Keystore. The first sign-in needs the
//    network; later launches unlock the stored session with the fingerprint or
//    phone PIN and work offline for up to 7 days. The password is never stored.
const isMobile = isMobileApp;

const ACCESS_TOKEN_KEY = "accessToken";
const REFRESH_TOKEN_KEY = "refreshToken";
// { user, lastOnlineCheck }: lets the app open offline with the right pages.
const PROFILE_KEY = "profile";
// Kept after sign-out, to detect that a different person signs in on this phone.
const LAST_USER_KEY = "lastUserId";
// Per-user caches cleared when another person signs in (outbox items stay, tagged by user).
const USER_CACHE_PREFIXES = ["clock:", "cache:"];
// Same lifetime as the refresh token on the server (Theme1.RefreshTokens).
export const MAX_OFFLINE_MS = 7 * 24 * 3600 * 1000;

const SESSION_EXPIRED = "Your session has expired. Please sign in again.";
const OFFLINE_TOO_LONG = "You have been offline for more than 7 days. Connect to the internet and sign in again.";

// Paths that must not trigger a token refresh or carry the CSRF header.
const AUTH_PATHS = new Set(["/api/auth/login", "/api/auth/refresh", "/api/auth/revoke", "/api/auth/csrf"]);

const tokens = { access: null, refresh: null };
let refreshing = null;

// Safe session data only. `locked`: a session exists on the phone but was not
// unlocked yet. `restoredOffline`: opened from the device without the server.
// `notice`: why the user is back on the sign-in screen.
export const authState = reactive({
  user: null,
  csrfToken: null,
  initialized: false,
  restoredOffline: false,
  locked: false,
  notice: ""
});

// `silent: true` skips the error sound, for background calls that may fail offline.
export async function apiFetch(path, { silent = false, retried = false, ...options } = {}) {
  const headers = new Headers(options.headers || {});

  if (isMobile) {
    if (tokens.access) headers.set("Authorization", `Bearer ${tokens.access}`);
  } else if (!AUTH_PATHS.has(path) && authState.csrfToken) {
    headers.set("X-CSRF-Token", authState.csrfToken);
  }

  const cacheable = isCachedRead(path, options);

  let response;
  try {
    response = await fetch(API_BASE + path, {
      ...options,
      credentials: isMobile ? "omit" : "include",
      headers
    });
  } catch (error) {
    // Offline: answer reads with the last response saved on the phone.
    const cached = cacheable && (await readCachedResponse(path));
    if (cached) return cached;
    if (!silent) notifyError();
    throw error;
  }

  // Mobile JWTs last one hour: renew silently, then replay the request once.
  if (isMobile && response.status === 401 && !retried && !AUTH_PATHS.has(path) && tokens.refresh) {
    if (await refreshTokens()) return apiFetch(path, { silent, retried: true, ...options });
  }

  if (cacheable && response.ok) await saveCachedResponse(path, response.clone());
  return response;
}

// ---------------------------------------------------------------------------
// Offline reads (mobile): every successful GET is kept per user, so pages show
// the last known data without network. Only what the user's role could fetch
// is stored, and another user's sign-in clears it.
// ---------------------------------------------------------------------------

const READ_CACHE_PREFIX = "cache:";
const CACHED_AT_HEADER = "X-Cached-At";

function isCachedRead(path, options) {
  const method = (options.method || "GET").toUpperCase();
  return isMobile && method === "GET" && !AUTH_PATHS.has(path) && Boolean(authState.user);
}

const readCacheKey = (path) => `${READ_CACHE_PREFIX}${authState.user.id}:${path}`;

async function saveCachedResponse(path, response) {
  try {
    await localDb.set(readCacheKey(path), { status: response.status, body: await response.text(), at: Date.now() });
  } catch {
    // Caching is best effort.
  }
}

async function readCachedResponse(path) {
  const entry = await localDb.get(readCacheKey(path));
  if (!entry) return null;
  return new Response(entry.body, {
    status: entry.status,
    headers: { "Content-Type": "application/json", [CACHED_AT_HEADER]: String(entry.at) }
  });
}

// When a response came from the phone's cache, the time it was saved (ms), else null.
export function cachedAt(response) {
  const value = response?.headers?.get(CACHED_AT_HEADER);
  return value ? Number(value) : null;
}

// ---------------------------------------------------------------------------
// Mobile session
// ---------------------------------------------------------------------------

async function saveProfile(user) {
  await localDb.set(PROFILE_KEY, { user, lastOnlineCheck: Date.now() });
}

async function storeMobileSession({ user, token, refresh_token: refreshToken }) {
  tokens.access = token;
  tokens.refresh = refreshToken;
  await Promise.all([secureStore.set(ACCESS_TOKEN_KEY, token), secureStore.set(REFRESH_TOKEN_KEY, refreshToken)]);
  authState.user = user;
  authState.restoredOffline = false;
  authState.locked = false;
  authState.notice = "";
  await saveProfile(user);
}

// Back to the sign-in screen. Queued actions stay in the outbox and are sent
// after the same user signs in again.
async function endMobileSession(notice) {
  tokens.access = null;
  tokens.refresh = null;
  await Promise.all([secureStore.remove(ACCESS_TOKEN_KEY), secureStore.remove(REFRESH_TOKEN_KEY), localDb.remove(PROFILE_KEY)]);
  authState.user = null;
  authState.restoredOffline = false;
  authState.locked = false;
  authState.notice = notice;
}

// Exchange the refresh token for a new pair. One request at a time: parallel
// 401s wait for the same refresh. Throws when the server is unreachable.
function refreshTokens() {
  refreshing ||= (async () => {
    try {
      const response = await fetch(`${API_BASE}/api/auth/refresh`, {
        method: "POST",
        credentials: "omit",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: tokens.refresh })
      });
      if (response.status === 401) {
        // Expired, revoked (sign-out, password change) or the account was deleted.
        await endMobileSession(SESSION_EXPIRED);
        return false;
      }
      if (!response.ok) throw new Error(`Token refresh failed (${response.status})`);
      await storeMobileSession(await response.json());
      return true;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

// Ask the server who is signed in (renewing the JWT if needed).
// Returns true, false (signed out), or throws when the server is unreachable.
async function checkMobileSession() {
  const response = await apiFetch("/api/auth/session", { silent: true });
  if (response.ok) {
    authState.user = (await response.json()).user; // The server is the reference (role may have changed).
    authState.restoredOffline = false;
    await saveProfile(authState.user);
    return true;
  }
  if (response.status === 401) {
    if (authState.user || tokens.refresh) await endMobileSession(SESSION_EXPIRED);
    return false;
  }
  throw new Error(`Server error ${response.status}`);
}

async function openMobileSession(profile) {
  tokens.refresh = await secureStore.get(REFRESH_TOKEN_KEY);
  tokens.access = await secureStore.get(ACCESS_TOKEN_KEY);
  authState.locked = false;

  try {
    await checkMobileSession();
  } catch (error) {
    // Offline or server unreachable: work from the device, within the limit.
    if (Date.now() - profile.lastOnlineCheck < MAX_OFFLINE_MS) {
      authState.user = profile.user;
      authState.restoredOffline = true;
    } else {
      authState.notice = OFFLINE_TOO_LONG;
    }
    console.warn("Server unreachable, session opened from the device:", error);
  }
}

async function initializeMobileSession() {
  // Tokens from older builds were kept unencrypted: drop them.
  try {
    localStorage.removeItem("theme1_mobile_token");
  } catch {
    // Storage unavailable: nothing to clean.
  }

  const [refreshToken, profile] = await Promise.all([secureStore.get(REFRESH_TOKEN_KEY), localDb.get(PROFILE_KEY)]);
  if (!refreshToken || !profile?.user) return; // Never signed in here: sign-in screen.

  if (!(await biometric.unlock())) {
    authState.locked = true; // The sign-in screen offers to try again.
    return;
  }
  await openMobileSession(profile);
}

// Retry the local unlock from the sign-in screen after a cancelled prompt.
export async function unlockSession() {
  const profile = await localDb.get(PROFILE_KEY);
  if (!profile?.user || !(await biometric.unlock())) return false;
  await openMobileSession(profile);
  return Boolean(authState.user);
}

async function clearPreviousUserCaches(userId) {
  const lastUserId = await localDb.get(LAST_USER_KEY);
  if (lastUserId !== null && String(lastUserId) !== String(userId)) {
    await Promise.all(USER_CACHE_PREFIXES.map((prefix) => localDb.removePrefix(prefix)));
  }
  await localDb.set(LAST_USER_KEY, userId);
}

// ---------------------------------------------------------------------------
// Web session (HttpOnly cookie + CSRF)
// ---------------------------------------------------------------------------

// Returns true, false (signed out), or throws when the server is unreachable.
async function checkWebSession() {
  const csrfResponse = await apiFetch("/api/auth/csrf", { silent: true });
  if (csrfResponse.status >= 500) throw new Error(`Server error ${csrfResponse.status}`);
  if (!csrfResponse.ok) return false;

  const csrfData = await csrfResponse.json();
  // No token means no session cookie; skip the session call entirely.
  if (!csrfData.csrf_token) return false;

  authState.csrfToken = csrfData.csrf_token;
  const sessionResponse = await apiFetch("/api/auth/session", { silent: true });
  if (!sessionResponse.ok) return false;

  authState.user = (await sessionResponse.json()).user;
  return true;
}

function clearWebSession() {
  authState.user = null;
  authState.csrfToken = null;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Restore the session at startup, before the router shows the first page.
export async function initializeAuth() {
  try {
    if (isMobile) {
      await initializeMobileSession();
    } else if (!(await checkWebSession())) {
      clearWebSession();
    }
  } catch (error) {
    console.warn("Session not restored:", error);
  } finally {
    authState.initialized = true;
  }
}

// Called by the sync before replaying the outbox: the server must confirm the
// session first. Returns false when the user was signed out on the server.
export async function revalidateSession() {
  if (isMobile) return checkMobileSession();
  const valid = await checkWebSession();
  if (!valid) clearWebSession();
  return valid;
}

// Sign in (always online). The mobile app stores its tokens in the Keystore.
export async function login(credentials) {
  const response = await apiFetch("/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(isMobile ? { ...credentials, client: "mobile" } : credentials)
  });

  const data = await response.json();
  if (!response.ok) {
    notifyError();
    throw new Error(data.error || "Unable to log in");
  }

  if (isMobile) {
    await clearPreviousUserCaches(data.user.id);
    await storeMobileSession(data);
  } else {
    authState.user = data.user;
    authState.csrfToken = data.csrf_token;
    authState.notice = "";
  }
  return data.user;
}

// Request reset instructions without revealing whether an email exists.
export async function requestPasswordReset(email) {
  const response = await apiFetch("/api/auth/password-reset/request", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email })
  });

  return response.json();
}

// Complete a reset using the one-time token delivered to the user.
export async function resetPassword(token, newPassword) {
  const response = await apiFetch("/api/auth/password-reset/confirm", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, new_password: newPassword })
  });

  const data = await response.json();
  if (!response.ok) {
    notifyError();
    throw new Error(data.error || "Unable to reset password");
  }
  return data;
}

// Complete an invitation by setting the initial password with the single-use token.
export async function acceptInvitation(token, newPassword) {
  const response = await apiFetch("/api/auth/accept-invitation", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, new_password: newPassword })
  });

  const data = await response.json();
  if (!response.ok) {
    notifyError();
    throw new Error(data.error || "Unable to accept invitation");
  }
  return data;
}

// Sign out. Works offline: the local session is cleared either way. On mobile
// the refresh token is revoked on the server when it can be reached.
export async function logout() {
  if (isMobile) {
    const refreshToken = tokens.refresh;
    if (refreshToken) {
      try {
        await apiFetch("/api/auth/revoke", {
          method: "POST",
          silent: true,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refresh_token: refreshToken })
        });
      } catch {
        // Offline: the token is deleted from the phone and expires on its own.
      }
    }
    await endMobileSession("");
    return;
  }

  try {
    await apiFetch("/api/auth/logout", { method: "POST", silent: true });
  } catch {
    // Server unreachable: the local state is cleared below.
  }
  clearWebSession();
}

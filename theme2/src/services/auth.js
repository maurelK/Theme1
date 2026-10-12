import { reactive } from "vue";
import { notifyError } from "./feedback";
const API_BASE = import.meta.env.VITE_API_BASE_URL || ''

// The mobile WebView serves the app from another site than the API, so the
// SameSite=Lax auth cookie is never sent: mobile uses a bearer token instead.
const isMobile = import.meta.env.MODE === "cordova";
const MOBILE_TOKEN_KEY = "theme1_mobile_token";

function readMobileToken() {
  try {
    return localStorage.getItem(MOBILE_TOKEN_KEY);
  } catch {
    return null;
  }
}

function storeMobileToken(token) {
  try {
    if (token) localStorage.setItem(MOBILE_TOKEN_KEY, token);
    else localStorage.removeItem(MOBILE_TOKEN_KEY);
  } catch {
    // Storage unavailable: the session simply won't survive an app restart.
  }
}
// Keep the JWT in the HttpOnly cookie and retain only safe session data in memory.
export const authState = reactive({
  user: null,
  csrfToken: null,
  initialized: false
});

const publicPaths = new Set([
  "/api/auth/login",
  "/api/auth/register",
  "/api/auth/csrf"
]);

// Attach cookies and the CSRF header consistently for every API request.
export async function apiFetch(path, options = {}) {
  const headers = new Headers(options.headers || {});

  if (!publicPaths.has(path) && authState.csrfToken) {
    headers.set("X-CSRF-Token", authState.csrfToken);
  }

  const mobileToken = isMobile && readMobileToken();
  if (mobileToken) {
    headers.set("Authorization", `Bearer ${mobileToken}`);
  }

  try {
    return await fetch(API_BASE + path, {
      ...options,
      credentials: "include",
      headers
    });
  } catch (error) {
    notifyError();
    throw error;
  }
}

// Restore the browser session after a refresh without reading the JWT.
// If the API is unreachable (offline, network error), the app still starts without a session.
export async function initializeAuth() {
  try {
    const csrfResponse = await apiFetch("/api/auth/csrf");
    if (!csrfResponse.ok) return;

    const csrfData = await csrfResponse.json();
    authState.csrfToken = csrfData.csrf_token;

    // No token means no session cookie; skip the session call entirely.
    if (!authState.csrfToken) return;

    const sessionResponse = await apiFetch("/api/auth/session");
    if (sessionResponse.ok) {
      const sessionData = await sessionResponse.json();
      authState.user = sessionData.user;
    }
  } catch (error) {
    console.warn("Session not restored:", error);
  } finally {
    authState.initialized = true;
  }
}

// Log in and keep only the returned safe profile and CSRF token client-side.
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

  if (isMobile) storeMobileToken(data.token);
  authState.user = data.user;
  authState.csrfToken = data.csrf_token;
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

// Clear the server cookie and the in-memory session state together.
export async function logout() {
  try {
    await apiFetch("/api/auth/logout", { method: "POST" });
  } finally {
    if (isMobile) storeMobileToken(null);
  }
  authState.user = null;
  authState.csrfToken = null;
}

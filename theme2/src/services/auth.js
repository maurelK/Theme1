import { reactive } from "vue";

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
  const method = (options.method || "GET").toUpperCase();

  if (!publicPaths.has(path) && authState.csrfToken) {
    headers.set("X-CSRF-Token", authState.csrfToken);
  }

  return fetch(path, {
    ...options,
    credentials: "include",
    headers
  });
}

// Restore the browser session after a refresh without reading the JWT.
export async function initializeAuth() {
  try {
    const csrfResponse = await apiFetch("/api/auth/csrf");
    if (!csrfResponse.ok) return;

    const csrfData = await csrfResponse.json();
    authState.csrfToken = csrfData.csrf_token;

    const sessionResponse = await apiFetch("/api/auth/session");
    if (sessionResponse.ok) {
      const sessionData = await sessionResponse.json();
      authState.user = sessionData.user;
    }
  } finally {
    authState.initialized = true;
  }
}

// Log in and keep only the returned safe profile and CSRF token client-side.
export async function login(credentials) {
  const response = await apiFetch("/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(credentials)
  });

  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "Unable to log in");

  authState.user = data.user;
  authState.csrfToken = data.csrf_token;
  return data.user;
}

// Register accounts as employees through the public registration endpoint.
export async function register(attributes) {
  const response = await apiFetch("/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(attributes)
  });

  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "Unable to register");
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
  if (!response.ok) throw new Error(data.error || "Unable to reset password");
  return data;
}

// Clear the server cookie and the in-memory session state together.
export async function logout() {
  await apiFetch("/api/auth/logout", { method: "POST" });
  authState.user = null;
  authState.csrfToken = null;
}

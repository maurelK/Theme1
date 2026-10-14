// Durable key-value store for offline data (cache, outbox, session).
// Mobile: SQLite through cordova-sqlite-storage, which survives app restarts
// and is not evicted like WebView storage. Web: localStorage fallback.
// Values are JSON-serialised; reads of a missing key return `fallback`.

const DB_NAME = "timemanager.db";
const WEB_PREFIX = "tm:";

let dbPromise = null;

function hasSqlite() {
  return typeof window !== "undefined" && Boolean(window.sqlitePlugin);
}

function executeSql(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.executeSql(sql, params, resolve, reject);
  });
}

// Opened lazily; the app only starts after `deviceready`, so the plugin is ready.
function openDb() {
  dbPromise ||= (async () => {
    const db = window.sqlitePlugin.openDatabase({ name: DB_NAME, location: "default" });
    await executeSql(db, "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)");
    return db;
  })();
  return dbPromise;
}

function parse(raw, fallback) {
  if (raw === null || raw === undefined) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

export const localDb = {
  async get(key, fallback = null) {
    try {
      if (hasSqlite()) {
        const result = await executeSql(await openDb(), "SELECT value FROM kv WHERE key = ?", [key]);
        return result.rows.length ? parse(result.rows.item(0).value, fallback) : fallback;
      }
      return parse(localStorage.getItem(WEB_PREFIX + key), fallback);
    } catch {
      return fallback;
    }
  },

  async set(key, value) {
    const raw = JSON.stringify(value);
    if (hasSqlite()) {
      await executeSql(await openDb(), "INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)", [key, raw]);
      return;
    }
    localStorage.setItem(WEB_PREFIX + key, raw);
  },

  async remove(key) {
    if (hasSqlite()) {
      await executeSql(await openDb(), "DELETE FROM kv WHERE key = ?", [key]);
      return;
    }
    localStorage.removeItem(WEB_PREFIX + key);
  },

  // Remove every key starting with `prefix` (e.g. a previous user's cache).
  async removePrefix(prefix) {
    if (hasSqlite()) {
      await executeSql(await openDb(), "DELETE FROM kv WHERE substr(key, 1, ?) = ?", [prefix.length, prefix]);
      return;
    }
    Object.keys(localStorage)
      .filter((key) => key.startsWith(WEB_PREFIX + prefix))
      .forEach((key) => localStorage.removeItem(key));
  }
};

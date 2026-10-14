// Best estimate of the server's current time, for actions recorded offline.
//
// Each online status response carries `server_time`. We keep:
//  * an in-memory anchor (server time + performance.now()), immune to the user
//    changing the phone's clock while the app is open;
//  * a persisted offset (server - device), used after an app restart.
// The server still validates every offline time (see Theme1.Clocks).

import { localDb } from "../platform/localDb";

const OFFSET_KEY = "trustedClock:offset";

let anchor = null; // { serverMs, perfMs }
let offsetMs = 0;
let loaded = false;

async function load() {
  if (loaded) return;
  offsetMs = (await localDb.get(OFFSET_KEY, 0)) || 0;
  loaded = true;
}

export const trustedClock = {
  // Record a server timestamp (ISO string) received just now.
  async sync(serverTime) {
    const serverMs = Date.parse(serverTime);
    if (Number.isNaN(serverMs)) return;
    anchor = { serverMs, perfMs: performance.now() };
    offsetMs = serverMs - Date.now();
    loaded = true;
    await localDb.set(OFFSET_KEY, offsetMs);
  },

  async now() {
    if (anchor) return new Date(anchor.serverMs + (performance.now() - anchor.perfMs));
    await load();
    return new Date(Date.now() + offsetMs);
  }
};

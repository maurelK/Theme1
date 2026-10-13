// Single source of truth for the top bar and the mobile bottom bar.

import { isMobileApp } from "./platform";

const svg = (path) =>
  `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="${path}"/></svg>`;

export const ICONS = {
  home: svg("M3 10.2 12 3l9 7.2V20a1.5 1.5 0 0 1-1.5 1.5h-4.75V14.5h-5.5v7H4.5A1.5 1.5 0 0 1 3 20V10.2Z"),
  clock: svg("M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm1 5v4.6l3.2 1.9a1 1 0 1 1-1 1.7l-3.7-2.2A1 1 0 0 1 11 12V7a1 1 0 1 1 2 0Z"),
  chart: svg("M4 20a1 1 0 0 1-1-1V5a1 1 0 1 1 2 0v13h15a1 1 0 1 1 0 2H4Zm4-4a1 1 0 0 1-1-1v-4a1 1 0 1 1 2 0v4a1 1 0 0 1-1 1Zm4 0a1 1 0 0 1-1-1V8a1 1 0 1 1 2 0v7a1 1 0 0 1-1 1Zm4 0a1 1 0 0 1-1-1v-5a1 1 0 1 1 2 0v5a1 1 0 0 1-1 1Z"),
  team: svg("M8 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm8.5 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM2 19a6 6 0 0 1 12 0v1H2v-1Zm13.5 1v-1a7.4 7.4 0 0 0-1.6-4.6A5 5 0 0 1 22 18.5V20h-6.5Z"),
  directory: svg("M4 4.5A1.5 1.5 0 0 1 5.5 3h5A1.5 1.5 0 0 1 12 4.5v15A1.5 1.5 0 0 1 10.5 21h-5A1.5 1.5 0 0 1 4 19.5v-15Zm10 3A1.5 1.5 0 0 1 15.5 6h3A1.5 1.5 0 0 1 20 7.5v12a1.5 1.5 0 0 1-1.5 1.5h-3a1.5 1.5 0 0 1-1.5-1.5v-12Z"),
  admin: svg("M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3Zm0 5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Zm0 12.2a7 7 0 0 1-4.2-3.2c.6-1.4 2.4-2.3 4.2-2.3s3.6.9 4.2 2.3a7 7 0 0 1-4.2 3.2Z"),
  profile: svg("M12 12a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9Zm-8 8.5C4 16.4 7.6 14 12 14s8 2.4 8 6.5a.5.5 0 0 1-.5.5h-15a.5.5 0 0 1-.5-.5Z"),
  signOut: svg("M10 3.5a1 1 0 0 1 1 1v9a1 1 0 1 1-2 0v-9a1 1 0 0 1 1-1Zm-4.6 2.3a1 1 0 0 1 .1 1.4A6 6 0 1 0 12 18a6 6 0 0 0 4.5-2.1 1 1 0 1 1 1.5 1.3A8 8 0 1 1 5.3 6.3a1 1 0 0 1 1.4-.1l.7.6Z")
};

// Links for a role. Dashboards (Overview, My hours) are web-only: the mobile app has none.
export function navLinksFor(role) {
  const links = [];
  if (!isMobileApp) links.push({ label: "Overview", to: "/", icon: ICONS.home });
  links.push({ label: "My time", to: "/my-time", icon: ICONS.clock });
  if (!isMobileApp) links.push({ label: "My hours", to: "/my-hours", icon: ICONS.chart });

  if (role === "employee") {
    links.push({ label: "My team", to: "/my-team", icon: ICONS.team });
  } else {
    links.push({ label: "Directory", to: "/directory", icon: ICONS.directory });
    if (role === "administrator") {
      links.push({ label: "Admin", to: "/admin", icon: ICONS.admin });
    } else {
      links.push({ label: "Teams", to: "/admin/teams", icon: ICONS.team });
    }
  }

  links.push({ label: "Profile", to: "/profile", icon: ICONS.profile });
  return links;
}

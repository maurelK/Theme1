// True in the Cordova build (vite build --mode cordova). Dashboards and charts are web-only.
export const isMobileApp = import.meta.env.MODE === "cordova";

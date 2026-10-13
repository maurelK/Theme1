// Haptic and sound feedback for clock actions. Sounds are synthesised with the
// Web Audio API, so there are no audio files to ship in the web or mobile build.

let audioContext;

function vibrate(pattern) {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate(pattern);
  }
}

function getAudioContext() {
  if (typeof window === "undefined") return null;
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return null;
  audioContext ||= new AudioContext();
  return audioContext;
}

// Browsers and WebViews only allow audio started from a user gesture. Call this
// synchronously in the click handler, before any await, so the sound that plays
// after the server answers is not blocked.
export function unlockAudio() {
  try {
    const context = getAudioContext();
    if (context?.state === "suspended") context.resume();
  } catch {
    // Audio is optional.
  }
}

// One note with a short attack and a smooth release.
function playNote(frequency, { delay = 0, duration = 0.18, type = "sine", volume = 0.2 } = {}) {
  try {
    const context = getAudioContext();
    if (!context) return;

    const start = context.currentTime + delay;
    const oscillator = context.createOscillator();
    const gain = context.createGain();

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(volume, start + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.05);
  } catch {
    // Audio is optional and can be unavailable in a WebView or muted browser.
  }
}

// Notes (Hz).
const C4 = 261.63, C5 = 523.25, E5 = 659.25, G5 = 783.99, C6 = 1046.5;

// Clock in: quick, bright rising arpeggio ending high ("start of shift").
export function notifyClockIn() {
  vibrate(80);
  playNote(C5, { type: "triangle", duration: 0.14 });
  playNote(E5, { type: "triangle", duration: 0.14, delay: 0.1 });
  playNote(G5, { type: "triangle", duration: 0.14, delay: 0.2 });
  playNote(C6, { type: "triangle", duration: 0.35, delay: 0.3 });
}

// Clock out: slower, soft falling notes ending on a long low tone ("end of shift").
export function notifyClockOut() {
  vibrate([60, 60, 120]);
  playNote(G5, { duration: 0.22 });
  playNote(E5, { duration: 0.22, delay: 0.18 });
  playNote(C5, { duration: 0.22, delay: 0.36 });
  playNote(C4, { duration: 0.6, delay: 0.54, volume: 0.25 });
}

// Error: two low, buzzy blips, clearly different from both clock sounds.
export function notifyError() {
  vibrate([80, 50, 160]);
  playNote(196, { type: "square", duration: 0.14, volume: 0.08 });
  playNote(147, { type: "square", duration: 0.2, delay: 0.17, volume: 0.08 });
}

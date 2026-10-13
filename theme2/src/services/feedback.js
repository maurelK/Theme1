let audioContext;

function vibrate(pattern) {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate(pattern);
  }
}

function playTone(frequency, duration, delay = 0) {
  if (typeof window === "undefined") return;

  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;

    audioContext ||= new AudioContext();
    const start = audioContext.currentTime + delay;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();

    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.08, start + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain);
    gain.connect(audioContext.destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.02);
  } catch {
    // Audio is optional and can be unavailable in a WebView or muted browser.
  }
}

export function notifyError() {
  vibrate([80, 50, 160]);
  playTone(220, 0.16);
  playTone(150, 0.2, 0.18);
}

export function notifyClockIn() {
  vibrate(70);
  playTone(520, 0.12);
  playTone(740, 0.16, 0.13);
}

export function notifyClockOut() {
  vibrate([45, 35, 45]);
  playTone(740, 0.12);
  playTone(520, 0.16, 0.13);
}

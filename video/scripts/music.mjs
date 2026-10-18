// Synthesizes public/music.wav: an original, royalty-free score cut to the video's timeline.
// Pure JS, no samples: drones + ticks for the hook, a riser into the logo drop, then a
// 120 BPM C–G–Am–F groove with UI sound effects placed on the on-screen events.
import {readFileSync, writeFileSync} from 'node:fs';

const SR = 44100;
const FPS = 30;
const fr = (n) => n / FPS;
// Scene start times (seconds) from the same timeline the video uses.
const T = {};
{
  let at = 0;
  for (const [name, dur] of JSON.parse(readFileSync(new URL('../src/timeline.json', import.meta.url), 'utf8'))) { T[name] = fr(at); at += dur; }
  T.end = fr(at);
  T.drop = T.logo;
}
const LEN = T.end + 0.05;
const N = Math.ceil(LEN * SR);
const L = new Float32Array(N), R = new Float32Array(N);

const midi = (m) => 440 * 2 ** ((m - 69) / 12);
const env = (t, a, d) => (t < 0 ? 0 : t < a ? t / a : Math.exp(-(t - a) / d));
let seed = 7;
const noise = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;

function add(start, dur, fn, gain = 1, pan = 0) {
  const s0 = Math.max(0, Math.floor(start * SR)), s1 = Math.min(N, Math.floor((start + dur) * SR));
  const gl = gain * Math.cos(((pan + 1) * Math.PI) / 4), gr = gain * Math.sin(((pan + 1) * Math.PI) / 4);
  for (let i = s0; i < s1; i++) {
    const v = fn((i - s0) / SR, i);
    L[i] += v * gl; R[i] += v * gr;
  }
}

// ── instruments ──────────────────────────────────────────────
const kick = (t0, g = 1) => add(t0, 0.5, (t) => Math.sin(2 * Math.PI * (45 * t + 90 * (1 - Math.exp(-t * 28)) / 28)) * env(t, 0.002, 0.16) * 1.1, g);
const clap = (t0, g = 0.35) => { let lp = 0; add(t0, 0.25, (t) => { lp += 0.5 * (noise() - lp); return (noise() - lp) * env(t, 0.001, 0.07) * (t < 0.03 ? 1 + Math.sin(t * 600) : 1); }, g); };
const hat = (t0, g = 0.12, pan = 0.2) => { let lp = 0; add(t0, 0.06, (t) => { lp += 0.7 * (noise() - lp); return (noise() - lp) * env(t, 0.0005, 0.018); }, g, pan); };
const tick = (t0, g = 0.22, pitch = 2400) => add(t0, 0.05, (t) => Math.sin(2 * Math.PI * pitch * t) * env(t, 0.0005, 0.008), g, 0.15);
const bass = (t0, m, dur = 0.24, g = 0.32) => {
  const f = midi(m); let lp = 0;
  add(t0, dur + 0.05, (t) => { const saw = 2 * ((f * t) % 1) - 1; const cut = 0.04 + 0.25 * Math.exp(-t * 14); lp += cut * (saw - lp); return (lp * 1.6 + Math.sin(2 * Math.PI * f * t) * 0.6) * env(t, 0.004, dur * 0.6); }, g);
};
const pluck = (t0, m, g = 0.07, pan = 0) => { const f = midi(m); add(t0, 0.4, (t) => (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(4 * Math.PI * f * t) * Math.exp(-t * 20)) * env(t, 0.002, 0.11), g, pan); };
const pad = (t0, notes, dur, g = 0.05) => {
  for (const [k, m] of notes.entries()) {
    const f = midi(m);
    for (const det of [-0.12, 0.12]) {
      add(t0, dur, (t) => { const a = Math.min(1, t / 0.35) * Math.min(1, (dur - t) / 0.4); const ff = f * 2 ** (det / 12); return (2 * ((ff * t) % 1) - 1) * 0.35 * a + Math.sin(2 * Math.PI * ff * t) * 0.65 * a; }, g, det < 0 ? -0.5 + k * 0.1 : 0.5 - k * 0.1);
    }
  }
};
const pop = (t0, g = 0.25, f0 = 900) => add(t0, 0.12, (t) => Math.sin(2 * Math.PI * (f0 * t + 500 * (1 - Math.exp(-t * 40)) / 40)) * env(t, 0.002, 0.03), g);
const ding = (t0, g = 0.18, pan = 0) => add(t0, 1.2, (t) => (Math.sin(2 * Math.PI * 1318.5 * t) + 0.6 * Math.sin(2 * Math.PI * 1975.5 * t) * Math.exp(-t * 3) + 0.3 * Math.sin(2 * Math.PI * 2637 * t) * Math.exp(-t * 6)) * env(t, 0.003, 0.35), g, pan);
const whoosh = (t0, dur = 0.45, g = 0.16, up = true) => { let lp = 0; add(t0, dur, (t) => { const p = t / dur; const cut = 0.02 + 0.5 * (up ? p : 1 - p); lp += cut * (noise() - lp); return lp * Math.sin(Math.PI * p) ** 2; }, g); };
const boom = (t0, g = 0.9) => { add(t0, 2.2, (t) => Math.sin(2 * Math.PI * (32 * t + 70 * (1 - Math.exp(-t * 6)) / 6)) * env(t, 0.003, 0.6), g); let lp = 0; add(t0, 1.6, (t) => { lp += 0.3 * (noise() - lp); return lp * env(t, 0.001, 0.35); }, g * 0.5); };
const error = (t0) => { add(t0, 0.5, (t) => Math.tanh(4 * Math.sin(2 * Math.PI * 110 * t)) * env(t, 0.002, 0.12), 0.2); add(t0 + 0.13, 0.5, (t) => Math.tanh(4 * Math.sin(2 * Math.PI * 92.5 * t)) * env(t, 0.002, 0.14), 0.2); kick(t0, 0.7); };

// ── 1. hook + late: drone, clock, error, accelerating ticks, riser ──
add(0, T.drop, (t) => { const a = Math.min(1, t / 1.5) * Math.min(1, (T.drop - t) / 0.2); return (Math.sin(2 * Math.PI * 55 * t) * 0.6 + Math.sin(2 * Math.PI * 82.4 * t) * 0.3 + Math.sin(2 * Math.PI * 110.6 * t) * 0.15 * (0.5 + 0.5 * Math.sin(t * 1.3))) * a; }, 0.22);
for (let t = 0.1; t < T.late; t += 0.5) tick(t, 0.2, (Math.round(t * 2) % 2) ? 2000 : 2600);
for (let i = 0; i < 26; i++) tick(fr(4) + i * 0.2, 0.08, 3000);   // typing
error(fr(50));
whoosh(fr(66), 0.3, 0.12);
// clock spin: ticks speeding up
for (let t = T.late + 0.2, step = 0.25; t < T.late + fr(56); t += step, step = Math.max(0.035, step * 0.86)) tick(t, 0.18, 2200 + (t - T.late) * 300);
// riser into the drop
{ let lp = 0; const s = T.drop - 1.3; add(s, 1.3, (t) => { const p = t / 1.3; lp += (0.01 + 0.45 * p * p) * (noise() - lp); return lp * p * p; }, 0.55); }
for (let i = 0, t = T.drop - 1.0; t < T.drop; i++, t += Math.max(0.03, 0.125 * (1 - i / 14))) clap(t, 0.08 + 0.18 * (1 - (T.drop - t)));

// ── 2. drop + groove: C G Am F, 2 s per chord (1 bar @120bpm) ──
boom(T.drop);
const CHORDS = [[48, [60, 64, 67, 72]], [43, [59, 62, 67, 71]], [45, [57, 60, 64, 69]], [41, [57, 60, 65, 69]]];
const grooveEnd = T.install + fr(96);
const beat = 0.5;
for (let b = 0; T.drop + b * beat < grooveEnd; b++) {
  const t = T.drop + b * beat;
  const bar = Math.floor(b / 4), [root, notes] = CHORDS[bar % 4];
  const sparse = t < T.drop + 3;            // logo scene: let it breathe
  if (!sparse || b % 2 === 0) kick(t, 0.85);
  if (!sparse && b % 2 === 1) clap(t, 0.3);
  if (!sparse) { hat(t + beat / 2, 0.1, 0.3); hat(t + beat / 4, 0.04, -0.3); hat(t + 3 * beat / 4, 0.04, -0.3); }
  if (b % 4 === 0) pad(t, notes, 4 * beat + 0.3, 0.032);
  bass(t, root, 0.2); if (!sparse) bass(t + beat / 2, root + 12, 0.16, 0.22);
  if (!sparse) for (let k = 0; k < 4; k++) pluck(t + k * beat / 4, notes[(b * 4 + k) % 4] + 12, 0.045, k % 2 ? 0.4 : -0.4);
}

// ── 3. UI sound effects on on-screen events ──
const M = T.menubar, St = T.settings, Rm = T.reminders, D = T.devices, F = T.features, I = T.install;
pop(St + fr(14), 0.2, 1400); whoosh(St + fr(16), 0.3, 0.1);       // gear → settings pane
for (const at of [44, 66, 88]) { pop(St + fr(at - 3), 0.12, 1700); pop(St + fr(at), 0.2, 1100); }  // dropdown picks
pop(St + fr(110), 0.16, 800);                                       // toggle flips
whoosh(M - 0.1, 0.4, 0.1);
error(M + fr(82)); pop(M + fr(84), 0.18, 600);                 // hits 100% → countdown
whoosh(M + fr(100), 0.35, 0.12); pop(M + fr(104), 0.22, 1100);    // popover
pop(M + fr(110), 0.14, 1300); pop(M + fr(118), 0.14, 1500);
pop(Rm + fr(16), 0.2, 1000); pop(Rm + fr(28), 0.2, 1200);
pop(Rm + fr(80), 0.28, 700); whoosh(Rm + fr(90), 0.45, 0.14);  // "limits reset early" → time moves
ding(Rm + fr(112), 0.12);
ding(D + fr(12), 0.2, -0.3); ding(D + fr(24), 0.18, 0.1); ding(D + fr(36), 0.16, 0.4);
for (let i = 0; i < 6; i++) pop(F + fr(10 + i * 6), 0.16, 900 + i * 120);
for (let i = 0; i < 28; i++) tick(I + fr(14) + i * 0.033 + (i % 3) * 0.006, 0.07, 2800 + (i % 4) * 300);
for (let k = 0; k < 4; k++) pop(I + fr(14 + 88 / 3.2 + 6 + k * 7), 0.13, 1200 + k * 150);

// ── 4. end card: impact + ringing C chord ──
boom(grooveEnd, 0.7);
pad(grooveEnd, [48, 55, 60, 64, 67, 72], T.end - grooveEnd, 0.05);
for (const [i, m] of [72, 76, 79, 84].entries()) pluck(grooveEnd + i * 0.09, m, 0.08, (i - 1.5) * 0.3);

// ── master: fade out, soft clip, write 16-bit WAV ──
const out = Buffer.alloc(44 + N * 4);
out.write('RIFF', 0); out.writeUInt32LE(36 + N * 4, 4); out.write('WAVEfmt ', 8);
out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(2, 22); out.writeUInt32LE(SR, 24);
out.writeUInt32LE(SR * 4, 28); out.writeUInt16LE(4, 32); out.writeUInt16LE(16, 34); out.write('data', 36); out.writeUInt32LE(N * 4, 40);
let peak = 0;
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const fade = Math.min(1, t / 0.05, (LEN - t) / 0.8);
  const l = Math.tanh(L[i] * 0.9) * fade, r = Math.tanh(R[i] * 0.9) * fade;
  peak = Math.max(peak, Math.abs(l), Math.abs(r));
  out.writeInt16LE(Math.round(l * 30000), 44 + i * 4);
  out.writeInt16LE(Math.round(r * 30000), 46 + i * 4);
}
writeFileSync(new URL('../public/music.wav', import.meta.url), out);
console.log(`music.wav: ${LEN.toFixed(2)}s, peak ${peak.toFixed(2)}`);

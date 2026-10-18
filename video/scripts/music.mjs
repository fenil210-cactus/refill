// Synthesizes public/music.wav: an original, royalty-free score cut to the video's timeline.
// Pure JS, no samples: drones + ticks for the hook, a riser into the logo drop, then a
// 120 BPM C–G–Am–F groove with UI sound effects placed on the on-screen events.
import {createSynth, fr, sceneTimes} from './synth.mjs';

// Scene start times (seconds) from the same timeline the video uses.
const T = sceneTimes(new URL('../src/timeline.json', import.meta.url));
T.drop = T.logo;
const LEN = T.end + 0.05;
const {add, kick, clap, hat, tick, bass, pluck, pad, pop, ding, whoosh, boom, error, riser, write} = createSynth(LEN);

// ── 1. hook + late: drone, clock, error, accelerating ticks, riser ──
add(0, T.drop, (t) => { const a = Math.min(1, t / 1.5) * Math.min(1, (T.drop - t) / 0.2); return (Math.sin(2 * Math.PI * 55 * t) * 0.6 + Math.sin(2 * Math.PI * 82.4 * t) * 0.3 + Math.sin(2 * Math.PI * 110.6 * t) * 0.15 * (0.5 + 0.5 * Math.sin(t * 1.3))) * a; }, 0.22);
for (let t = 0.1; t < T.late; t += 0.5) tick(t, 0.2, (Math.round(t * 2) % 2) ? 2000 : 2600);
for (let i = 0; i < 26; i++) tick(fr(4) + i * 0.2, 0.08, 3000);   // typing
error(fr(50));
whoosh(fr(66), 0.3, 0.12);
// clock spin: ticks speeding up
for (let t = T.late + 0.2, step = 0.25; t < T.late + fr(56); t += step, step = Math.max(0.035, step * 0.86)) tick(t, 0.18, 2200 + (t - T.late) * 300);
// riser into the drop
riser(T.drop);
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

const peak = write(new URL('../public/music.wav', import.meta.url));
console.log(`music.wav: ${LEN.toFixed(2)}s, peak ${peak.toFixed(2)}`);

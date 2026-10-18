// Synthesizes public/music-claude.wav for the Claude Code cut: same palette as the launch score,
// a 120 BPM Am–F–C–G groove, and UI sounds on the pointer click, camera moves and the ping.
import {createSynth, fr, sceneTimes} from './synth.mjs';

const T = sceneTimes(new URL('../src/timeline-claude.json', import.meta.url));
const LEN = T.end + 0.05;
const {add, kick, clap, hat, tick, bass, pluck, pad, pop, ding, whoosh, boom, error, riser, write} = createSynth(LEN);
const drop = T.clogo;

// ── 1. hook: low drone, typing, the limit error, riser into the logo ──
add(0, drop, (t) => { const a = Math.min(1, t / 1.2) * Math.min(1, (drop - t) / 0.2); return (Math.sin(2 * Math.PI * 55 * t) * 0.6 + Math.sin(2 * Math.PI * 82.4 * t) * 0.3) * a; }, 0.22);
for (let i = 0; i < 20; i++) tick(fr(4) + i * 0.034 + (i % 3) * 0.01, 0.07, 3000);
error(fr(46));
whoosh(fr(60), 0.3, 0.12);
riser(drop, 1.1);
for (let i = 0, t = drop - 0.8; t < drop; i++, t += Math.max(0.03, 0.11 * (1 - i / 12))) clap(t, 0.08 + 0.18 * (1 - (drop - t)));

// ── 2. drop + groove ──
boom(drop);
const CHORDS = [[45, [57, 60, 64, 69]], [41, [57, 60, 65, 69]], [48, [60, 64, 67, 72]], [43, [59, 62, 67, 71]]];
const grooveEnd = T.cend;
const beat = 0.5;
for (let b = 0; drop + b * beat < grooveEnd; b++) {
  const t = drop + b * beat;
  const [root, notes] = CHORDS[Math.floor(b / 4) % 4];
  const sparse = t < T.czoom + 1.4;          // logo + pointer move: let it breathe
  if (!sparse || b % 2 === 0) kick(t, 0.85);
  if (!sparse && b % 2 === 1) clap(t, 0.3);
  if (!sparse) { hat(t + beat / 2, 0.1, 0.3); hat(t + beat / 4, 0.04, -0.3); hat(t + 3 * beat / 4, 0.04, -0.3); }
  if (b % 4 === 0) pad(t, notes, 4 * beat + 0.3, 0.032);
  bass(t, root, 0.2); if (!sparse) bass(t + beat / 2, root + 12, 0.16, 0.22);
  if (!sparse) for (let k = 0; k < 4; k++) pluck(t + k * beat / 4, notes[(b * 4 + k) % 4] + 12, 0.045, k % 2 ? 0.4 : -0.4);
}

// ── 3. UI sounds ──
const Z = T.czoom, S = T.cconnect, R = T.creminders;
tick(Z + fr(42), 0.3, 1800); pop(Z + fr(43), 0.2, 700);          // click
pop(Z + fr(45), 0.22, 1100);                                        // popover opens
whoosh(Z + fr(50), 1.3, 0.16);                                      // zoom in
whoosh(Z + fr(140), 1.2, 0.14);                                     // zoom down to Claude Code
pop(Z + fr(178), 0.16, 1500);
pop(S + fr(10), 0.2, 1400); whoosh(S + fr(16), 0.3, 0.1);          // gear → settings
pop(S + fr(44), 0.24, 800); pop(S + fr(50), 0.14, 1300);           // toggle on
for (const at of [70, 94, 118]) pop(S + fr(at - 2), 0.12, 1200);
for (let i = 0; i < 4; i++) pop(R + fr(12 + i * 8), 0.16, 1000 + i * 120);
ding(R + fr(72), 0.2, 0.3);                                         // the ping

// ── 4. end card ──
boom(grooveEnd, 0.7);
pad(grooveEnd, [45, 52, 57, 60, 64, 69], T.end - grooveEnd, 0.05);
for (const [i, m] of [69, 72, 76, 81].entries()) pluck(grooveEnd + i * 0.09, m, 0.08, (i - 1.5) * 0.3);

const peak = write(new URL('../public/music-claude.wav', import.meta.url));
console.log(`music-claude.wav: ${LEN.toFixed(2)}s, peak ${peak.toFixed(2)}`);

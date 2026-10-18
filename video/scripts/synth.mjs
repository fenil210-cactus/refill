// Tiny pure-JS synth shared by the launch scores: no samples, everything is generated.
import {readFileSync, writeFileSync} from 'node:fs';

export const SR = 44100;
export const FPS = 30;
export const fr = (n) => n / FPS;
export const midi = (m) => 440 * 2 ** ((m - 69) / 12);
const env = (t, a, d) => (t < 0 ? 0 : t < a ? t / a : Math.exp(-(t - a) / d));

/** Scene start times (seconds) from a timeline.json, plus `end`. */
export function sceneTimes(timelineUrl) {
  const T = {};
  let at = 0;
  for (const [name, dur] of JSON.parse(readFileSync(timelineUrl, 'utf8'))) { T[name] = fr(at); at += dur; }
  T.end = fr(at);
  return T;
}

export function createSynth(lengthSeconds) {
  const LEN = lengthSeconds;
  const N = Math.ceil(LEN * SR);
  const L = new Float32Array(N), R = new Float32Array(N);
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
  const riser = (end, dur = 1.3, g = 0.55) => { let lp = 0; add(end - dur, dur, (t) => { const p = t / dur; lp += (0.01 + 0.45 * p * p) * (noise() - lp); return lp * p * p; }, g); };

  /** Fade out, soft clip, write a 16-bit stereo WAV. */
  function write(url) {
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
    writeFileSync(url, out);
    return peak;
  }

  return {add, noise, kick, clap, hat, tick, bass, pluck, pad, pop, ding, whoosh, boom, error, riser, write};
}

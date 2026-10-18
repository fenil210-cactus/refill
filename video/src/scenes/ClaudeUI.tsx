import React from 'react';
import {interpolate, Easing} from 'remotion';
import {BoltCircle, Card, CloseCircle, DIM, Gear, GREEN, Popup, RED, SF, Sync, Toggle} from './RealUI';

// Replica of the v1.1 popover: Codex and Claude Code sections, and the regrouped settings pane.
export const CLAY = '#E08A68';
export const AMBER = '#FF9F0A';
const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const Section: React.FC<{title: string; detail: string; glow?: number; children: React.ReactNode}> = ({title, detail, glow = 0, children}) => (
  <div style={{display: 'flex', flexDirection: 'column', gap: 8, borderRadius: 14, margin: -6, padding: 6,
    boxShadow: glow > 0 ? `0 0 0 ${1.5 * glow}px ${CLAY}, 0 0 ${28 * glow}px ${CLAY}66` : 'none'}}>
    <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '0 2px'}}>
      <span style={{fontSize: 10.5, fontWeight: 650, letterSpacing: 0.7, color: 'rgba(255,255,255,0.6)'}}>{title.toUpperCase()}</span>
      <span style={{fontSize: 10.5, color: 'rgba(255,255,255,0.45)'}}>{detail}</span>
    </div>
    {children}
  </div>
);

const Shell: React.FC<{subtitle: string; settings?: boolean; gearPress?: number; spin?: number; synced: string; children: React.ReactNode}> = ({subtitle, settings, gearPress = 0, spin = 0, synced, children}) => (
  <div style={{width: 340, fontFamily: SF, color: '#fff', borderRadius: 16, padding: 14, display: 'flex', flexDirection: 'column', gap: 12,
    background: 'linear-gradient(180deg, rgba(58,86,114,0.84), rgba(44,68,94,0.86))', backdropFilter: 'blur(26px) saturate(1.4)',
    border: '0.5px solid rgba(255,255,255,0.28)', boxShadow: '0 22px 60px rgba(0,0,0,0.45), inset 0 0.5px 0 rgba(255,255,255,0.25)'}}>
    <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
      <BoltCircle size={24} />
      <div style={{flex: 1}}><div style={{fontSize: 13.5, fontWeight: 700}}>{settings ? 'Settings' : 'Refill'}</div><div style={{fontSize: 10.5, color: DIM}}>{subtitle}</div></div>
      <div style={{transform: `scale(${1 - gearPress * 0.2})`, opacity: 1 - gearPress * 0.3}}>{settings ? <CloseCircle /> : <Gear />}</div>
    </div>
    {children}
    <div style={{height: 0.5, background: 'rgba(255,255,255,0.15)'}} />
    <div style={{display: 'flex', alignItems: 'center', gap: 7, fontSize: 11, color: DIM}}>
      <Sync spin={spin} /> {synced}
      <div style={{flex: 1}} />
      {['Reminders', 'Quit'].map((b) => <div key={b} style={{background: 'rgba(255,255,255,0.16)', color: '#fff', fontSize: 11.5, fontWeight: 500, padding: '3px 10px', borderRadius: 6}}>{b}</div>)}
    </div>
  </div>
);

/** Main popover with both providers. `claudeGlow` rings the Claude Code section. */
export const DualPopover: React.FC<{barIn?: number; claudeGlow?: number; gearPress?: number}> = ({barIn = 1, claudeGlow = 0, gearPress = 0}) => (
  <Shell subtitle="Codex + Claude limits" synced="Synced just now" gearPress={gearPress}>
    <Section title="Codex" detail="Plus plan · live">
      <Card title="5-Hour" pct={64} resets="Resets today 8:02 PM · in 2h 42m" reminder="Reminder set for 8:02 PM" tint={GREEN} barIn={barIn} />
      <Card title="Weekly" pct={22} resets="Resets Sun, Oct 25, 2:13 AM · in 6d 8h" reminder="Reminder set for 2:13 AM" tint={GREEN} barIn={barIn} />
    </Section>
    <Section title="Claude Code" detail="updated just now" glow={claudeGlow}>
      <Card title="5-Hour" pct={100} resets="Resets today 6:54 PM · in 1h 34m" reminder="Reminder set for 6:54 PM" tint={RED} barIn={barIn} />
      <Card title="Weekly" pct={41} resets="Resets Wed, Oct 21, 5:19 PM · in 2d 23h" reminder="Reminder set for 5:19 PM" tint={GREEN} barIn={barIn} />
    </Section>
  </Shell>
);

const Group: React.FC<{title: string; children: React.ReactNode}> = ({title, children}) => (
  <div style={{display: 'flex', flexDirection: 'column', gap: 6}}>
    <span style={{fontSize: 10.5, fontWeight: 650, letterSpacing: 0.7, color: 'rgba(255,255,255,0.6)', padding: '0 2px'}}>{title.toUpperCase()}</span>
    <div style={{background: 'rgba(255,255,255,0.075)', borderRadius: 10, overflow: 'hidden'}}>{children}</div>
  </div>
);
const Row: React.FC<{label: string; detail?: string; first?: boolean; flash?: number; children?: React.ReactNode}> = ({label, detail, first, flash = 0, children}) => (
  <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '7px 11px', minHeight: 22, fontSize: 12.5,
    borderTop: first ? 'none' : '0.5px solid rgba(255,255,255,0.1)', background: `rgba(224,138,104,${0.22 * flash})`}}>
    <div style={{display: 'flex', flexDirection: 'column', gap: 1}}>
      <span>{label}</span>
      {detail && <span style={{fontSize: 10.5, color: DIM}}>{detail}</span>}
    </div>
    {children}
  </div>
);

/** Settings pane, v1.1 ordering: Track → Windows → Alerts → General → Advanced. */
export const SettingsPopover: React.FC<{claudeOn: number; claudeFlash: number; listFlash?: number}> = ({claudeOn, claudeFlash, listFlash = 0}) => (
  <Shell subtitle="Refill v1.1.0" settings synced="Synced just now">
    <Group title="Track">
      <Row label="Codex" detail="Live via the codex CLI" first><Toggle on={1} /></Row>
      <Row label="Claude Code" detail="Via its status line · Pro & Max" flash={claudeFlash}><Toggle on={claudeOn} /></Row>
    </Group>
    <Group title="Windows">
      <Row label="5-hour" first><Toggle on={1} /></Row>
      <Row label="Weekly"><Toggle on={1} /></Row>
    </Group>
    <Group title="Alerts">
      <Row label="Notify me" first><Popup value="5 min before" flash={0} /></Row>
      <Row label="Extra heads-up"><Popup value="1 hour before" flash={0} /></Row>
      <Row label="Only if I've used"><Popup value="Any amount" flash={0} /></Row>
    </Group>
    <Group title="General">
      <Row label="Reminders list" first flash={listFlash}><span style={{color: DIM, fontSize: 12}}>AI Limits</span></Row>
      <Row label="Open at login"><Toggle on={1} /></Row>
    </Group>
    <div style={{display: 'flex', alignItems: 'center', gap: 6, fontSize: 10.5, fontWeight: 650, letterSpacing: 0.7, color: 'rgba(255,255,255,0.6)', padding: '0 2px'}}>
      <span style={{fontSize: 9}}>▶</span> ADVANCED
    </div>
    <div style={{fontSize: 10.5, color: 'rgba(255,255,255,0.45)', padding: '0 2px'}}>Reads limits locally. Writes only to its own Reminders list.</div>
  </Shell>
);

/** macOS arrow pointer. */
export const Pointer: React.FC<{size?: number; press?: number}> = ({size = 26, press = 0}) => (
  <svg width={size} height={size * 1.45} viewBox="0 0 20 29" style={{transform: `scale(${1 - press * 0.12})`, transformOrigin: '2px 2px', filter: 'drop-shadow(0 2px 3px rgba(0,0,0,0.45))'}}>
    <path d="M2 2v21.5l5.2-5 3.5 8.3 3.6-1.5-3.5-8.2H18Z" fill="#000" stroke="#fff" strokeWidth="1.6" strokeLinejoin="round" />
  </svg>
);

export type Shot = {s: number; fx: number; fy: number; tx: number; ty: number};

/**
 * Camera: puts content point (fx, fy) at screen point (tx, ty) at scale s, clamped so the
 * desktop always fills the frame. Keyframes are eased one after another.
 */
export const camera = (f: number, keys: [number, Shot][], W: number, H: number): React.CSSProperties => {
  let shot = keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [a, A] = keys[i - 1], [b, B] = keys[i];
    if (f <= a) break;
    const p = interpolate(f, [a, b], [0, 1], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
    shot = {s: A.s + (B.s - A.s) * p, fx: A.fx + (B.fx - A.fx) * p, fy: A.fy + (B.fy - A.fy) * p, tx: A.tx + (B.tx - A.tx) * p, ty: A.ty + (B.ty - A.ty) * p};
  }
  const {s} = shot;
  const ox = Math.min(Math.max(shot.fx - shot.tx / s, 0), W - W / s);
  const oy = Math.min(Math.max(shot.fy - shot.ty / s, 0), H - H / s);
  return {transformOrigin: '0 0', transform: `scale(${s}) translate(${-ox}px, ${-oy}px)`};
};

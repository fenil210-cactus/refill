import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';

// Faithful replica of the real Refill popover (SwiftUI MenuBarExtra over a blue desktop),
// drawn in macOS points; callers scale it with `zoom`.
export const SF = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif';
const RED = '#FF5257', GREEN = '#22C38E', BLUE = '#0A84FF';
const DIM = 'rgba(255,255,255,0.62)';
const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

export const BoltCircle: React.FC<{size?: number}> = ({size = 30}) => (
  <svg width={size} height={size} viewBox="0 0 30 30"><circle cx="15" cy="15" r="15" fill={GREEN} />
    <path d="M16.4 6.5 9.6 16.1c-.3.4 0 1 .5 1h4.4l-1.1 6c-.1.6.6.9 1 .4l6.8-9.6c.3-.4 0-1-.5-1h-4.4l1.1-6c.1-.6-.6-.9-1-.4Z" fill="#fff" /></svg>
);
const Gear: React.FC = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.75)" strokeWidth="1.7"><circle cx="12" cy="12" r="3.2" />
    <path d="M12 2.8l1.6 2.3 2.7-.6.6 2.7 2.4 1.4-1.1 2.5 1.1 2.5-2.4 1.4-.6 2.7-2.7-.6L12 21.2l-1.6-2.3-2.7.6-.6-2.7-2.4-1.4 1.1-2.5-1.1-2.5 2.4-1.4.6-2.7 2.7.6Z" strokeLinejoin="round" /></svg>
);
const CloseCircle: React.FC = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.75)" strokeWidth="1.7"><circle cx="12" cy="12" r="9" /><path d="m9 9 6 6m0-6-6 6" strokeLinecap="round" /></svg>
);
const Reset: React.FC<{c?: string}> = ({c = DIM}) => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.4" strokeLinecap="round"><path d="M4 12a8 8 0 1 0 2.6-5.9M4 4v4.5h4.5" /></svg>
);
const BellBadge: React.FC = () => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill={GREEN}><path d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5.5-6.84V3.5a1.5 1.5 0 0 0-3 0v.66A7 7 0 0 0 5 11v5l-1.7 1.7A.75.75 0 0 0 3.83 19h16.34a.75.75 0 0 0 .53-1.3Z" /><circle cx="19" cy="5" r="4" /></svg>
);
const Sync: React.FC<{spin?: number}> = ({spin = 0}) => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.7)" strokeWidth="2" strokeLinecap="round" style={{transform: `rotate(${spin}deg)`}}><path d="M20 12a8 8 0 1 1-2.6-5.9M20 4v4.5h-4.5" /></svg>
);
export const HourglassSF: React.FC<{size?: number}> = ({size = 15}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="#fff"><path d="M6 2h12v2c0 3-2 5-4.3 6.6.2.2.3.3.3.5v1.8c0 .2-.1.3-.3.5C16 15 18 17 18 20v2H6v-2c0-3 2-5 4.3-6.6a.7.7 0 0 1-.3-.5v-1.8c0-.2.1-.3.3-.5C8 9 6 7 6 4V2Zm2.2 2c.3 2 1.8 3.4 3.8 4.6 2-1.2 3.5-2.6 3.8-4.6H8.2Zm3.8 10.4c-2 1.2-3.5 2.6-3.8 4.6h7.6c-.3-2-1.8-3.4-3.8-4.6Z" /></svg>
);

const Card: React.FC<{title: string; pct: number; resets: string; reminder: string; tint: string; barIn: number}> = ({title, pct, resets, reminder, tint, barIn}) => (
  <div style={{background: 'rgba(255,255,255,0.075)', borderRadius: 12, padding: '12px 13px 13px'}}>
    <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'baseline'}}>
      <div style={{fontSize: 13, fontWeight: 600}}>{title}</div>
      <div style={{fontSize: 18.5, fontWeight: 700, color: tint, fontVariantNumeric: 'tabular-nums', fontFamily: 'ui-rounded, ' + SF}}>{Math.round(pct * barIn)}%</div>
    </div>
    <div style={{height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.14)', margin: '9px 0 11px', overflow: 'hidden'}}>
      <div style={{width: `${pct * barIn}%`, height: '100%', background: tint, borderRadius: 3}} />
    </div>
    <div style={{fontSize: 11, color: DIM, display: 'flex', alignItems: 'center', gap: 5}}><Reset /> {resets}</div>
    <div style={{fontSize: 11, color: GREEN, marginTop: 7, display: 'flex', alignItems: 'center', gap: 5}}><BellBadge /> {reminder}</div>
  </div>
);

const Popup: React.FC<{value: string; flash: number}> = ({value, flash}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 6, padding: '2px 6px 2px 9px', borderRadius: 5, fontSize: 11.5,
    background: `rgba(255,255,255,${0.13 + flash * 0.25})`, boxShadow: flash > 0 ? `0 0 0 ${2 * flash}px rgba(10,132,255,${flash})` : 'none'}}>
    {value}
    <svg width="7" height="11" viewBox="0 0 7 11" fill="none" stroke="#fff" strokeWidth="1.4"><path d="M1 4 3.5 1.5 6 4M1 7l2.5 2.5L6 7" /></svg>
  </div>
);
const Toggle: React.FC<{on: number}> = ({on}) => (
  <div style={{width: 38, height: 22, borderRadius: 11, background: on > 0.5 ? BLUE : 'rgba(255,255,255,0.2)', position: 'relative'}}>
    <div style={{position: 'absolute', top: 2, left: 2 + on * 16, width: 18, height: 18, borderRadius: 9, background: '#fff', boxShadow: '0 1px 2px rgba(0,0,0,0.3)'}} />
  </div>
);
const Row: React.FC<{label: string; children?: React.ReactNode; last?: boolean}> = ({label, children, last}) => (
  <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 11px', minHeight: 22, fontSize: 12.5, borderBottom: last ? 'none' : '0.5px solid rgba(255,255,255,0.1)'}}>
    <span style={{maxWidth: 150, lineHeight: 1.25}}>{label}</span>{children}
  </div>
);

export type SettingsState = {notify: string; headsUp: string; minUsed: string; fiveHour: number; weekly: number; flash: Record<string, number>};

/** The popover. `mode` = cards or settings; animate via props. */
export const RealPopover: React.FC<{mode: 'main' | 'settings'; countdown: string; synced: string; barIn?: number; settings?: SettingsState; spin?: number; gearPress?: number}> = ({
  mode, countdown, synced, barIn = 1, settings, spin = 0, gearPress = 0,
}) => (
  <div style={{width: 340, fontFamily: SF, color: '#fff', borderRadius: 16, padding: 14, display: 'flex', flexDirection: 'column', gap: 12,
    background: 'linear-gradient(180deg, rgba(58,86,114,0.80), rgba(44,68,94,0.82))', backdropFilter: 'blur(26px) saturate(1.4)',
    border: '0.5px solid rgba(255,255,255,0.28)', boxShadow: '0 22px 60px rgba(0,0,0,0.45), inset 0 0.5px 0 rgba(255,255,255,0.25)'}}>
    <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
      <BoltCircle size={24} />
      <div style={{flex: 1}}><div style={{fontSize: 13.5, fontWeight: 700}}>Refill</div><div style={{fontSize: 10.5, color: DIM}}>Team plan · live</div></div>
      <div style={{transform: `scale(${1 - gearPress * 0.2})`, opacity: 1 - gearPress * 0.3}}>{mode === 'main' ? <Gear /> : <CloseCircle />}</div>
    </div>
    {mode === 'main' ? (
      <>
        <Card title="Codex · 5-Hour" pct={100} resets={`Resets today 8:02 PM · in ${countdown}`} reminder="Reminder set for 8:02 PM" tint={RED} barIn={barIn} />
        <Card title="Codex · Weekly" pct={22} resets="Resets Sun, Oct 25, 2:13 AM · in 6d 9h" reminder="Reminder set for 2:13 AM" tint={GREEN} barIn={barIn} />
      </>
    ) : settings && (
      <>
        <div style={{background: 'rgba(255,255,255,0.075)', borderRadius: 10}}>
          <Row label="Notify me"><Popup value={settings.notify} flash={settings.flash.notify ?? 0} /></Row>
          <Row label="Extra heads-up"><Popup value={settings.headsUp} flash={settings.flash.headsUp ?? 0} /></Row>
          <Row label="Only if I've used"><Popup value={settings.minUsed} flash={settings.flash.minUsed ?? 0} /></Row>
          <Row label="5-hour window"><Toggle on={settings.fiveHour} /></Row>
          <Row label="Weekly window" last><Toggle on={settings.weekly} /></Row>
        </div>
        <div style={{background: 'rgba(255,255,255,0.075)', borderRadius: 10}}>
          <Row label="Reminders list"><span style={{color: DIM, fontSize: 12}}>Codex Limits</span></Row>
          <Row label="Live check via codex app-server"><Toggle on={1} /></Row>
          <Row label="Background check"><Popup value="Every 10 min" flash={0} /></Row>
          <Row label="codex path (auto)" />
          <Row label="Open at login" last><Toggle on={1} /></Row>
        </div>
      </>
    )}
    <div style={{height: 0.5, background: 'rgba(255,255,255,0.15)'}} />
    <div style={{display: 'flex', alignItems: 'center', gap: 7, fontSize: 11, color: DIM}}>
      <Sync spin={spin} /> {synced}
      <div style={{flex: 1}} />
      {['Reminders', 'Quit'].map((b) => <div key={b} style={{background: 'rgba(255,255,255,0.16)', color: '#fff', fontSize: 11.5, fontWeight: 500, padding: '3px 10px', borderRadius: 6}}>{b}</div>)}
    </div>
  </div>
);

/** Blue alpine desktop like the real screenshot, with a translucent menu bar. */
export const BlueDesktop: React.FC<{children?: React.ReactNode; vertical?: boolean; chip: React.ReactNode; chipActive?: boolean; clock?: string}> = ({children, vertical, chip, chipActive, clock = 'Sun 18 Oct  4:23 PM'}) => {
  const f = useCurrentFrame();
  const drift = interpolate(f, [0, 300], [0, -30], clampOpts);
  return (
    <AbsoluteFill style={{fontFamily: SF}}>
      <AbsoluteFill style={{background: 'linear-gradient(180deg, #1b3553 0%, #2f5d86 42%, #6e9cc4 70%, #a9c8e2 100%)'}} />
      <svg width="100%" height="100%" viewBox="0 0 1920 1080" preserveAspectRatio="xMidYMax slice" style={{position: 'absolute', inset: 0, transform: `translateX(${drift}px)`}}>
        <path d="M-50 760 260 470 420 590 640 380 860 600 1010 500 1240 300 1470 560 1620 470 1980 700V1080H-50Z" fill="#c9dcec" opacity="0.55" />
        <path d="M-50 860 200 640 380 760 560 600 800 820 1000 690 1180 560 1400 780 1580 680 1980 860V1080H-50Z" fill="#e9f1f8" opacity="0.75" />
        <path d="M-50 960 320 820 600 930 900 800 1250 950 1560 850 1980 980V1080H-50Z" fill="#33597c" opacity="0.9" />
      </svg>
      {/* keeps captions legible over the snow */}
      <AbsoluteFill style={{background: 'linear-gradient(180deg, transparent 50%, rgba(12,28,48,0.6) 100%)'}} />
      <div style={{position: 'absolute', top: 0, left: 0, right: 0, height: vertical ? 64 : 44, background: 'rgba(30,50,72,0.35)', backdropFilter: 'blur(20px)', display: 'flex', alignItems: 'center', padding: '0 20px', gap: vertical ? 22 : 26, color: '#fff', fontSize: vertical ? 22 : 15, fontWeight: 500, zoom: vertical ? 1 : 1.25}}>
        <svg width="15" height="18" viewBox="0 0 17 20" fill="#fff"><path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9C3.6 4.8 2 5.8 1.1 7.4-.8 10.6.6 15.4 2.4 18c.9 1.3 1.9 2.7 3.3 2.6 1.3-.1 1.8-.9 3.4-.9s2 .9 3.4.8c1.4 0 2.3-1.3 3.2-2.6 1-1.5 1.4-2.9 1.4-3-.1 0-2.9-1.1-3-4.3ZM11.6 3c.7-.9 1.2-2 1.1-3.2-1 0-2.3.7-3 1.6-.7.8-1.3 2-1.1 3.1 1.1.1 2.3-.6 3-1.5Z" /></svg>
        {!vertical && <><b>Terminal</b><span>Shell</span><span>Edit</span><span>View</span><span>Window</span><span>Help</span></>}
        <div style={{flex: 1}} />
        <div style={{display: 'flex', alignItems: 'center', gap: 5, padding: '3px 9px', borderRadius: 6, background: chipActive ? 'rgba(255,255,255,0.28)' : 'transparent', fontVariantNumeric: 'tabular-nums'}}>{chip}</div>
        {!vertical && <>
          {[['SSD', '32%'], ['RAM', '79%'], ['CPU', '30%']].map(([k, v]) => (
            <div key={k} style={{display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1, gap: 1}}><span style={{fontSize: 8, fontWeight: 600, opacity: 0.85}}>{k}</span><span style={{fontSize: 13, fontWeight: 600}}>{v}</span></div>
          ))}
          <svg width="20" height="14" viewBox="0 0 24 18" fill="#fff"><path d="M12 13.5a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6Zm-5-3.3 1.6 1.6a4.8 4.8 0 0 1 6.8 0l1.6-1.6a7.1 7.1 0 0 0-10 0ZM2.6 5.8l1.6 1.6a11 11 0 0 1 15.6 0l1.6-1.6a13.3 13.3 0 0 0-18.8 0Z" /></svg>
        </>}
        <div style={{width: 25, height: 12, border: '1.5px solid rgba(255,255,255,0.85)', borderRadius: 4, padding: 1.5}}><div style={{width: '72%', height: '100%', background: '#fff', borderRadius: 1.5}} /></div>
        <span>{clock}</span>
      </div>
      {children}
    </AbsoluteFill>
  );
};

/** Animated settings changes for the "your rules" scene. */
export const useSettingsScript = (f: number): SettingsState => {
  const step = (at: number) => f >= at;
  const flash = (at: number) => interpolate(f, [at - 2, at, at + 14], [0, 1, 0], clampOpts);
  return {
    notify: step(44) ? '5 min before' : 'At reset',
    headsUp: step(66) ? '1 hour before' : 'None',
    minUsed: step(88) ? '≥ 50%' : 'Any amount',
    fiveHour: 1,
    weekly: interpolate(f, [108, 116], [1, 0], {...clampOpts, easing: Easing.inOut(Easing.cubic)}),
    flash: {notify: flash(44), headsUp: flash(66), minUsed: flash(88)},
  };
};

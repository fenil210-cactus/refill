import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {loadFont} from '@remotion/google-fonts/Inter';
import {loadFont as loadMono} from '@remotion/google-fonts/JetBrainsMono';

export const {fontFamily: inter} = loadFont('normal', {weights: ['400', '500', '600', '700', '800', '900'], subsets: ['latin']});
export const {fontFamily: mono} = loadMono('normal', {weights: ['400', '600', '700'], subsets: ['latin']});

export const C = {
  bg: '#07100C',
  ink: '#F2FFF9',
  dim: 'rgba(242,255,249,0.58)',
  green: '#10B981',
  mint: '#34D399',
  red: '#FF5A5F',
  amber: '#FFB547',
  card: 'rgba(255,255,255,0.06)',
  line: 'rgba(255,255,255,0.10)',
};

export const useVertical = () => {
  const {width, height} = useVideoConfig();
  return height > width;
};

/** Dark canvas with a slowly drifting green glow. */
export const Backdrop: React.FC<{glow?: string; children?: React.ReactNode}> = ({glow = C.green, children}) => {
  const f = useCurrentFrame();
  const x = 50 + Math.sin(f / 90) * 12;
  const y = 40 + Math.cos(f / 110) * 10;
  return (
    <AbsoluteFill style={{background: C.bg, fontFamily: inter, color: C.ink, overflow: 'hidden'}}>
      <AbsoluteFill style={{background: `radial-gradient(60% 55% at ${x}% ${y}%, ${glow}33 0%, transparent 70%)`}} />
      <AbsoluteFill
        style={{
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
          maskImage: 'radial-gradient(70% 70% at 50% 50%, black, transparent)',
        }}
      />
      {children}
    </AbsoluteFill>
  );
};

/** 0→1 spring starting at `delay` frames. */
export const usePop = (delay = 0, config = {damping: 14, stiffness: 160, mass: 0.7}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: f - delay, fps, config});
};

export const fadeInOut = (f: number, dur: number, inLen = 8, outLen = 8) =>
  interpolate(f, [0, inLen, dur - outLen, dur], [0, 1, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

/** Big headline that rises in word by word. */
export const Headline: React.FC<{text: string; delay?: number; size?: number; color?: string; accent?: string[]; accentColor?: string; style?: React.CSSProperties}> = ({
  text, delay = 0, size = 92, color = C.ink, accent = [], accentColor = C.mint, style,
}) => {
  const f = useCurrentFrame();
  // "|" forces a line break.
  const words = text.replace(/\s*\|\s*/g, ' | ').split(' ');
  const strip = (s: string) => s.replace(/[.,!?]/g, '');
  const accents = accent.map(strip);
  let n = 0;
  return (
    <div style={{display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: `0 ${size * 0.26}px`, fontSize: size, fontWeight: 800, letterSpacing: -size * 0.035, lineHeight: 1.08, ...style}}>
      {words.map((w, i) => {
        if (w === '|') return <div key={i} style={{flexBasis: '100%', height: 0}} />;
        const t = interpolate(f - delay - n++ * 3, [0, 12], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
        const isAccent = accents.includes(strip(w));
        return (
          <span key={i} style={{display: 'inline-block', opacity: t, transform: `translateY(${(1 - t) * size * 0.5}px)`, filter: `blur(${(1 - t) * 8}px)`, color: isAccent ? accentColor : color}}>
            {w}
          </span>
        );
      })}
    </div>
  );
};

export const Bolt: React.FC<{size?: number; color?: string}> = ({size = 24, color = 'currentColor'}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color}><path d="M13.2 1.8 4.6 13.4c-.4.5 0 1.2.6 1.2h5.6l-1.4 7.2c-.1.7.8 1.1 1.2.5l8.6-11.6c.4-.5 0-1.2-.6-1.2h-5.6l1.4-7.2c.1-.7-.8-1.1-1.2-.5Z" /></svg>
);

export const Hourglass: React.FC<{size?: number; color?: string}> = ({size = 24, color = 'currentColor'}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round">
    <path d="M6 2h12M6 22h12M7 2c0 5 10 6 10 10S7 17 7 22M17 2c0 5-10 6-10 10s10 5 10 10" />
  </svg>
);

export const Bell: React.FC<{size?: number; color?: string}> = ({size = 24, color = 'currentColor'}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color}><path d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5.5-6.84V3.5a1.5 1.5 0 0 0-3 0v.66A7 7 0 0 0 5 11v5l-1.7 1.7A.75.75 0 0 0 3.83 19h16.34a.75.75 0 0 0 .53-1.3Z" /></svg>
);

/** macOS-style window chrome. */
export const MacWindow: React.FC<{title?: string; width: number; height?: number; dark?: boolean; children: React.ReactNode; style?: React.CSSProperties}> = ({
  title, width, height, dark = true, children, style,
}) => (
  <div style={{width, height, borderRadius: 18, overflow: 'hidden', background: dark ? '#16191A' : '#FBFBFC', border: `1px solid ${dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.12)'}`,
    boxShadow: '0 40px 120px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(0,0,0,0.6)', display: 'flex', flexDirection: 'column', ...style}}>
    <div style={{height: 46, display: 'flex', alignItems: 'center', padding: '0 18px', gap: 9, background: dark ? '#1E2223' : '#ECECEE', borderBottom: `1px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.08)'}`, flexShrink: 0}}>
      {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <div key={c} style={{width: 14, height: 14, borderRadius: 7, background: c}} />)}
      <div style={{flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 600, color: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.55)', marginRight: 66}}>{title}</div>
    </div>
    <div style={{flex: 1, position: 'relative'}}>{children}</div>
  </div>
);

/** Types `text` from `start`, `cps` characters per frame. */
export const typed = (text: string, f: number, start: number, cps = 1.4) => text.slice(0, Math.max(0, Math.floor((f - start) * cps)));

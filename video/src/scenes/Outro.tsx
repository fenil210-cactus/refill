import React from 'react';
import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, Easing} from 'remotion';
import {Backdrop, C, Headline, MacWindow, mono, typed, usePop, useVertical} from '../theme';

const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const RemindersGlyph: React.FC<{size: number}> = ({size}) => (
  <div style={{width: size, height: size, borderRadius: size * 0.24, background: '#fff', display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: size * 0.1, padding: size * 0.16, flexShrink: 0}}>
    {['#FF9F0A', '#0A84FF', '#FF453A'].map((c) => (
      <div key={c} style={{display: 'flex', alignItems: 'center', gap: size * 0.08}}>
        <div style={{width: size * 0.16, height: size * 0.16, borderRadius: size, background: c}} />
        <div style={{flex: 1, height: size * 0.05, background: '#D1D1D6', borderRadius: 2}} />
      </div>
    ))}
  </div>
);

const Notification: React.FC<{scale?: number; style?: React.CSSProperties; light?: boolean}> = ({scale = 1, style, light}) => (
  <div style={{width: 520 * scale, borderRadius: 26 * scale, padding: `${18 * scale}px ${20 * scale}px`, display: 'flex', gap: 14 * scale, alignItems: 'center',
    background: light ? 'rgba(245,245,247,0.86)' : 'rgba(40,44,46,0.82)', color: light ? '#111' : '#fff', backdropFilter: 'blur(30px)', boxShadow: '0 20px 60px rgba(0,0,0,0.45)', border: '1px solid rgba(255,255,255,0.14)', ...style}}>
    <RemindersGlyph size={54 * scale} />
    <div style={{flex: 1, minWidth: 0}}>
      <div style={{display: 'flex', justifyContent: 'space-between', fontSize: 17 * scale, opacity: 0.6, fontWeight: 600}}><span>REMINDERS</span><span>now</span></div>
      <div style={{fontSize: 21 * scale, fontWeight: 700, marginTop: 3 * scale}}>Codex unblocked: 5-hour limit resets</div>
      <div style={{fontSize: 19 * scale, opacity: 0.75, marginTop: 2 * scale}}>Fresh limit at 8:02 PM. Go build.</div>
    </div>
  </div>
);

/** 6 · The ping lands on every device. */
export const Devices: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const mac = usePop(6), phone = usePop(18), watch = usePop(30);
  const shake = (start: number) => (f > start && f < start + 14 ? Math.sin((f - start) * 2.2) * (start + 14 - f) * 0.5 : 0);
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: v ? 60 : 50}}>
        <Headline text="Pinged on your Mac, iPhone and Watch." delay={2} size={v ? 84 : 76} accent={['Mac,', 'iPhone', 'Watch.']} style={{maxWidth: v ? 960 : 1600}} />
        <div style={{display: 'flex', alignItems: 'center', gap: v ? 60 : 70, transform: `scale(${v ? 1.45 : 1})`, margin: v ? '120px 0' : 0, flexDirection: 'row'}}>
          {/* Mac (horizontal only; vertical frames focus on phone + watch) */}
          <div style={{opacity: mac, transform: `translateY(${(1 - mac) * 40}px)`, display: v ? 'none' : 'block'}}>
            <div style={{width: 760, height: 470, borderRadius: 22, border: '10px solid #2a2d2f', background: 'linear-gradient(135deg,#0d3b2e,#1b1036)', position: 'relative', overflow: 'hidden'}}>
              <div style={{position: 'absolute', top: 0, left: 0, right: 0, height: 26, background: 'rgba(0,0,0,0.3)'}} />
              <div style={{position: 'absolute', top: 44, right: 18, transform: `translateX(${(1 - usePopLocal(f, 12)) * 600}px) translateX(${shake(12)}px)`}}><Notification scale={0.78} /></div>
            </div>
            <div style={{width: 860, height: 22, margin: '0 -50px', background: 'linear-gradient(#3a3d40,#1f2123)', borderRadius: '0 0 18px 18px'}} />
          </div>
          {/* iPhone */}
          <div style={{opacity: phone, transform: `translateY(${(1 - phone) * 60}px)`, width: 270, height: 560, borderRadius: 46, border: '9px solid #2a2d2f', background: 'linear-gradient(180deg,#123c30,#1b1036)', position: 'relative', overflow: 'hidden', flexShrink: 0}}>
            <div style={{position: 'absolute', top: 12, left: '50%', marginLeft: -45, width: 90, height: 26, borderRadius: 14, background: '#000'}} />
            <div style={{position: 'absolute', top: 70, width: '100%', textAlign: 'center', color: '#fff', fontSize: 74, fontWeight: 700, letterSpacing: -2}}>8:02</div>
            <div style={{position: 'absolute', bottom: 120, left: 10, transform: `translateY(${(1 - usePopLocal(f, 24)) * 300}px) translateX(${shake(24)}px)`}}><Notification scale={0.46} /></div>
          </div>
          {/* Watch */}
          <div style={{opacity: watch, transform: `translateY(${(1 - watch) * 60}px)`, display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0}}>
            <div style={{width: 110, height: 70, background: '#1f2123', borderRadius: '24px 24px 0 0'}} />
            <div style={{width: 200, height: 240, borderRadius: 54, border: '9px solid #2a2d2f', background: '#000', padding: 18, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, transform: `translateX(${shake(36)}px)`}}>
              <RemindersGlyph size={62} />
              <div style={{color: '#fff', fontSize: 17, fontWeight: 700, textAlign: 'center', lineHeight: 1.2}}>Codex 5-hour limit resets</div>
              <div style={{color: C.mint, fontSize: 15, fontWeight: 600}}>8:02 PM</div>
            </div>
            <div style={{width: 110, height: 70, background: '#1f2123', borderRadius: '0 0 24px 24px'}} />
          </div>
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

const usePopLocal = (f: number, start: number) => interpolate(f, [start, start + 12], [0, 1], {...clampOpts, easing: Easing.out(Easing.back(1.4))});

const FEATURES = [
  ['Live limits', 'straight from codex app-server'],
  ['One reminder per window', 'updated in place, never duplicated'],
  ['Follows every reset', 'early resets, rollovers, plan changes'],
  ['Heads-up alerts', '5, 15, 30 or 60 min before'],
  ['100% local', 'never reads your auth tokens'],
  ['Free & open source', 'MIT · under 2 MB · macOS 13+'],
];

/** 7 · Feature grid. */
export const Features: React.FC = () => {
  const v = useVertical();
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 56}}>
        <Headline text="Smart about every reset." delay={0} size={v ? 92 : 84} accent={['every']} />
        <div style={{display: 'grid', gridTemplateColumns: v ? '1fr' : '1fr 1fr 1fr', gap: 22, width: v ? 900 : 1560}}>
          {FEATURES.map(([t, d], i) => <Chip key={t} title={t} detail={d} delay={10 + i * 6} />)}
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

const Chip: React.FC<{title: string; detail: string; delay: number}> = ({title, detail, delay}) => {
  const p = usePop(delay);
  return (
    <div style={{background: 'rgba(255,255,255,0.055)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 22, padding: '26px 30px', opacity: p, transform: `translateY(${(1 - p) * 30}px) scale(${0.92 + p * 0.08})`}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 12, fontSize: 31, fontWeight: 800}}>
        <div style={{width: 12, height: 12, borderRadius: 6, background: C.mint, boxShadow: `0 0 16px ${C.mint}`}} />{title}
      </div>
      <div style={{fontSize: 23, color: C.dim, marginTop: 8, paddingLeft: 24}}>{detail}</div>
    </div>
  );
};

const CMD = 'curl -fsSL https://raw.githubusercontent.com/fenil210-cactus/refill/main/install.sh | bash';

/** 8 · Install one-liner → end card. */
export const Install: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const cmd = typed(CMD, f, 14, 3.2);
  const done = 14 + CMD.length / 3.2;
  const lines = [
    ['✓', 'downloaded 716K'],
    ['✓', 'installed /Applications/Refill.app'],
    ['✓', 'CLI: refill  (try: refill status)'],
    ['⚡', 'Refill is in your menu bar.'],
  ];
  const end = interpolate(f, [96, 110], [0, 1], clampOpts);
  const logo = usePop(100, {damping: 12, stiffness: 140, mass: 0.8});
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 50, opacity: 1 - end, transform: `scale(${1 - end * 0.06})`}}>
        <Headline text="One line. Ten seconds." delay={0} size={v ? 96 : 88} accent={['Ten', 'seconds.']} />
        <div style={{transform: `scale(${v ? 0.58 : 1})`}}>
          <MacWindow title="zsh" width={1480} height={330}>
            <div style={{fontFamily: mono, fontSize: 22.5, padding: '28px 34px', lineHeight: 1.75, color: '#D7E2DD'}}>
              <div style={{whiteSpace: 'nowrap'}}><span style={{color: C.mint}}>~ $</span> {cmd}{f < done + 4 && <span>▌</span>}</div>
              {lines.map(([i, t], k) => f > done + 6 + k * 7 && (
                <div key={t} style={{color: k === 3 ? C.mint : '#D7E2DD', fontWeight: k === 3 ? 700 : 400}}><span style={{color: C.mint}}>{'  '}{i}</span> {t}</div>
              ))}
            </div>
          </MacWindow>
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 26, opacity: end}}>
        <Img src={staticFile('icon.png')} style={{width: 210, height: 210, transform: `scale(${logo})`, filter: `drop-shadow(0 30px 80px ${C.green}88)`}} />
        <div style={{fontSize: 150, fontWeight: 900, letterSpacing: -7, lineHeight: 1}}>Refill</div>
        <div style={{fontSize: 42, fontWeight: 600, color: C.dim}}>Never miss a <span style={{color: C.mint}}>Codex</span> limit reset.</div>
        <div style={{marginTop: 18, fontFamily: mono, fontSize: v ? 34 : 36, fontWeight: 600, padding: '16px 30px', borderRadius: 16, background: 'rgba(52,211,153,0.12)', border: `1px solid ${C.mint}55`, color: C.mint}}>
          github.com/fenil210-cactus/refill
        </div>
        <div style={{fontSize: 26, color: C.dim, marginTop: 6}}>Free · Open source · macOS 13+ · Claude Code support coming soon</div>
      </AbsoluteFill>
    </Backdrop>
  );
};

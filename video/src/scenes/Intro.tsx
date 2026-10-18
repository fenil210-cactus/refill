import React from 'react';
import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, Easing} from 'remotion';
import {Backdrop, C, Headline, MacWindow, mono, typed, usePop, useVertical} from '../theme';

/** 1 · Hook: the limit wall. */
export const Hook: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const prompt = typed('refactor the auth module and add tests', f, 4, 1.6);
  const working = f > 34;
  const hit = f > 50;
  const shake = hit && f < 60 ? Math.sin(f * 2.6) * (60 - f) * 0.6 : 0;
  const winIn = usePop(0);
  return (
    <Backdrop glow={hit ? C.red : C.green}>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 56}}>
        <div style={{transform: `scale(${(v ? 0.56 : 1) * (0.9 + winIn * 0.1)}) translateX(${shake}px)`, opacity: winIn}}>
          <MacWindow title="codex · ~/my-app" width={1180} height={330}>
            <div style={{fontFamily: mono, fontSize: 27, padding: '30px 36px', lineHeight: 1.75, color: '#D7E2DD'}}>
              <div><span style={{color: C.mint}}>›</span> {prompt}<span style={{opacity: f < 34 && f % 16 < 8 ? 1 : 0}}>▌</span></div>
              {working && <div style={{color: C.dim}}>• Working <span style={{color: '#6b7a74'}}>({hit ? '2m 14s' : '2m 1' + Math.min(9, Math.floor((f - 34) / 2)) + 's'} · esc to interrupt)</span></div>}
              {hit && (
                <div style={{color: C.red, marginTop: 8, opacity: interpolate(f, [50, 56], [0, 1], {extrapolateRight: 'clamp'})}}>
                  ■ You've hit your usage limit. Try again at <b style={{color: '#fff'}}>8:02 PM</b>.
                </div>
              )}
            </div>
          </MacWindow>
        </div>
        {f > 66 && <Headline text="You'll forget." delay={66} size={v ? 120 : 104} />}
      </AbsoluteFill>
    </Backdrop>
  );
};

/** 2 · The clock runs past the reset while you're away. */
export const Late: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const t = interpolate(f, [6, 56], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)});
  const mins = Math.round(20 * 60 + 2 + t * (3 * 60 + 45)); // 8:02 PM → 11:47 PM
  const h = Math.floor(mins / 60) % 12 || 12;
  const m = String(mins % 60).padStart(2, '0');
  const color = t < 0.02 ? C.mint : C.red;
  return (
    <Backdrop glow={t < 0.02 ? C.green : C.red}>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 30}}>
        <div style={{fontSize: 30, fontWeight: 600, color: C.dim, letterSpacing: 6, textTransform: 'uppercase'}}>
          {t < 0.02 ? 'Limit refilled' : 'You check back at'}
        </div>
        <div style={{fontSize: v ? 230 : 260, fontWeight: 900, letterSpacing: -10, color, fontVariantNumeric: 'tabular-nums', textShadow: `0 0 80px ${color}55`}}>
          {h}:{m}<span style={{fontSize: v ? 90 : 110, letterSpacing: 0, marginLeft: 18}}>PM</span>
        </div>
        {f > 50 && <Headline text="3 hours of coding. Gone." delay={50} size={v ? 76 : 70} accent={[]} color={C.ink} style={{maxWidth: v ? 900 : 1400}} />}
      </AbsoluteFill>
    </Backdrop>
  );
};

/** 3 · Logo reveal. */
export const Logo: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const s = usePop(0, {damping: 11, stiffness: 120, mass: 0.9});
  const ring = interpolate(f, [0, 40], [0, 1], {extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <div style={{position: 'absolute', width: 900, height: 900, borderRadius: 450, border: `2px solid ${C.mint}`, opacity: (1 - ring) * 0.7, transform: `scale(${0.2 + ring * 1.2})`}} />
        <div style={{display: 'flex', flexDirection: v ? 'column' : 'row', alignItems: 'center', gap: v ? 30 : 44}}>
          <Img src={staticFile('icon.png')} style={{width: 260, height: 260, transform: `scale(${s}) rotate(${(1 - s) * -25}deg)`, filter: `drop-shadow(0 30px 80px ${C.green}88)`}} />
          <div style={{display: 'flex', flexDirection: 'column', alignItems: v ? 'center' : 'flex-start'}}>
            <div style={{fontSize: 190, fontWeight: 900, letterSpacing: -9, lineHeight: 1, opacity: interpolate(f, [8, 20], [0, 1], {extrapolateRight: 'clamp'}), transform: `translateX(${v ? 0 : interpolate(f, [8, 26], [-40, 0], {extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)})}px)`}}>
              Refill
            </div>
            <div style={{fontSize: 44, fontWeight: 600, color: C.dim, marginTop: 10, opacity: interpolate(f, [24, 36], [0, 1], {extrapolateRight: 'clamp'}), textAlign: v ? 'center' : 'left'}}>
              Never miss a <span style={{color: C.mint}}>Codex</span> limit reset.
            </div>
          </div>
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

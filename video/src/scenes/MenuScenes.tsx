import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';
import {Bolt, C, Headline, usePop, useVertical} from '../theme';
import {BlueDesktop, HourglassSF, RealPopover, useSettingsScript} from './RealUI';

const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const POPOVER_W = 340;
/** Popover position. CSS `zoom` also scales top/left, so offsets are given in pre-zoom units. */
const place = (v: boolean, zoomV: number): React.CSSProperties => v
  ? {zoom: zoomV, top: 84 / zoomV, left: (1080 - POPOVER_W * zoomV) / 2 / zoomV, transformOrigin: 'top center'}
  : {zoom: 1.6, top: 66, right: 330, transformOrigin: 'top right'};

const Caption: React.FC<{v: boolean; children: React.ReactNode}> = ({v, children}) => (
  <AbsoluteFill style={{justifyContent: 'flex-end', alignItems: v ? 'center' : 'flex-start', padding: v ? '0 60px 170px' : '0 110px 110px'}}>
    <div style={{maxWidth: v ? 960 : 860, padding: v ? 0 : '0', textShadow: '0 4px 40px rgba(10,25,45,0.6)'}}>{children}</div>
  </AbsoluteFill>
);

/** 4 · Menu bar meter climbs to 100%, flips to a countdown, popover opens (matches the real app). */
export const MenuBar: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const pct = Math.round(interpolate(f, [6, 78], [72, 100], {...clampOpts, easing: Easing.in(Easing.quad)}));
  const blocked = f >= 82;
  const tint = pct >= 100 ? C.red : pct >= 85 ? C.amber : '#fff';
  const flip = interpolate(f, [80, 90], [0, 1], clampOpts);
  const pop = usePop(104, {damping: 16, stiffness: 180, mass: 0.6});
  const barIn = interpolate(f, [110, 136], [0, 1], {...clampOpts, easing: Easing.out(Easing.cubic)});
  const zoomIn = interpolate(f, [96, 150], [1, v ? 1 : 1.08], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
  const chip = blocked ? (
    <><HourglassSF size={v ? 20 : 14} /><span style={{display: 'inline-block', transform: `rotateX(${(1 - flip) * 90}deg)`}}>3h 39m</span></>
  ) : (
    <><Bolt size={v ? 20 : 14} color={tint} /><span style={{color: tint, fontWeight: 600}}>{pct}%</span></>
  );
  return (
    <AbsoluteFill>
      <BlueDesktop vertical={v} chip={chip} chipActive={f > 100}>
        <div style={{position: 'absolute', ...place(v, 2.75), opacity: pop, scale: String(zoomIn),
          transform: `translateY(${(1 - pop) * -10}px) scale(${0.97 + pop * 0.03})`}}>
          <RealPopover mode="main" countdown="3h 39m" synced="Synced 3m ago" barIn={barIn} />
        </div>
        <Caption v={v}>
          {f < 96 ? <Headline text="Lives in your menu bar." delay={8} size={v ? 92 : 84} accent={['menu', 'bar.']} style={{justifyContent: v ? 'center' : 'flex-start'}} />
            : <Headline text="Knows exactly | when you're back." delay={98} size={v ? 92 : 84} accent={['exactly']} style={{justifyContent: v ? 'center' : 'flex-start'}} />}
        </Caption>
      </BlueDesktop>
    </AbsoluteFill>
  );
};

/** 4b · Gear → settings pane; options change on their own: lead time, heads-up, threshold, windows. */
export const Settings: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const s = useSettingsScript(f);
  const gearPress = interpolate(f, [10, 14, 18], [0, 1, 0], clampOpts);
  const swap = interpolate(f, [16, 26], [0, 1], {...clampOpts, easing: Easing.out(Easing.cubic)});
  const mode = f < 20 ? 'main' : 'settings';
  const chip = <><HourglassSF size={v ? 20 : 14} /><span>3h 39m</span></>;
  const lines = [
    [44, 'Ping 5 min before reset'],
    [66, 'Extra heads-up an hour ahead'],
    [88, 'Skip windows you barely used'],
    [108, 'Pick which limits to track'],
  ] as const;
  return (
    <AbsoluteFill>
      <BlueDesktop vertical={v} chip={chip} chipActive>
        <AbsoluteFill style={{background: `rgba(8,18,30,${0.25 * swap})`}} />
        <div style={{position: 'absolute', ...place(v, mode === 'settings' ? 2.0 : 2.75),
          transform: `translateY(${mode === 'settings' ? (1 - swap) * 8 : 0}px)`, opacity: mode === 'settings' ? 0.4 + swap * 0.6 : 1}}>
          <RealPopover mode={mode} countdown="3h 39m" synced="Synced 3m ago" settings={s} gearPress={gearPress} />
        </div>
        <AbsoluteFill style={{justifyContent: v ? 'flex-end' : 'center', alignItems: v ? 'center' : 'flex-start', padding: v ? '0 60px 140px' : '0 0 0 110px'}}>
          <div style={{maxWidth: v ? 960 : 720, textShadow: '0 4px 40px rgba(10,25,45,0.6)', display: 'flex', flexDirection: 'column', gap: v ? 34 : 40, alignItems: v ? 'center' : 'flex-start'}}>
            <Headline text="Your limits. | Your rules." delay={4} size={v ? 100 : 96} accent={['rules.']} style={{justifyContent: v ? 'center' : 'flex-start'}} />
            <div style={{display: 'flex', flexDirection: 'column', gap: 14}}>
              {lines.map(([at, t]) => {
                const p = interpolate(f, [at - 4, at + 6], [0, 1], {...clampOpts, easing: Easing.out(Easing.cubic)});
                return (
                  <div key={t} style={{display: 'flex', alignItems: 'center', gap: 14, fontSize: v ? 40 : 36, fontWeight: 700, opacity: p, transform: `translateX(${(1 - p) * -24}px)`}}>
                    <div style={{width: 30, height: 30, borderRadius: 15, background: C.mint, color: '#062016', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, fontWeight: 900}}>✓</div>{t}
                  </div>
                );
              })}
            </div>
          </div>
        </AbsoluteFill>
      </BlueDesktop>
    </AbsoluteFill>
  );
};

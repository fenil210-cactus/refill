import React from 'react';
import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {Backdrop, Bell, C, Headline, inter, MacWindow, mono, typed, usePop, useVertical} from '../theme';
import {BlueDesktop, HourglassSF} from './RealUI';
import {camera, CLAY, DualPopover, Pointer, SettingsPopover, Shot} from './ClaudeUI';
import {Notification} from './Outro';

// Claude Code launch: shorter cut that shows the new UI, with a camera that zooms into the popover.
const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const ease = (f: number, a: number, b: number) => interpolate(f, [a, b], [0, 1], {...clampOpts, easing: Easing.out(Easing.cubic)});

/** Where the menu bar item sits on each canvas (measured from renders), and the popover under it. */
const geo = (v: boolean) => {
  const chip = v ? {x: 742, y: 32} : {x: 1300, y: 27};
  const zoom = v ? 1.6 : 1.25;
  const w = 340 * zoom, top = v ? 76 : 62;
  const left = Math.min(chip.x - w / 2, (v ? 1080 : 1920) - w - 14);
  return {chip, zoom, w, top, left, h: 605 * zoom};
};

const Caption: React.FC<{v: boolean; children: React.ReactNode; bottom?: number}> = ({v, children, bottom}) => (
  <AbsoluteFill style={{justifyContent: 'flex-end', alignItems: v ? 'center' : 'flex-start', padding: v ? `0 60px ${bottom ?? 110}px` : `0 110px ${bottom ?? 120}px`}}>
    <div style={{fontFamily: inter, color: C.ink, maxWidth: v ? 960 : 820, textShadow: '0 4px 40px rgba(10,25,45,0.7)'}}>{children}</div>
  </AbsoluteFill>
);

const Countdown: React.FC<{v: boolean}> = ({v}) => <><HourglassSF size={v ? 20 : 14} /><span>1h 34m</span></>;

/** 1 · The same wall, in Claude Code. */
export const ClaudeHook: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const prompt = typed('add rate limiting to the API', f, 4, 1.4);
  const reply = f > 30, hit = f > 46;
  const shake = hit && f < 56 ? Math.sin(f * 2.6) * (56 - f) * 0.6 : 0;
  const winIn = usePop(0);
  return (
    <Backdrop glow={hit ? C.red : CLAY}>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: v ? 90 : 56}}>
        <div style={{transform: `scale(${(v ? 0.72 : 1) * (0.9 + winIn * 0.1)}) translateX(${shake}px)`, opacity: winIn, margin: v ? '0 -200px' : 0}}>
          <MacWindow title="claude · ~/my-app" width={1180} height={350}>
            <div style={{fontFamily: mono, fontSize: 27, padding: '26px 34px', lineHeight: 1.7, color: '#D7E2DD'}}>
              <div style={{border: '1.5px solid rgba(255,255,255,0.22)', borderRadius: 10, padding: '6px 16px', marginBottom: 14}}>
                <span style={{color: 'rgba(255,255,255,0.5)'}}>&gt;</span> {prompt}<span style={{opacity: f < 30 && f % 16 < 8 ? 1 : 0}}>▌</span>
              </div>
              {reply && <div><span style={{color: '#fff'}}>⏺</span> I'll add a token-bucket limiter to the routes…</div>}
              {hit && (
                <div style={{opacity: interpolate(f, [46, 52], [0, 1], clampOpts)}}>
                  <div style={{color: C.red, whiteSpace: 'pre'}}>  ⎿  5-hour limit reached ∙ resets <b style={{color: '#fff'}}>6:54pm</b></div>
                  <div style={{color: 'rgba(255,255,255,0.4)', whiteSpace: 'pre'}}>{'     '}/upgrade to increase your usage limit.</div>
                </div>
              )}
            </div>
          </MacWindow>
        </div>
        {f > 60 && <Headline text="Same wall. | Different agent." delay={60} size={v ? 112 : 100} accent={['Different', 'agent.']} accentColor={CLAY} />}
      </AbsoluteFill>
    </Backdrop>
  );
};

/** 2 · Refill, now with Claude Code. */
export const ClaudeLogo: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const s = usePop(0, {damping: 11, stiffness: 120, mass: 0.9});
  const ring = interpolate(f, [0, 40], [0, 1], {extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
  const chips = [['Codex', C.mint, 26], ['Claude Code', CLAY, 32]] as const;
  return (
    <Backdrop glow={CLAY}>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 40}}>
        <div style={{position: 'absolute', width: 900, height: 900, borderRadius: 450, border: `2px solid ${CLAY}`, opacity: (1 - ring) * 0.7, transform: `scale(${0.2 + ring * 1.2})`}} />
        <div style={{display: 'flex', flexDirection: v ? 'column' : 'row', alignItems: 'center', gap: v ? 30 : 44}}>
          <Img src={staticFile('icon.png')} style={{width: 230, height: 230, transform: `scale(${s}) rotate(${(1 - s) * -25}deg)`, filter: `drop-shadow(0 30px 80px ${C.green}88)`}} />
          <div style={{display: 'flex', flexDirection: 'column', alignItems: v ? 'center' : 'flex-start'}}>
            <div style={{fontSize: 170, fontWeight: 900, letterSpacing: -8, lineHeight: 1, opacity: ease(f, 6, 18)}}>Refill</div>
            <div style={{fontSize: 46, fontWeight: 700, color: C.dim, marginTop: 12, opacity: ease(f, 16, 28)}}>
              now tracks <span style={{color: CLAY}}>Claude Code</span> too.
            </div>
          </div>
        </div>
        <div style={{display: 'flex', gap: 18}}>
          {chips.map(([t, c, at]) => {
            const p = usePop(at);
            return (
              <div key={t} style={{display: 'flex', alignItems: 'center', gap: 12, fontSize: 32, fontWeight: 800, padding: '12px 26px', borderRadius: 40, background: `${c}1F`, border: `1.5px solid ${c}88`, color: c, opacity: p, transform: `scale(${0.8 + p * 0.2})`}}>
                ✓ {t}
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

/** 3 · Pointer clicks the menu bar item, camera zooms into the popover, then down to Claude Code. */
export const ClaudeZoom: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const {width: W, height: H} = useVideoConfig();
  const g = geo(v);
  const cx = g.left + g.w / 2;
  const claudeY = g.top + g.zoom * 418;       // centre of the Claude Code section inside the popover
  const keys: [number, Shot][] = v ? [
    [50, {s: 1, fx: W / 2, fy: H / 2, tx: W / 2, ty: H / 2}],
    [92, {s: 1.45, fx: cx, fy: g.top, tx: W / 2, ty: g.top * 1.45}],
    [140, {s: 1.45, fx: cx, fy: g.top, tx: W / 2, ty: g.top * 1.45}],
    [178, {s: 1.95, fx: cx, fy: claudeY, tx: W / 2, ty: 800}],
  ] : [
    [50, {s: 1, fx: W / 2, fy: H / 2, tx: W / 2, ty: H / 2}],
    [92, {s: 1.75, fx: cx, fy: g.top + g.h * 0.3, tx: 1350, ty: 470}],
    [140, {s: 1.75, fx: cx, fy: g.top + g.h * 0.3, tx: 1350, ty: 470}],
    [178, {s: 2.1, fx: cx, fy: claudeY, tx: 1350, ty: 560}],
  ];
  // pointer glides to the menu bar item and clicks
  const glide = interpolate(f, [4, 38], [0, 1], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
  const px = interpolate(glide, [0, 1], [W * 0.42, g.chip.x - 6]);
  const py = interpolate(glide, [0, 1], [H * 0.62, g.chip.y - 4]) - Math.sin(glide * Math.PI) * 60;
  const press = interpolate(f, [40, 43, 47], [0, 1, 0], clampOpts);
  const ripple = interpolate(f, [42, 62], [0, 1], clampOpts);
  const pop = usePop(45, {damping: 16, stiffness: 180, mass: 0.6});
  const barIn = ease(f, 52, 80);
  const glow = interpolate(f, [176, 186, 230, 250], [0, 1, 1, 0.6], clampOpts);
  const pointerOut = interpolate(f, [60, 72], [1, 0], clampOpts);
  return (
    <AbsoluteFill style={{overflow: 'hidden'}}>
      <AbsoluteFill style={camera(f, keys, W, H)}>
        <BlueDesktop vertical={v} chip={<Countdown v={v} />} chipActive={f > 42}>
          <div style={{position: 'absolute', left: g.chip.x - 40, top: g.chip.y - 40, width: 80, height: 80, borderRadius: 40,
            border: '3px solid rgba(255,255,255,0.9)', opacity: (1 - ripple) * (f > 42 ? 1 : 0), transform: `scale(${0.3 + ripple * 1.1})`}} />
          <div style={{position: 'absolute', zoom: g.zoom, left: g.left / g.zoom, top: g.top / g.zoom, opacity: pop,
            transform: `translateY(${(1 - pop) * -10}px) scale(${0.97 + pop * 0.03})`, transformOrigin: 'top center'}}>
            <DualPopover barIn={barIn} claudeGlow={glow} />
          </div>
          <div style={{position: 'absolute', left: px, top: py, opacity: pointerOut}}><Pointer size={v ? 34 : 26} press={press} /></div>
        </BlueDesktop>
      </AbsoluteFill>
      <AbsoluteFill style={{background: 'linear-gradient(180deg, transparent 62%, rgba(8,20,36,0.55) 100%)'}} />
      <Caption v={v} bottom={v ? 120 : 110}>
        {f < 150 ? <Headline text="Codex + Claude Code. | One click." delay={6} size={v ? 84 : 80} accent={['Claude', 'Code.']} accentColor={CLAY} style={{justifyContent: v ? 'center' : 'flex-start'}} />
          : <Headline text="Claude's 5-hour | and weekly, tracked." delay={152} size={v ? 84 : 80} accent={['5-hour', 'weekly,']} accentColor={CLAY} style={{justifyContent: v ? 'center' : 'flex-start'}} />}
      </Caption>
    </AbsoluteFill>
  );
};

/** 4 · Settings: one switch connects Claude Code. */
export const ClaudeConnect: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const gearPress = interpolate(f, [8, 12, 16], [0, 1, 0], clampOpts);
  const swap = ease(f, 16, 26);
  const settings = f >= 18;
  const claudeOn = interpolate(f, [44, 52], [0, 1], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
  const claudeFlash = interpolate(f, [42, 46, 80], [0, 1, 0], clampOpts);
  const listFlash = interpolate(f, [96, 100, 126], [0, 1, 0], clampOpts);
  const zoom = v ? 1.75 : 1.55;
  const pos: React.CSSProperties = v
    ? {zoom, top: 96 / zoom, left: (1080 - 340 * zoom) / 2 / zoom}
    : {zoom, top: 56 / zoom, left: (1920 - 340 * zoom - 170) / zoom};
  const lines = [
    [46, 'One switch connects it'],
    [70, 'Your status line keeps working'],
    [94, 'One "AI Limits" list for both'],
    [118, 'Switch off → fully restored'],
  ] as const;
  return (
    <AbsoluteFill>
      <BlueDesktop vertical={v} chip={<Countdown v={v} />} chipActive>
        <AbsoluteFill style={{background: `rgba(8,18,30,${0.3 * swap})`}} />
        <div style={{position: 'absolute', ...pos, opacity: settings ? 0.4 + swap * 0.6 : 1, transform: `translateY(${settings ? (1 - swap) * 8 : 0}px)`}}>
          {settings ? <SettingsPopover claudeOn={claudeOn} claudeFlash={claudeFlash} listFlash={listFlash} /> : <DualPopover gearPress={gearPress} />}
        </div>
        {v && <AbsoluteFill style={{background: 'linear-gradient(180deg, transparent 52%, rgba(8,20,36,0.92) 68%)'}} />}
        <AbsoluteFill style={{justifyContent: v ? 'flex-end' : 'center', alignItems: v ? 'center' : 'flex-start', padding: v ? '0 60px 110px' : '0 0 0 110px'}}>
          <div style={{maxWidth: v ? 960 : 760, textShadow: '0 4px 40px rgba(10,25,45,0.6)', display: 'flex', flexDirection: 'column', gap: v ? 30 : 40, alignItems: v ? 'center' : 'flex-start'}}>
            <Headline text="Connect in | one switch." delay={4} size={v ? 96 : 92} accent={['one', 'switch.']} accentColor={CLAY} style={{justifyContent: v ? 'center' : 'flex-start'}} />
            <div style={{display: 'flex', flexDirection: 'column', gap: 14, color: '#fff'}}>
              {lines.map(([at, t]) => {
                const p = ease(f, at - 4, at + 6);
                return (
                  <div key={t} style={{display: 'flex', alignItems: 'center', gap: 14, fontSize: v ? 40 : 36, fontWeight: 700, opacity: p, transform: `translateX(${(1 - p) * -24}px)`}}>
                    <div style={{width: 30, height: 30, borderRadius: 15, background: CLAY, color: '#2a1206', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, fontWeight: 900, flexShrink: 0}}>✓</div>{t}
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

const ROWS = [
  {title: 'Claude unblocked: 5-hour limit resets', when: 'Today, 6:54 PM', urgent: true, c: CLAY},
  {title: 'Codex 5-hour limit resets', when: 'Today, 8:02 PM', c: C.mint},
  {title: 'Claude weekly limit resets', when: 'Wed 21 Oct, 5:19 PM', c: CLAY},
  {title: 'Codex weekly limit resets', when: 'Sun 25 Oct, 2:13 AM', c: C.mint},
];

/** 5 · Everything in one Reminders list, and the ping. */
export const ClaudeReminders: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const win = usePop(0);
  const note = interpolate(f, [70, 84], [0, 1], {...clampOpts, easing: Easing.out(Easing.back(1.3))});
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: v ? 'column' : 'row', gap: v ? 80 : 90}}>
        {!v && (
          <div style={{width: 560}}>
            <Headline text="One list. | Every limit." delay={6} size={86} accent={['Every', 'limit.']} style={{justifyContent: 'flex-start'}} />
          </div>
        )}
        <div style={{transform: `scale(${(v ? 1.05 : 1) * (0.94 + win * 0.06)})`, opacity: win, position: 'relative'}}>
          <div style={{width: 960, height: 560, borderRadius: 20, overflow: 'hidden', display: 'flex', background: '#1C1E1F', border: '1px solid rgba(255,255,255,0.12)', boxShadow: '0 40px 120px rgba(0,0,0,0.55)'}}>
            <div style={{width: 250, background: '#232627', padding: '24px 18px', display: 'flex', flexDirection: 'column', gap: 10}}>
              <div style={{display: 'flex', gap: 8, marginBottom: 14}}>{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <div key={c} style={{width: 14, height: 14, borderRadius: 7, background: c}} />)}</div>
              <div style={{fontSize: 14, color: C.dim, fontWeight: 700, marginTop: 6}}>My Lists</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 10, fontSize: 18, padding: '6px 8px'}}><div style={{width: 24, height: 24, borderRadius: 12, background: '#0A84FF'}} />Reminders</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 10, fontSize: 18, padding: '6px 8px', background: 'rgba(255,255,255,0.12)', borderRadius: 8, fontWeight: 600}}><div style={{width: 24, height: 24, borderRadius: 12, background: C.green}} />AI Limits<span style={{marginLeft: 'auto', color: C.dim}}>4</span></div>
            </div>
            <div style={{flex: 1, padding: '30px 38px'}}>
              <div style={{fontSize: 44, fontWeight: 800, color: C.green, marginBottom: 4}}>AI Limits</div>
              {ROWS.map((r, i) => {
                const p = usePop(12 + i * 8);
                return (
                  <div key={r.title} style={{display: 'flex', gap: 16, padding: '15px 0', borderBottom: '1px solid rgba(255,255,255,0.08)', opacity: p, transform: `translateX(${(1 - p) * 40}px)`}}>
                    <div style={{width: 26, height: 26, borderRadius: 13, border: `2.5px solid ${C.green}`, marginTop: 3, flexShrink: 0}} />
                    <div style={{flex: 1}}>
                      <div style={{fontSize: 25, fontWeight: 600}}>{r.urgent && <span style={{color: C.green, fontWeight: 800}}>!!! </span>}{r.title}</div>
                      <div style={{fontSize: 20, color: C.dim, marginTop: 4, display: 'flex', alignItems: 'center', gap: 10}}>
                        <span style={{width: 9, height: 9, borderRadius: 5, background: r.c}} />{r.when} · <Bell size={16} color={C.dim} />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
          <div style={{position: 'absolute', top: v ? -150 : -60, right: v ? 20 : -60, opacity: note, transform: `translateY(${(1 - note) * -40}px) scale(${0.9 + note * 0.1})`}}>
            <Notification scale={v ? 1.15 : 1} title="Claude unblocked: 5-hour limit resets" body="Fresh limit at 6:54 PM. Go build." />
          </div>
        </div>
        {v && (
          <div style={{width: 960}}>
            <Headline text="One list. | Every limit." delay={6} size={116} accent={['Every', 'limit.']} />
          </div>
        )}
      </AbsoluteFill>
    </Backdrop>
  );
};

/** 6 · End card. */
export const ClaudeEnd: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const logo = usePop(0, {damping: 12, stiffness: 140, mass: 0.8});
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 26, zoom: v ? 1.3 : 1}}>
        <Img src={staticFile('icon.png')} style={{width: 200, height: 200, transform: `scale(${logo})`, filter: `drop-shadow(0 30px 80px ${C.green}88)`}} />
        <div style={{fontSize: 150, fontWeight: 900, letterSpacing: -7, lineHeight: 1, opacity: ease(f, 4, 14)}}>Refill</div>
        <div style={{fontSize: v ? 44 : 42, fontWeight: 600, color: C.dim, opacity: ease(f, 10, 22), textAlign: 'center', maxWidth: v ? 900 : 'none'}}>
          Never miss a <span style={{color: C.mint}}>Codex</span> or {v && <br />}<span style={{color: CLAY}}>Claude Code</span> limit reset.
        </div>
        <div style={{marginTop: 18, fontFamily: mono, fontSize: v ? 34 : 36, fontWeight: 600, padding: '16px 30px', borderRadius: 16, background: 'rgba(52,211,153,0.12)', border: `1px solid ${C.mint}55`, color: C.mint, opacity: ease(f, 18, 30)}}>
          github.com/fenil210-cactus/refill
        </div>
        <div style={{fontSize: 26, color: C.dim, marginTop: 6, opacity: ease(f, 26, 38), textAlign: 'center'}}>
          Free · Open source · macOS 13+{v ? <br /> : ' · '}Claude Code on Pro & Max plans
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

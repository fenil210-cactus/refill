import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';
import {Backdrop, Bell, Bolt, C, Headline, usePop, useVertical} from '../theme';

const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const ReminderRow: React.FC<{title: string; time: React.ReactNode; delay: number; urgent?: boolean}> = ({title, time, delay, urgent}) => {
  const p = usePop(delay);
  return (
    <div style={{display: 'flex', gap: 18, padding: '18px 0', borderBottom: '1px solid rgba(255,255,255,0.08)', opacity: p, transform: `translateX(${(1 - p) * 40}px)`}}>
      <div style={{width: 28, height: 28, borderRadius: 14, border: `2.5px solid ${C.green}`, marginTop: 3, flexShrink: 0}} />
      <div style={{flex: 1}}>
        <div style={{fontSize: 27, fontWeight: 600}}>{urgent && <span style={{color: C.green, fontWeight: 800}}>!!! </span>}{title}</div>
        <div style={{fontSize: 21, color: C.dim, marginTop: 6, display: 'flex', alignItems: 'center', gap: 10}}>{time}</div>
      </div>
    </div>
  );
};

/** 5 · Reminders list, then the reset moves and the reminder follows. */
export const Reminders: React.FC = () => {
  const f = useCurrentFrame();
  const v = useVertical();
  const move = interpolate(f, [92, 112], [0, 1], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
  const banner = usePop(80);
  const time = move < 0.5 ? '8:02 PM' : '6:30 PM';
  const glow = interpolate(f, [90, 98, 118, 150], [0, 1, 1, 0], clampOpts);
  const win = usePop(0);
  return (
    <Backdrop>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', flexDirection: v ? 'column' : 'row', gap: v ? 80 : 90}}>
        {!v && (
          <div style={{width: 640}}>
            {f < 86 ? <Headline text="Real Apple | Reminders. | Set for you." delay={6} size={80} accent={['Apple', 'Reminders.']} style={{justifyContent: 'flex-start'}} />
              : <Headline text="Reset moved? | So does your | reminder." delay={88} size={80} accent={['moved?', 'reminder.']} style={{justifyContent: 'flex-start'}} />}
          </div>
        )}
        <div style={{transform: `scale(${(v ? 0.95 : 1) * (0.94 + win * 0.06)})`, opacity: win, position: 'relative'}}>
          <div style={{width: 940, height: 560, borderRadius: 20, overflow: 'hidden', display: 'flex', background: '#1C1E1F', border: '1px solid rgba(255,255,255,0.12)', boxShadow: '0 40px 120px rgba(0,0,0,0.55)'}}>
            <div style={{width: 270, background: '#232627', padding: '24px 18px', display: 'flex', flexDirection: 'column', gap: 10}}>
              <div style={{display: 'flex', gap: 8, marginBottom: 14}}>{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <div key={c} style={{width: 14, height: 14, borderRadius: 7, background: c}} />)}</div>
              <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10}}>
                {[['Today', '#0A84FF', 1], ['Scheduled', '#FF453A', 2], ['All', '#8E8E93', 2], ['Flagged', '#FF9F0A', 0]].map(([t, c, n]) => (
                  <div key={t as string} style={{background: 'rgba(255,255,255,0.07)', borderRadius: 12, padding: 12}}>
                    <div style={{display: 'flex', justifyContent: 'space-between'}}><div style={{width: 26, height: 26, borderRadius: 13, background: c as string}} /><b style={{fontSize: 22}}>{n as number}</b></div>
                    <div style={{fontSize: 15, color: C.dim, marginTop: 6, fontWeight: 600}}>{t as string}</div>
                  </div>
                ))}
              </div>
              <div style={{fontSize: 14, color: C.dim, fontWeight: 700, marginTop: 16}}>My Lists</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 10, fontSize: 18, padding: '6px 8px'}}><div style={{width: 24, height: 24, borderRadius: 12, background: '#0A84FF'}} />Reminders</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 10, fontSize: 18, padding: '6px 8px', background: 'rgba(255,255,255,0.12)', borderRadius: 8, fontWeight: 600}}><div style={{width: 24, height: 24, borderRadius: 12, background: C.green}} />Codex Limits</div>
            </div>
            <div style={{flex: 1, padding: '34px 40px'}}>
              <div style={{fontSize: 46, fontWeight: 800, color: C.green}}>Codex Limits</div>
              <ReminderRow delay={16} urgent title="Codex unblocked: 5-hour limit resets"
                time={<><span style={{background: `rgba(52,211,153,${glow * 0.3})`, color: glow > 0.1 ? C.mint : C.dim, borderRadius: 6, padding: '0 6px', margin: '0 -6px', display: 'inline-block', transform: `translateY(${Math.sin(move * Math.PI) * -6}px)`}}>Today, {time}</span> · <Bell size={17} color={C.dim} /></>} />
              <ReminderRow delay={28} title="Codex weekly limit resets" time={<>Sun 25 Oct, 2:13 AM · <Bell size={17} color={C.dim} /></>} />
              <div style={{fontSize: 17, color: 'rgba(255,255,255,0.35)', marginTop: 20, opacity: interpolate(f, [40, 50], [0, 1], clampOpts)}}>Kept up to date by Refill</div>
            </div>
          </div>
          <div style={{position: 'absolute', top: -34, right: 40, background: C.amber, color: '#1a1206', fontWeight: 800, fontSize: 22, padding: '12px 22px', borderRadius: 30, boxShadow: '0 12px 40px rgba(255,181,71,0.45)', opacity: banner, transform: `scale(${banner}) rotate(${(1 - banner) * 8}deg)`, display: 'flex', gap: 8, alignItems: 'center'}}>
            <Bolt size={22} color="#1a1206" /> Limits reset early
          </div>
        </div>
        {v && (
          <div style={{width: 960}}>
            {f < 86 ? <Headline text="Real Apple Reminders. Set for you." delay={6} size={92} accent={['Apple', 'Reminders.']} />
              : <Headline text="Reset moved? So does your reminder." delay={88} size={92} accent={['moved?', 'reminder.']} />}
          </div>
        )}
      </AbsoluteFill>
    </Backdrop>
  );
};

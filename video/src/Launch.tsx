import React from 'react';
import {AbsoluteFill, Audio, interpolate, Sequence, staticFile, useCurrentFrame} from 'remotion';
import timeline from './timeline.json';
import {Hook, Late, Logo} from './scenes/Intro';
import {MenuBar, Settings} from './scenes/MenuScenes';
import {Reminders} from './scenes/Product';
import {Devices, Features, Install} from './scenes/Outro';

// Scene lengths live in timeline.json so scripts/music.mjs can cut the score to the same frames.
const SCENES: Record<string, React.FC> = {hook: Hook, late: Late, logo: Logo, menubar: MenuBar, settings: Settings,
  reminders: Reminders, devices: Devices, features: Features, install: Install};
const TIMELINE = timeline as [string, number][];
export const TOTAL = TIMELINE.reduce((a, [, d]) => a + d, 0);

/** Short crossfade + slight zoom between scenes. */
export const SceneWrap: React.FC<{dur: number; children: React.ReactNode; last: boolean}> = ({dur, children, last}) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [0, 6, dur - 6, dur], [0, 1, 1, last ? 1 : 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const s = interpolate(f, [0, 8], [1.03, 1], {extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{opacity: o, transform: `scale(${s})`}}>{children}</AbsoluteFill>;
};

export const Launch: React.FC = () => {
  let from = 0;
  return (
    <AbsoluteFill style={{background: '#07100C'}}>
      {TIMELINE.map(([name, dur], i) => {
        const start = from;
        from += dur;
        const Scene = SCENES[name];
        return (
          <Sequence key={name} from={start} durationInFrames={dur} name={name}>
            <SceneWrap dur={dur} last={i === TIMELINE.length - 1}><Scene /></SceneWrap>
          </Sequence>
        );
      })}
      <Audio src={staticFile('music.wav')} />
    </AbsoluteFill>
  );
};

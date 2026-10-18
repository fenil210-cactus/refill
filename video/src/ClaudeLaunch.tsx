import React from 'react';
import {AbsoluteFill, Audio, Sequence, staticFile} from 'remotion';
import timeline from './timeline-claude.json';
import {SceneWrap} from './Launch';
import {ClaudeConnect, ClaudeEnd, ClaudeHook, ClaudeLogo, ClaudeReminders, ClaudeZoom} from './scenes/Claude';

// Claude Code launch cut. Scene lengths live in timeline-claude.json, shared with scripts/music-claude.mjs.
const SCENES: Record<string, React.FC> = {chook: ClaudeHook, clogo: ClaudeLogo, czoom: ClaudeZoom, cconnect: ClaudeConnect,
  creminders: ClaudeReminders, cend: ClaudeEnd};
const TIMELINE = timeline as [string, number][];
export const CLAUDE_TOTAL = TIMELINE.reduce((a, [, d]) => a + d, 0);

export const ClaudeLaunch: React.FC = () => {
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
      <Audio src={staticFile('music-claude.wav')} />
    </AbsoluteFill>
  );
};

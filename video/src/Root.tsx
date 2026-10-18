import React from 'react';
import {Composition} from 'remotion';
import {Launch, TOTAL} from './Launch';

export const Root: React.FC = () => (
  <>
    <Composition id="Launch" component={Launch} durationInFrames={TOTAL} fps={30} width={1920} height={1080} />
    <Composition id="LaunchVertical" component={Launch} durationInFrames={TOTAL} fps={30} width={1080} height={1920} />
  </>
);

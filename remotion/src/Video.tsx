import { Audio, staticFile } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { wipe } from "@remotion/transitions/wipe";
import { clockWipe } from "@remotion/transitions/clock-wipe";
import React from "react";
import { Scene1Kinetic } from "./scenes/Scene1Kinetic";
import { Scene2Glass } from "./scenes/Scene2Glass";
import { Scene3DataViz } from "./scenes/Scene3DataViz";
import { Scene4Depth } from "./scenes/Scene4Depth";
import { Scene5Collage } from "./scenes/Scene5Collage";
import { Scene6Outro } from "./scenes/Scene6Outro";

export type VideoProps = {
  withVoiceover?: boolean;
};

const timing = linearTiming({ durationInFrames: 12 });
const sceneDuration = 310;

const audioPath = (sceneId: string) => `audio/solanaanz/solanaanz-${sceneId}.mp3`;

export const Video: React.FC<VideoProps> = ({ withVoiceover = false }) => {
  return (
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene1"))} />}
        <Scene1Kinetic />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: "from-right" })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene2"))} />}
        <Scene2Glass />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={wipe({ direction: "from-top" })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene3"))} />}
        <Scene3DataViz />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene4"))} />}
        <Scene4Depth />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: "from-bottom" })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene5"))} />}
        <Scene5Collage />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={clockWipe()} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={sceneDuration}>
        {withVoiceover && <Audio src={staticFile(audioPath("scene6"))} />}
        <Scene6Outro />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};

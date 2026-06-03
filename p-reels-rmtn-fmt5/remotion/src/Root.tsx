import React from "react";
import { Composition } from "remotion";
import { loadFont as loadOswald } from "@remotion/google-fonts/Oswald";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
import { ReelBg, totalFrames, type ReelBgProps } from "./ReelBg";
import { fps } from "./theme";

loadOswald();
loadInter();
loadMono();

// Default props = a tiny self-test so `remotion studio` and a no-props render
// still show something. Real renders pass --props with the Opus-planned scenes.
const defaultProps: ReelBgProps = {
  scenes: [
    { type: "hook", durationInFrames: 60, eyebrow: "MR GROWTH GUIDE", title: "DATA-DRIVEN", accent: "REEL" },
    {
      type: "typing",
      durationInFrames: 150,
      label: "claude.ai",
      text: "Research this person from their LinkedIn bio. Find one real thing they did recently. Write a two-sentence opener.",
    },
    { type: "text", durationInFrames: 60, eyebrow: "DAY 13 / 100", title: "COMMENT", accent: "EMAILPRO" },
  ],
};

export const Root: React.FC = () => (
  <Composition
    id="ReelBg"
    component={ReelBg}
    durationInFrames={totalFrames(defaultProps.scenes)}
    fps={fps}
    width={1080}
    height={1920}
    defaultProps={defaultProps}
    calculateMetadata={({ props }) => ({
      durationInFrames: totalFrames((props as ReelBgProps).scenes ?? defaultProps.scenes),
    })}
  />
);

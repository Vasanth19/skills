import React from "react";
import { CalculateMetadataFunction, Composition } from "remotion";
import { TopicBroll } from "./TopicBroll";
import { FPS, HEIGHT, TopicBrollProps, WIDTH, topicBrollSchema } from "./schema";

// Derive total duration from the beat plan (sum of each beat's durationInFrames).
const calculateMetadata: CalculateMetadataFunction<TopicBrollProps> = ({
  props,
}) => {
  const total = props.beats.reduce(
    (sum, b) => sum + (b.durationInFrames || 90),
    0,
  );
  return {
    durationInFrames: Math.max(total, 1),
  };
};

const sampleProps: TopicBrollProps = {
  beats: [
    {
      text: "I automated my busiest workflow",
      keywords: ["automation", "workflow"],
      durationInFrames: 90,
    },
    {
      text: "Then the leads doubled in 30 days",
      keywords: ["leads", "growth", "30 days"],
      durationInFrames: 90,
    },
    {
      text: "Here's the exact system I used",
      keywords: ["system", "playbook"],
      durationInFrames: 90,
    },
  ],
  bgColor: "#0F172A",
  accentColor: "#38BDF8",
  textColor: "#F8FAFC",
  brandLabel: "MR GROWTH GUIDE",
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="TopicBroll"
      component={TopicBroll}
      schema={topicBrollSchema}
      fps={FPS}
      width={WIDTH}
      height={HEIGHT}
      durationInFrames={270}
      defaultProps={sampleProps}
      calculateMetadata={calculateMetadata}
    />
  );
};

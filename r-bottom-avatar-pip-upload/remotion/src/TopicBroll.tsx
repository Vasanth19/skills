import React from "react";
import {
  AbsoluteFill,
  Easing,
  Series,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import {
  Beat,
  HEIGHT,
  SAFE_BOTTOM,
  TopicBrollProps,
  WIDTH,
} from "./schema";

const FONT_STACK =
  '"SF Pro Display", "Helvetica Neue", Inter, system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif';

/** Animated dark-navy background: base color + drifting radial glows + faint grid.
 *  No fade-from-black: it is fully painted at frame 0. */
const Background: React.FC<{
  bgColor: string;
  accentColor: string;
}> = ({ bgColor, accentColor }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Slow continuous drift for the two glows (loops over the whole comp).
  const t = frame / Math.max(durationInFrames, 1);
  const glowAX = interpolate(t, [0, 1], [18, 38]);
  const glowAY = interpolate(t, [0, 1], [24, 14]);
  const glowBX = interpolate(t, [0, 1], [82, 64]);
  const glowBY = interpolate(t, [0, 1], [10, 30]);

  return (
    <AbsoluteFill style={{ backgroundColor: bgColor }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(60% 40% at ${glowAX}% ${glowAY}%, ${hexA(
            accentColor,
            0.28,
          )} 0%, transparent 60%), radial-gradient(55% 38% at ${glowBX}% ${glowBY}%, ${hexA(
            "#7C3AED",
            0.22,
          )} 0%, transparent 60%)`,
        }}
      />
      {/* faint grid for a "growth / dashboard" feel */}
      <AbsoluteFill
        style={{
          backgroundImage: `linear-gradient(${hexA(
            "#FFFFFF",
            0.04,
          )} 1px, transparent 1px), linear-gradient(90deg, ${hexA(
            "#FFFFFF",
            0.04,
          )} 1px, transparent 1px)`,
          backgroundSize: "90px 90px",
          maskImage:
            "linear-gradient(to bottom, black 0%, black 55%, transparent 85%)",
          WebkitMaskImage:
            "linear-gradient(to bottom, black 0%, black 55%, transparent 85%)",
        }}
      />
      {/* darken the bottom PIP zone so the avatar reads cleanly */}
      <AbsoluteFill
        style={{
          background: `linear-gradient(to bottom, transparent ${
            (SAFE_BOTTOM / HEIGHT) * 100 - 8
          }%, ${hexA(bgColor, 0.85)} 100%)`,
        }}
      />
    </AbsoluteFill>
  );
};

/** One beat: a kicker line, a big animated headline, keyword chips, and a moving accent bar.
 *  All content lives in the top safe zone (y < SAFE_BOTTOM). */
const BeatScene: React.FC<{
  beat: Beat;
  index: number;
  accentColor: string;
  textColor: string;
}> = ({ beat, index, accentColor, textColor }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Headline enter (crisp UI deceleration) — starts at ~30% by frame 0 so something
  // is visible immediately even on the very first beat at frame 0.
  const enter = interpolate(frame, [0, 18], [0.35, 1], {
    easing: Easing.bezier(0.16, 1, 0.3, 1),
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Exit near the end of the beat.
  const exit = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    {
      easing: Easing.in(Easing.cubic),
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    },
  );
  const vis = Math.min(enter, exit);

  const headlineY = interpolate(enter, [0.35, 1], [40, 0]);
  const accentWidth = interpolate(frame, [4, 34], [0, 220], {
    easing: Easing.bezier(0.16, 1, 0.3, 1),
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        // Confine everything to the top safe zone.
        height: SAFE_BOTTOM,
        padding: "0 90px",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "flex-start",
        opacity: vis,
      }}
    >
      {/* kicker */}
      <div
        style={{
          fontFamily: FONT_STACK,
          fontSize: 34,
          fontWeight: 700,
          letterSpacing: 6,
          textTransform: "uppercase",
          color: accentColor,
          opacity: interpolate(frame, [2, 16], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          transform: `translateY(${interpolate(enter, [0.35, 1], [16, 0])}px)`,
          marginBottom: 28,
        }}
      >
        {String(index + 1).padStart(2, "0")} ·{" "}
        {beat.keywords[0] ?? "the play"}
      </div>

      {/* animated accent bar under kicker */}
      <div
        style={{
          width: accentWidth,
          height: 8,
          borderRadius: 4,
          background: accentColor,
          marginBottom: 40,
          boxShadow: `0 0 30px ${hexA(accentColor, 0.6)}`,
        }}
      />

      {/* big headline */}
      <div
        style={{
          fontFamily: FONT_STACK,
          fontSize: 104,
          lineHeight: 1.04,
          fontWeight: 800,
          color: textColor,
          letterSpacing: -1.5,
          transform: `translateY(${headlineY}px)`,
          textShadow: "0 8px 40px rgba(0,0,0,0.45)",
          maxWidth: 880,
        }}
      >
        {beat.text}
      </div>

      {/* keyword chips */}
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 20,
          marginTop: 56,
        }}
      >
        {beat.keywords.map((kw, i) => {
          const chipIn = interpolate(
            frame,
            [20 + i * 6, 36 + i * 6],
            [0, 1],
            {
              easing: Easing.bezier(0.34, 1.56, 0.64, 1),
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            },
          );
          return (
            <div
              key={kw + i}
              style={{
                fontFamily: FONT_STACK,
                fontSize: 38,
                fontWeight: 600,
                color: textColor,
                padding: "18px 32px",
                borderRadius: 999,
                border: `2px solid ${hexA(accentColor, 0.55)}`,
                background: hexA(accentColor, 0.1),
                transform: `scale(${interpolate(chipIn, [0, 1], [0.6, 1])})`,
                opacity: chipIn,
              }}
            >
              #{kw}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

export const TopicBroll: React.FC<TopicBrollProps> = ({
  beats,
  bgColor,
  accentColor,
  textColor,
  brandLabel,
}) => {
  return (
    <AbsoluteFill style={{ backgroundColor: bgColor }}>
      <Background bgColor={bgColor} accentColor={accentColor} />

      <Series>
        {beats.map((beat, i) => (
          <Series.Sequence
            key={i}
            durationInFrames={beat.durationInFrames}
            premountFor={15}
          >
            <BeatScene
              beat={beat}
              index={i}
              accentColor={accentColor}
              textColor={textColor}
            />
          </Series.Sequence>
        ))}
      </Series>

      {/* persistent brand label, kept inside the safe zone */}
      <AbsoluteFill
        style={{
          height: SAFE_BOTTOM,
          justifyContent: "flex-start",
          alignItems: "center",
          paddingTop: 120,
        }}
      >
        <div
          style={{
            fontFamily: FONT_STACK,
            fontSize: 30,
            fontWeight: 700,
            letterSpacing: 8,
            color: hexA(textColor, 0.55),
          }}
        >
          {brandLabel}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** Turn #RRGGBB into an rgba() string at the given alpha. */
function hexA(hex: string, alpha: number): string {
  const h = hex.replace("#", "");
  const full =
    h.length === 3
      ? h
          .split("")
          .map((c) => c + c)
          .join("")
      : h;
  const r = parseInt(full.slice(0, 2), 16);
  const g = parseInt(full.slice(2, 4), 16);
  const b = parseInt(full.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// Re-export for the Root to use in dimensions.
export { WIDTH, HEIGHT };

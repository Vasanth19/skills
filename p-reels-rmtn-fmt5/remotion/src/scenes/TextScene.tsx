import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring } from "remotion";
import { baseTheme, type Theme } from "../theme";

// text — generic title beat (eyebrow + headline + accent). The default/fallback
// scene. Content in the top half so the bottom-left PIP never covers it.
export const TextScene: React.FC<{
  eyebrow?: string;
  title?: string;
  accent?: string;
  theme?: Theme;
}> = ({ eyebrow = "", title = "", accent = "", theme = baseTheme }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const ti = spring({ frame, fps, config: { damping: 16 }, durationInFrames: 16 });
  const ac = spring({ frame: frame - 10, fps, config: { damping: 12 }, durationInFrames: 16 });

  return (
    <AbsoluteFill style={{ background: theme.bgNavy }}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle at 50% 44%, ${theme.accent}1a 0%, transparent 60%)` }} />
      <div style={{ position: "absolute", top: 200, left: 72, right: 72 }}>
        {eyebrow ? (
          <div style={{ opacity: ti, color: theme.accent, fontFamily: theme.fontMono, fontWeight: 700, fontSize: 30, letterSpacing: 6, textTransform: "uppercase", marginBottom: 26 }}>
            — {eyebrow}
          </div>
        ) : null}
        <div style={{ opacity: ti, transform: `translateY(${(1 - ti) * 26}px)`, color: theme.textWhite, fontFamily: theme.fontHeading, fontWeight: 900, fontSize: 118, lineHeight: 0.92, letterSpacing: -2, textTransform: "uppercase" }}>
          {title}{" "}
          {accent ? <span style={{ color: theme.accent, textShadow: `0 0 30px ${theme.accent}66` }}>{accent}</span> : null}
        </div>
      </div>
    </AbsoluteFill>
  );
};

import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate } from "remotion";
import { baseTheme, type Theme } from "../theme";

// hook — big eyebrow + headline + accent word. Content lives in the TOP half so
// the bottom-left PIP (composited later) never covers it. All text from props.
export const HookScene: React.FC<{
  eyebrow?: string;
  title?: string;
  accent?: string;
  theme?: Theme;
}> = ({ eyebrow = "", title = "", accent = "", theme = baseTheme }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const eb = spring({ frame, fps, config: { damping: 14 }, durationInFrames: 14 });
  const ti = spring({ frame: frame - 8, fps, config: { damping: 16 }, durationInFrames: 16 });
  const ac = spring({ frame: frame - 18, fps, config: { damping: 12 }, durationInFrames: 16 });
  const glow = 0.5 + 0.18 * Math.sin((frame / fps) * Math.PI);

  return (
    <AbsoluteFill style={{ background: theme.bgNavy }}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle at 38% 42%, ${theme.accent}${Math.round(glow * 40).toString(16).padStart(2, "0")} 0%, transparent 58%)` }} />
      <div style={{ position: "absolute", top: 150, left: 72, right: 72 }}>
        <div style={{ opacity: eb, transform: `translateY(${(1 - eb) * 24}px)`, color: theme.accent, fontFamily: theme.fontMono, fontWeight: 700, fontSize: 30, letterSpacing: 6, textTransform: "uppercase" }}>
          — {eyebrow}
        </div>
        <div style={{ marginTop: 28, opacity: ti, transform: `translateY(${(1 - ti) * 30}px)`, color: theme.textWhite, fontFamily: theme.fontHeading, fontWeight: 900, fontSize: 112, lineHeight: 0.92, letterSpacing: -2, textTransform: "uppercase" }}>
          {title}
        </div>
        {accent ? (
          <div style={{ marginTop: 6, opacity: ac, transform: `translateY(${(1 - ac) * 30}px)`, color: theme.accent, fontFamily: theme.fontHeading, fontWeight: 900, fontSize: 112, lineHeight: 0.92, letterSpacing: -2, textTransform: "uppercase", textShadow: `0 0 30px ${theme.accent}66` }}>
            {accent}
          </div>
        ) : null}
      </div>
    </AbsoluteFill>
  );
};

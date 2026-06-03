import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate } from "remotion";
import { baseTheme, type Theme } from "../theme";

// typing — a UI/terminal card that TYPES `text` out char-by-char with a blinking
// caret (the day13 "interactive" look). All content from props; the card sits in
// the top ~55% so the bottom-left PIP never covers it.
export const TypingScene: React.FC<{
  label?: string; // window label, e.g. "claude.ai" or "Terminal"
  text?: string; // the prompt/command typed out
  theme?: Theme;
}> = ({ label = "claude.ai", text = "", theme = baseTheme }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const cardEnter = spring({ frame, fps, config: { damping: 15 }, durationInFrames: 16 });
  // Type across the middle ~70% of the scene; settle before it ends.
  const typeStart = 12;
  const typeEnd = Math.max(typeStart + 8, Math.round(durationInFrames * 0.82));
  const typed = Math.round(interpolate(frame, [typeStart, typeEnd], [0, text.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));
  const shown = text.slice(0, typed);
  const caretOn = Math.floor(frame / 9) % 2 === 0;
  const done = typed >= text.length;

  return (
    <AbsoluteFill style={{ background: theme.bgNavy }}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle at 50% 40%, ${theme.accent}1a 0%, transparent 60%)` }} />
      <div
        style={{
          position: "absolute",
          top: 220,
          left: 72,
          right: 72,
          opacity: cardEnter,
          transform: `translateY(${(1 - cardEnter) * 28}px) scale(${0.97 + 0.03 * cardEnter})`,
          background: theme.bgCard,
          border: `1px solid ${theme.bgCardBorder}`,
          borderRadius: 28,
          boxShadow: `0 30px 80px #00000066`,
          overflow: "hidden",
        }}
      >
        {/* window chrome */}
        <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "26px 30px", borderBottom: `1px solid ${theme.bgCardBorder}` }}>
          <span style={{ width: 16, height: 16, borderRadius: 8, background: "#EF4444" }} />
          <span style={{ width: 16, height: 16, borderRadius: 8, background: "#F59E0B" }} />
          <span style={{ width: 16, height: 16, borderRadius: 8, background: "#22C55E" }} />
          <span style={{ marginLeft: 14, color: theme.textMuted, fontFamily: theme.fontMono, fontSize: 26, letterSpacing: 1 }}>{label}</span>
        </div>
        {/* typed body */}
        <div style={{ padding: "40px 40px 56px", minHeight: 360 }}>
          <span style={{ color: theme.textWhite, fontFamily: theme.fontMono, fontWeight: 500, fontSize: 46, lineHeight: 1.45, whiteSpace: "pre-wrap" }}>
            {shown}
            <span style={{ opacity: caretOn && !done ? 1 : done ? (caretOn ? 1 : 0) : 0, color: theme.accent }}>▌</span>
          </span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

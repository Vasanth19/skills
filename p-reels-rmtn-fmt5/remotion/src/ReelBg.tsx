import React from "react";
import { AbsoluteFill, Series } from "remotion";
import { baseTheme, type Theme } from "./theme";
import { HookScene } from "./scenes/HookScene";
import { TypingScene } from "./scenes/TypingScene";
import { TextScene } from "./scenes/TextScene";

// ── The data-driven contract (Opus fills this; kimi passes it via --props) ──
// Each scene = { type, durationInFrames, ...sceneProps }. Add a scene type by
// adding a parameterized component + one line in REGISTRY — never by authoring
// per-render code.
export type SceneSpec = {
  type: "hook" | "typing" | "text";
  durationInFrames: number;
  // free-form per-scene props (validated/typed inside each scene component)
  [k: string]: unknown;
};

export type ReelBgProps = {
  scenes: SceneSpec[];
  theme?: Partial<Theme>;
};

const REGISTRY: Record<SceneSpec["type"], React.FC<any>> = {
  hook: HookScene,
  typing: TypingScene,
  text: TextScene,
};

export const ReelBg: React.FC<ReelBgProps> = ({ scenes = [], theme: themeOverride }) => {
  const theme = { ...baseTheme, ...(themeOverride ?? {}) };
  return (
    <AbsoluteFill style={{ background: theme.bgNavy, fontFamily: theme.fontBody, overflow: "hidden" }}>
      <Series>
        {scenes.map((s, i) => {
          const Comp = REGISTRY[s.type] ?? TextScene;
          return (
            <Series.Sequence key={i} durationInFrames={Math.max(1, Math.round(s.durationInFrames))}>
              <Comp {...s} theme={theme} />
            </Series.Sequence>
          );
        })}
      </Series>
    </AbsoluteFill>
  );
};

// Total duration helper for calculateMetadata.
export const totalFrames = (scenes: SceneSpec[]): number =>
  Math.max(1, scenes.reduce((n, s) => n + Math.max(1, Math.round(s.durationInFrames)), 0));

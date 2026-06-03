// MGG canonical theme (matches day13 + the HyperFrames fmt5 template).
// Override via props.theme to re-brand without touching scene code.
export const baseTheme = {
  bgNavy: "#0F172A",
  bgCard: "#1E293B",
  bgCardBorder: "#334155",
  accent: "#F97316", // orange
  accentDim: "#C2410C",
  textWhite: "#F8FAFC",
  textMuted: "#94A3B8",
  textDim: "#64748B",
  ok: "#22C55E",
  fontHeading: "'Oswald', system-ui, sans-serif",
  fontBody: "'Inter', system-ui, sans-serif",
  fontMono: "'JetBrains Mono', 'SF Mono', Menlo, monospace",
} as const;

export type Theme = typeof baseTheme;
export const fps = 30;

// PIP safe zone: the bottom-left card (≈ x:80–504, y:1300–1860 on 1080×1920).
// Scenes keep their primary content in the TOP ~55% so the talking-head PIP
// (composited later, bottom-left) never covers the words. Mirrors fmt5.
export const SAFE_TOP = 0;
export const SAFE_BOTTOM = 1040; // content stays above this y

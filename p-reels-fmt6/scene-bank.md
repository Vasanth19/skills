# Scene Bank — p-reels-fmt6

7 reusable Remotion scenes. Lives in R3's `gfx/remotion/src/scenes/`. Copy and modify the copy — keep the animation rig.

---

## Scene Catalogue

### SceneHook
3-line text hook, 3 color bands (coral/violet/teal), background glow. **Timing:** ~80f (2.7s). Don't use this as the cover frame — abstract text doesn't show the "money shot."

### SceneClaudeUiIdle
Empty Claude shell with "How can I help you today?" + input bar with blinking caret. **Timing:** ~60f (2.0s). Creates anticipation before the prompt appears.

### ScenePromptReveal
Full-frame Claude UI. Prompt text typewriters in monospace font. **Timing scales linearly** to character count × frame window. Always in **Claude AI purple/violet** border to distinguish from Response.

### SceneResponseReveal
Claude response card (green border to distinguish from PromptReveal violet) + email-style line-by-line render + 3 callout pills that slide in post-render. **Timing:** ~270f (9.0s). The callout pills are the "proof layer" — make them specific (numbers, outcomes, not vague claims).

### SceneProof
Big dollar/metric number + "before → after" timeline pill (Tuesday→Friday, Before→After, etc.). **Timing:** ~145f (4.8s). Use the actual result from the production, not placeholder text.

### SceneCta
Comment mock with CTA keyword typing yellow on dark + DM notification card. **Timing:** ~195f (6.5s). CTA keyword should be 1-2 words max — drives comment DMs.

### SceneDayCount
"DAY N / 100 · X to go · @handle" — same visual rig across all MGG reels. **Timing:** ~60f (2.0s). Swap N and days-remaining per order.

---

## Frame Budget Template

For a given VO duration, allocate frames ensuring Total ≥ VO × 30fps (±30f margin is fine):

```
Total frames = VO_seconds × 30
SceneHook:         80f
SceneClaudeUiIdle: 60f
ScenePromptReveal: (char_count × N)f  -- scale to fit
SceneResponseReveal: 270f
SceneProof:        145f
SceneCta:          195f
SceneDayCount:     60f
```

Adjust `ScenePromptReveal` and/or `SceneResponseReveal` to hit the target total.

---

## First Run — Remotion Template

Copy the most recent `p-reels-fmt6` order's `gfx/remotion/` as a starting scaffold. Then:

```bash
cd <new-order>/gfx/remotion
rm -rf node_modules
npm install  # NOT pnpm — pnpm node_modules don't survive cp -r
```

Verify Chrome for Testing is installed: `npx remotion install-browser` (once per machine).

## Post-mortem Pointer

Every production using this recipe should drop a `production: ord-<id>` drawer into the `mr-growth-guide` MemPalace room noting: final duration, speed multiplier used, any deviations from the 7-scene bank, and whether the lead-magnet dependency was resolved before CMO ship.

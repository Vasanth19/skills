# p_instructions — authoring the Konva (Canvas-2D) overlay beats

> How to drive the `p-reels-split-2d` top-half overlay. This is the prompt/authoring
> method behind the manthan/Konva look. The renderer (`renderer/render-overlay.mjs`)
> consumes a beats JSON; this file is how you *think* your way to those beats.

## The method (do NOT write one giant prompt)

1. **Describe the screen, then the motion — in plain language.** Say what the frame IS
   (a dark chat UI, a pricing plate, a terminal card), then what MOVES and in what order.
2. **Refine beat by beat.** Build one moment, watch it, adjust, then add the next. The
   smoothness comes from this iterative loop, not from one perfect prompt.
3. **Be specific about the motion *feel*** — this is the whole trick:
   - the easing/physics: **spring**, ease-out, ease-in, settle/overshoot
   - **what enters when**: "fade in the title, THEN pop the card, THEN cascade the bullets"
   - **no hard cuts** — elements transition; the scene flows
   - **hold the final frame** — let the last state breathe before the beat ends
4. **Let the Konva.js layer generate the animation.** You specify intent + timing + feel;
   the renderer produces the spring/cascade/fade. Don't hand-keyframe pixels.
5. **Generate → watch it back → tweak ONCE.** One refinement pass per beat is the norm.

## Worked example (verbatim — a GEO-series beat: an AI assistant citing a top-pick tool)

> "New part for the series, 1920x1080. Build a dark chat UI. User asks 'What's the best
> 3D animation software?' Then the assistant answers: fade in 'Here are the top 3D
> animation tools right now', then pop in a highlighted top-pick card with a logo, name
> and one-line description on a green-bordered plate, then cascade three runner-up bullets
> below it. Smooth, physics-based motion, spring on the card, no hard cuts. Hold the final
> frame."

Notice what makes it work:
- **The screen is named** ("dark chat UI") before any motion.
- **Enter order is explicit**: title fade → card pop → bullets cascade.
- **The feel is named**: "physics-based, spring on the card, no hard cuts, hold the final frame."
- **It's one beat**, not the whole reel — the next beat is described separately and refined on its own.

## Mapping a plain-language beat → the renderer's beat JSON

When you've described a beat like the above, translate it into the beat schema
(`renderer/beat-schema.md`):
- the **screen** → the beat `type` + container (chat-ui / plate / card / terminal) + `props`
- **enter order** → per-element `anim` envelopes with staggered `start` offsets
- **feel** → the envelope kind (`spring` / `pop` / `fade` / `slide` / `cascade`) + easing
- **hold the final frame** → the beat's tail holds the end-state (idle bob/breathe optional)

## House rules (for this format)
- 9:16 reel: the overlay canvas is the **top half (1080×960)**, content `cy ≤ 900` (manthan's
  zone constraint) — the bottom half is the face cam. (manthan authored at full 1920×1080 for a
  landscape series; here the same look is constrained to the top zone.)
- Pills + paired visuals: ~60% custom illustration, ~25% emoji, ~15% logo/mascot.
- Brand palette + fonts (pass `--font` to the renderer — node-canvas falls back to a bitmap
  trap on Linux without it).

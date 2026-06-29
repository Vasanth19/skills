---
name: p-snap-bg-swap
description: Finger-snap background swap reel pipeline. Detects snap points in audio, composites the avatar on alternating backgrounds, and assembles a viral snap-transition format short.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-video]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
providers: kie
produces:
  dish: Snap BG-Swap Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [source_video]
dependsOn: [c-ai-media, c-production, c-ffmpeg, c-shorts-qa-gate, c-eval-runner]
---

# pipeline-snap-bg-swap — Snap Background Swap Reel


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Viral format: avatar snaps fingers → background changes. Each snap = new scene.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| source_video | Yes | — | Green-screen avatar video with snap audio |
| bg_images | No | — | Array of background image paths (auto-generated if empty) |
| num_snaps | No | auto-detect | Override snap count |
| format | No | `9:16` | `9:16` or `16:9` |

## Steps

### Step 1 — Snap Detection ⛔ CHECKPOINT

→ Skill: `c-production` → snap point detection
→ Audio peak analysis (RMS threshold 0.7, min gap 0.5s, 50ms chunks)
→ Returns list of timestamps (seconds)
→ Output: `interim/broll-plan/snap-points.json`

**Gate: User verifies snap count and timestamps. Adjust threshold if too many/few detected.**

### Step 2 — Background Selection ⛔ CHECKPOINT

If `$bg_images` provided: use them.
If not:
→ Skill: `c-ai-media` → generate `num_snaps + 1` contextual backgrounds
→ Each bg: different color palette / scene / mood
→ Brand-consistent style from `brand-ref.md`
→ Output: `interim/broll/gfx/bg-{N}.png`

**Gate: User approves backgrounds.**

### Step 3 — Segment Composite

For each snap interval (snap[N] to snap[N+1]):
→ Skill: `c-ffmpeg` → colorkey composite
→ Two-pass: `colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`
→ Overlay avatar on `bg-{N}.png`
→ Trim to interval duration
→ Output: `interim/video/compositing/seg-{N}.mp4`

Final segment: snap[last] to end of video → `bg-{N+1}.png`

### Step 4 — Concat

→ Skill: `c-ffmpeg` → concat all segments (codec copy if same params)
→ Output: `video/compositing/snap-bg-swap-v1.mp4`

### Step 5 — Verify

→ ffprobe verify → confirm dimensions, duration, codec

### QA gate (MANDATORY — run before upload)

Run the shared eval engine (`c-eval-runner`) on the final MP4 before delivery.
It reads this recipe's `acceptance.json`, delegates the mechanical gate to `c-shorts-qa-gate`,
runs geometry and luma checks, and writes a structured `scorecard.json`.
**Do NOT deliver if it exits non-zero (verdict FAIL).**

```bash
SKILL_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" /Users/vasanth/Code/skills -maxdepth 5 -type d -name p-snap-bg-swap 2>/dev/null | head -1)
bash .hub/c-eval-runner/scripts/eval-run.sh <FINAL_MP4> --recipe-dir "$SKILL_DIR" --brand "$BRAND_SLUG"
# scorecard → <video_dir>/eval/scorecard.json ; frame sweep → <video_dir>/eval/
```

Replace `<FINAL_MP4>` with the final portrait output (e.g. `final/pr-snap01-<name>.mp4`).
Note: this gate targets the default `format=9:16` output. If `format=16:9` was used, the `dims`
check will FAIL — this is intentional (landscape output requires a separate landscape spec).

- **HARD** (verdict FAIL, exit 1, blocks delivery): mechanical gate (loudness ≈ -14 LUFS,
  frame-0 brightness, resolution/fps, audio present), duration 27–63s, canvas exactly 1080×1920,
  center zone not dark at 6 sampled points (catches failed composite segments).
- **PERCEPTUAL** (verdict NEEDS_VISION until resolved): snap-sync accuracy, greenscreen
  cleanliness, avatar visibility on each background, background distinctness, cover money-shot —
  emitted as PENDING with a frame sweep; resolve with a vision pass before delivery.

**Interim gate (fail-fast, recommended after Step 4):**
```bash
bash .hub/c-eval-runner/scripts/eval-run.sh video/compositing/snap-bg-swap-v1.mp4 --recipe-dir "$SKILL_DIR" --step snapconcat
```

### Step 6 — Delivery ⛔ CHECKPOINT

→ `final/pr-snap01-{desc}.mp4` (portrait) or `final/ls-snap01-{desc}.mp4` (landscape)
**Gate: User reviews snap transitions.**

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.


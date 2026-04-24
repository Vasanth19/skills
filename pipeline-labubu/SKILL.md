---
name: pipeline-labubu
description: Labubu/plush character animated short pipeline (CC Tiny Tales style). Generates character-consistent scene images, animates with Hailuo i2v, assembles with music. Requires rigorous character-lock audit — 6/6 visual attributes must be locked before any generation.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [story-concept]"
allowed-tools: Bash, Read, Write
---

# pipeline-labubu — Plush Character Animated Short

Character-lock → story arc → scene images → Hailuo animation → assembled short.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| story_concept | Yes | — | Story brief |
| character_description | Yes | — | Full 6-attribute character description |
| audio_track | Yes | — | Path to background music |
| num_scenes | No | `5` | Number of scenes |

## Character Lock Requirement (HARD GATE)

Before proceeding: character description MUST cover all 6 attributes:
1. Body type / plush material
2. Face: eye shape, eye color, nose/mouth
3. Ear/head shape (rabbit ears? round head?)
4. Outfit: color, pattern, texture
5. Accessories or distinctive features
6. Color palette (primary + accent)

**All 6 must be specific and visual. Vague = fail.**

---

## Steps

### Step 0a — 6/6 Character Audit ⛔ HARD GATE

Verify `character_description` against all 6 attributes.
If any attribute is missing or vague: STOP. Request completion before any generation.

### Step 0b — Divergence Protocol

After each generated image: run divergence check against char-ref.
Any divergence in face, outfit, or distinctive feature = regenerate immediately.
Do NOT proceed to animation with a diverged character.

### Step 1 — Story Arc ⛔ CHECKPOINT

Write 5-act arc for `$num_scenes`:
Act 1: Establish plush world + character.
Act 2: Desire or challenge appears.
Act 3: Attempt + obstacle.
Act 4: Climax (emotional peak).
Act 5: Resolution (heartwarming/funny payoff).

Per scene: visual description + emotion + camera + motion cue.
**Gate: User approves story arc.**

### Step 2 — Character Reference

→ Skill: `ai-media` → `gemini-character-ref` (--model pro)
→ Prompt: full `character_description` + "product photography, white background, full body"
→ Output: `interim/broll/gfx/char-ref.png`

### Step 3 — Scene Images ⛔ CHECKPOINT

For each scene:
→ Skill: `ai-media` → `gemini-character-scene`
→ Pass `char-ref.png` to EVERY call
→ Motion: 1–2 sentence prompt, gentle words
→ Run divergence check immediately after each image
→ Output: `interim/broll/segments/scene-{N}.png`

**Gate: User approves all scene images. No diverged images proceed.**

### Step 4 — Animation

For each scene image → Hailuo i2v via Floe API:
→ Motion prompt: match scene motion cue
→ Poll for completion
→ Output: `interim/broll/segments/scene-{N}-anim.mp4`

### Step 5 — Assemble

→ Skill: `ffmpeg`:
1. Trim each clip to beat timing
2. Scale to 1080x1920 if needed
3. Crossfade concat
4. Mux with `$audio_track`
5. Loudness: -14 LUFS
→ Output: `video/compositing/composite-v1.mp4`

### Step 6 — Deliver ⛔ CHECKPOINT

→ Verify → `final/pr-labubu01-{desc}.mp4`
**Gate: User approves final animation quality.**

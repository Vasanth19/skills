---
name: pipeline-ai-character
description: AI character animated short pipeline. Produces a 9:16 short using Gemini character-consistent scene images animated via Hailuo i2v. No dialogue — visual storytelling with music. Requires a character lock audit before any scene generation.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [story-concept]"
allowed-tools: Bash, Read, Write
---

# pipeline-ai-character — AI Character Short (9:16)

Visual storytelling: Gemini character images → Hailuo animation → music → assembled short.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| story_concept | Yes | — | One-paragraph story concept |
| character_description | Yes | — | Visual character description for prompts |
| audio_track | Yes | — | Path to music/audio track |
| num_scenes | No | `5` | Number of scenes |
| character_method | No | `gemini` | `gemini` or `floe` |
| crossfade | No | `0.3s` | Crossfade duration between scenes |

## Steps

### Step 0 — Character Lock Audit ⛔ CHECKPOINT

Before ANY generation: run 6/6 character audit.
Verify character description covers: face shape, hair, eyes, clothing, distinctive feature, color palette.
All 6 must be present and specific.

If any missing: stop and complete the description before proceeding.
**Gate: Character description passes all 6 audit points.**

### Step 1 — Story Arc ⛔ CHECKPOINT

Write 5-act story structure (`num_scenes` scenes):
- Act 1: Establish character + world
- Act 2: Introduce tension/desire
- Act 3: Rising action
- Act 4: Climax moment
- Act 5: Resolution

Each scene: visual description + emotion + camera angle + motion cue

**Gate: User approves story arc.**

### Step 2 — Character Reference

→ Skill: `ai-media` → `gemini-character-ref`
→ `--model pro` (never flash — consistency issues)
→ Output: `interim/broll/gfx/char-ref.png`

This reference image MUST be passed to every scene generation call.

### Step 3 — Scene Generation ⛔ CHECKPOINT

For each scene (in order):
→ Skill: `ai-media` → `gemini-character-scene`
→ Pass `char-ref.png` to EVERY call — no exceptions
→ Motion prompts: 1–2 sentences, gentle words (slow, subtle, still)
→ Output: `interim/broll/segments/scene-{N}.png`

Run per-scene divergence audit after each image:
- Check character has same face/hair/clothing as char-ref.png
- If diverged: regenerate before moving to next scene

**Gate: User approves all scene images.**

### Step 4 — Animation (Hailuo i2v)

For each scene image:
→ Submit to Hailuo image-to-video via Floe API
→ Motion prompt: match scene description motion cue
→ Poll for completion (5–10 min per clip)
→ Output: `interim/broll/segments/scene-{N}-anim.mp4`

### Step 5 — Trim Clips

→ Skill: `ffmpeg` → trim each animated clip to target duration (cover story beat)
→ Trim to match audio track pacing

### Step 6 — Assemble

→ Skill: `ffmpeg` → concat with `$crossfade`s crossfade filter
→ Mux with `$audio_track`
→ Loudness: -14 LUFS
→ Output: `video/compositing/composite-v1.mp4`

### Step 7 — Delivery ⛔ CHECKPOINT

→ Verify output → `final/pr-aimg01-{desc}.mp4`
**Gate: User reviews final.**

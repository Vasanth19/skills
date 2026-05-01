---
name: pipeline-ai-character
description: AI character animated short pipeline. Produces a 9:16 short using Gemini character-consistent scene images animated via Hailuo i2v. Works for any character type — human, plush toy (Labubu/Tiny Tales style), mascot, or fantasy. No dialogue — visual storytelling with music. Requires 6-attribute character lock audit before any generation.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [story-concept] [--type human|plush]"
allowed-tools: Bash, Read, Write
---

# pipeline-ai-character — AI Character Short (9:16)

> **BACKEND STALE** — Gemini image → Hailuo i2v scene-by-scene flow is superseded by multi-motion video models (e.g. Sea Dance / Wan 2.1 / Kling 2.0) that generate character-consistent multi-scene video from a single prompt. The 6-attribute character lock audit and story arc structure remain valid. Rewrite Steps 3–5 around the new model before using.

Visual storytelling: character lock → Gemini scene images → Hailuo animation → music assembly.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| story_concept | Yes | — | One-paragraph story concept |
| character_description | Yes | — | Visual character description (all 6 attributes) |
| audio_track | Yes | — | Path to music/audio track |
| type | No | `human` | `human` or `plush` — controls character audit checklist and prompt tone |
| num_scenes | No | `5` | Number of scenes |
| character_method | No | `gemini` | `gemini` or `floe` |
| crossfade | No | `0.3s` | Crossfade duration between scenes |

---

## Step 0 — Character Lock Audit ⛔ HARD GATE

Before ANY generation, verify `character_description` covers all 6 attributes.

**If `--type human`:**
1. Face shape (oval, square, angular…)
2. Hair: color, length, style
3. Eyes: color, shape, expression
4. Clothing: color, pattern, texture
5. Distinctive feature (scar, glasses, accessory…)
6. Color palette (primary + accent)

**If `--type plush` (Labubu / Tiny Tales style):**
1. Body type / plush material (soft, vinyl, fuzzy…)
2. Face: eye shape, eye color, nose/mouth style
3. Ear/head shape (rabbit ears? round head? spiky?)
4. Outfit: color, pattern, texture
5. Accessories or distinctive features
6. Color palette (primary + accent)

**All 6 must be specific and visual. Vague = fail. STOP until complete.**

Also establish **divergence protocol**: after each generated image, check character has same attributes as char-ref. Any divergence in face, outfit, or distinctive feature = regenerate immediately. Do NOT animate a diverged scene.

**Gate: Character description passes all 6 audit points.**

---

## Step 1 — Story Arc ⛔ CHECKPOINT

Write 5-act story structure (`num_scenes` scenes):

- Act 1: Establish character + world
- Act 2: Introduce tension/desire
- Act 3: Rising action / attempt + obstacle
- Act 4: Climax (emotional or comedic peak)
- Act 5: Resolution (heartwarming / funny payoff)

Each scene: visual description + emotion + camera angle + motion cue.

For `--type plush`: keep emotional register toylike and playful. Physical movements should be exaggerated and charming.

**Gate: User approves story arc.**

---

## Step 2 — Character Reference

→ Skill: `ai-media` → `gemini-character-ref` (`--model pro` — never flash, consistency issues)
→ Prompt: full `character_description` + "product photography, white background, full body, clean studio lighting"
→ Output: `interim/broll/gfx/char-ref.png`

This reference image MUST be passed to every scene generation call. Never skip it.

---

## Step 3 — Scene Images ⛔ CHECKPOINT

For each scene (generate in order):
→ Skill: `ai-media` → `gemini-character-scene`
→ Pass `char-ref.png` to EVERY call — no exceptions
→ Motion prompts: 1–2 sentences, gentle words (slow, subtle, still, drifting)
→ Output: `interim/broll/segments/scene-{N}.png`

After each image: run divergence check. Regenerate before moving on if diverged.

For `--type plush`: include "plush toy", "soft fabric texture", "photorealistic toy photography" in every prompt.

**Gate: User approves all scene images. No diverged images proceed.**

---

## Step 4 — Animation (Hailuo i2v)

For each approved scene image:
→ Submit to Hailuo image-to-video via Floe API
→ Motion prompt: match scene motion cue (short, gentle)
→ Poll for completion (5–10 min per clip)
→ Output: `interim/broll/segments/scene-{N}-anim.mp4`

---

## Step 5 — Trim + Assemble

→ Skill: `ffmpeg`:
1. Trim each clip to match audio track pacing
2. Scale to 1080×1920 if not already portrait
3. Crossfade concat with `$crossfade` duration
4. Mux with `$audio_track`
5. Loudness: -14 LUFS

→ Output: `video/compositing/composite-v1.mp4`

---

## Step 6 — Delivery ⛔ CHECKPOINT

→ Skill: `ffmpeg` → 12-point delivery checklist
→ Verify output: codec, resolution, audio
→ Move to: `final/pr-aimg01-{desc}.mp4`

**Gate: User reviews final animation quality.**

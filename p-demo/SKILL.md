---
name: p-demo
description: "Demo video production pipeline. Turn raw screen recordings, OBS demos, product walkthroughs, or rough voice explanations into polished short-form or long-form videos with avatar, voiceover, B-roll, captions, and delivery QA. Supports three formats: short (30-60s), long (5-12 min), and avatar (automated HeyGen API)."
metadata:
  short-description: Turn raw demos into polished videos
  formats:
    - short
    - long
    - avatar
---

# Demo Video Production Pipeline

Turn raw demo assets into polished distribution-ready videos. Three formats, one pipeline.

| Format | Duration | Key Difference |
|--------|----------|--------------|
| `short` | 30–60s | One hook/value/proof/CTA argument, Remotion B-roll |
| `long` | 5–12 min | Full story with voiceover, sections, speed-adjustable |
| `avatar` | 5–12 min | Same as long + HeyGen API avatar clips, automated |

## Core Rule

**Do not just trim a long video and add text.** Reuse demo clips as proof, but create new narrative structure around them.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| format | Yes | — | `short`, `long`, or `avatar` |
| source | No | — | Path to raw demo footage or assets folder |
| script | No | — | Draft script path (skip if none) |
| speed | No | `1.0` | Final speed multiplier |
| captions | No | `true` | Burn captions |
| sfx | No | `false` | Include SFX |
| voiceover | No | — | Provided audio path (skip TTS generation) |

## Workflow (All Formats)

### Step 1 — Read Project Context
→ Read `AGENTS.md`, `CLAUDE.md`, brand configs, creative-director instructions.
→ Read `.config/brand.yaml` for `elevenlabs.voiceId` and `elevenlabs.modelId`.
→ For Mr Growth Guide, default: voice `6aTgB3K5cvcH2IlnFVSx`, model `eleven_multilingual_v2`.

### Step 2 — Inventory Assets
List all available: demo clips, final videos, extracted B-roll, voiceover, transcripts, stills, brand assets.
- Prefer original demo/B-roll clips over final long-form export.
- Use final long-form only when original B-roll is unavailable.

### Step 3 — Analyze Source Material
- Inspect duration, dimensions, audio, visual sections.
- Transcribe with MLX Whisper when available.
- Create B-roll inventory: timestamp, filename, visual content, narration fit.

### Step 4 — Write Story (Format-Dependent)

**If `format=short`:**
→ One idea per short. Do not combine setup, permissions, plugins, rendering, and voiceover into one.
- Beat sheet: `0-2s hook`, `2-7s setup`, `7-18s value/proof`, `18-25s payoff`, `last 2-4s CTA`.
- Hook: specific claim or proof. CTA: explicit keyword action.

**If `format=long` or `format=avatar`:**
- Direct hook, value delivery, proof/demo, build process, CTA.
- Hook must say what viewer gets, not just describe the tool.
- Founder/operator language for MGG: practical, specific, first-person, no hype.
- Clean TTS script + visual beat map before final voiceover.

### Step 5 — Generate Voiceover (Skip if `voiceover` provided)
→ Skill: `c-studio-audio` → ElevenLabs via Floe API.
→ Save generation log: voice_id, model_id, output path, byte count.
→ After generation: MLX transcription on final voiceover → retime scenes.

**If `format=avatar`:**
→ Generate each avatar snippet as separate audio from final avatar script text.
→ Stitch snippets into one HeyGen-ready MP3 with `0.5s` silence between.
→ Save split map: snippet name, text, audio duration, combined start/end, silence gaps.

### Step 6 — Create Captions
→ Generate from **actual final audio**, not draft script.
- Short: burned-in throughout hook/value/proof/CTA.
- Long: selective burned-in for hook, section turns, key claims, CTA.
- Keep to 1-2 lines, timed to spoken phrases, in safe areas.

### Step 7 — Generate B-Roll / Interactive GFX

**All formats:**
→ Skill: `c-broll` → check library → match to script → placement plan.
→ AI images: `c-ai-media` → read `brand-ref.md` first.
→ GFX cards: `c-html-gfx` → `interim/broll/gfx/`.
→ Website scroll: `c-web-capture`.

**Short format specifically:**
→ Remotion interactive B-roll: prompt typing, animated cursor, file cards, folder tree, tool chips.
→ Use real demo clips for credibility, Remotion overlays for teaching.
→ Keep overlays short: "Prompt", "Files", "Voice", "Render".

### Step 8 — Render Avatar (avatar format only)
→ Skill: `c-heygen` → API path with stitched audio as voice source.
→ Green background `#00FF00`. Submit ONE combined render.
→ Poll, download, split back using saved split map.
→ Read `references/heygen-api-workflow.md` for API details.

**Fail-fast:** Never silently fallback from HeyGen API to browser/MCP/manual. Stop with exact error.

### Step 9 — Compose Video
→ Use HyperFrames for HTML-based product scenes, animated text, polished sections.
→ Use Remotion for editorial composition, B-roll sequencing, captions, audio sync, speed changes.

**Composition rules:**
- Short: default `1080x1920`, `30fps`. Keep demo readable. Use motion to guide attention.
- Long: callouts in top-right unless screen requires another safe area.
- Avatar: avatar clips as small PIP by default. Full-screen avatar only for 8-12s personal beats.
- Avoid persistent dimming overlays. Use short callouts, highlight boxes.
- Screen recordings: quick punch-in to `1.2x`, settle back immediately. Don't crop important UI.

### Step 10 — Render and QA
- Render master first. Apply speed changes after.
- Verify: dimensions, frame rate, duration, audio sample rate, audio peak, first-frame brightness, caption readability, avatar placement, B-roll/narration alignment.
- Save still checks: hook, plugin settings, folder sections, product proof, captions, CTA.
- Save `DELIVERY.md` with final paths, model/voice IDs, verification numbers.

### Step 11 — Delivery
→ 12-point checklist (see `c-studio-production` delivery checklist).
→ Short output: `final/pr-demo01-{desc}.mp4`
→ Long/avatar output: `final/ls-demo01-{desc}.mp4`

## CTA Rules (Short Format)

Good: "Comment CODEX and I will share the prompt." / "Save this before building your next AI workflow."
Weak: "Follow for more." / "Let me know what you think."

## Caption Rules (All Formats)

- Every short needs burned-in captions unless explicitly requested otherwise.
- Hook caption must be readable with sound off in first 1-2 seconds.
- Do not use persistent dimming layer behind captions across whole short.
- If caption competes with demo, shorten or move before/after proof shot.
- Long-form: selective burned-in only for hook, section turns, key claims, CTA.

## Quality Rules

- Fail fast on API, render, or missing-file errors. Report exact error and stop.
- Do not claim a TTS model/voice was used unless logged in production folder.
- Do not overwrite raw source files. Generated files belong under production folder.
- Do not patch jittery render repeatedly. Rebuild from clean source + deterministic timeline.
- Use constant frame rate sources in Remotion. Normalize mixed-fps inputs before composition.

## Output Paths

```
{production}/
  script/         — full script, TTS-clean, beat map, split map (avatar)
  audio/          — voiceover, avatar audio clips, generation logs
  captions/       — SRT/VTT + composition-ready JSON
  broll/          — extracted clips, timestamp notes
  gfx/            — HTML GFX cards, banners
  avatar/         — HeyGen payloads, poll logs, combined render, splits (avatar)
  renders/        — Remotion/HyperFrames project
  interim/        — previews, still checks, temporary muxes
  final/          — master, speed variant, platform export
  logs/           — transcript, generation logs, delivery checklist
```

## Related Skills

- `c-heygen` — lower-level HeyGen details and troubleshooting.
- `c-ffmpeg` — video compositing, trimming, speed adjust.
- `c-studio-script` — script writing, TTS preprocessing, duration analysis.
- `c-studio-audio` — TTS, SFX, transcription.
- `c-html-gfx` — HTML graphics, banners, slides.
- `c-web-capture` — website scroll B-roll.
- `c-broll` — library management, placement plans.
- `c-studio-production` — folder structure, delivery checklist.
- `c-ai-media` — AI image/video generation.

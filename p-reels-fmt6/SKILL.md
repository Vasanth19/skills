---
name: p-reels-fmt6
description: "Produce a 9:16 vertical Short as a full-frame, data-driven Remotion screen-rec — prompt-on-screen reveals, typing/terminal UI cards, and animated React scenes built beat-by-beat from the script (the 'day13' interactive look), with NO talking head and NO avatar PIP. The voiceover is ElevenLabs TTS in the brand's cloned voice (or a user-uploaded VO track), muxed over the render and loudnorm'd to -16 LUFS. Trigger on 'screen-rec reel', 'prompt-on-screen short', 'typing/terminal UI reel with voiceover', 'faceless Remotion short', 'VO-only screen recording reel'."
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Screen-Rec VO Short
  format: 9:16 vertical video
  duration: 35-50s
inputs: [script]
dependsOn: [c-audio, f-remotion, c-ffmpeg, c-reel-premium]
---

# p-reels-fmt6

> Produces one 9:16 YouTube Short with a full-frame Remotion screen-rec (no avatar PIP). The voiceover is generated via ElevenLabs TTS (through the `c-audio` component) using the brand's cloned voice, or replaced by a user-uploaded VO track. Intended for prompt-on-screen reveals, UI walkthroughs, or any short where the brand deliberately breaks the talking-head pattern.

**Brand:** Mr Growth Guide (B-GROWTHGUIDE)
**Paperclip ticket:** VAS-52 (first production using this recipe)
**Sibling recipes:** `p-bottom-avatar-pip` (default MGG Shorts), `p-alternating-visual` (tutorial alternating cuts)

## Sub-documents

| File | Contents |
|---|---|
| [`brand-params.md`](brand-params.md) | MGG-specific parameter table + pipeline overview diagram |
| [`pipeline.md`](pipeline.md) | Step-by-step (Steps 1-9) |
| [`scene-bank.md`](scene-bank.md) | 7 reusable Remotion scenes with frame budgets |
| [`anti-patterns.md`](anti-patterns.md) | What NOT to do + known gotchas |
| [`acceptance.md`](acceptance.md) | Definition of Done + CMO handoff notes |

## When to Use

Pick `p-reels-fmt6` when:
- The reel is a prompt-on-screen reveal (typing into Claude/ChatGPT UI live) — visual payload is the prompt + result, not the creator's face
- Brand deliberately wants face-off-camera to vary the algo grid
- Creator's voice is still the anchor (no stock VO) — ElevenLabs cloned voice carries
- Duration target: 35-50s (tight cuts run 15-30s; MGG's denser voice lands 40-50s, acceptable)

**Do NOT use if** the reel needs visible face reactions, hand gestures, or on-camera delivery. Use `p-bottom-avatar-pip` for those or for news-jacks.

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `script` | Yes | — | Full script for ElevenLabs VO |
| `voiceId` | No | from `brand.yaml` | Override brand ElevenLabs voice |
| `speedMultiplier` | No | `1.0` | Optional atempo multiplier (post-generation); default 1.0 (no change). Use 1.25 only if raw VO lands >50s. |
| `targetDuration` | No | 35-46s | Final duration window (not including outro ~5s) |

## Premium polish pass (SFX + grade; captions OFF by default)

After `pipeline.md` Step 9 produces `final/short.mp4` and BEFORE any upload/handoff:

→ Skill: `c-reel-premium` — follow its Steps P1–P4 over the final file:

```bash
PREMIUM_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" -maxdepth 4 -type d -name c-reel-premium 2>/dev/null | head -1)
# REEL_IN/REEL_OUT=final/short.mp4  WORDS_JSON=<the VO transcript>
# CAPTIONS=off   <- the typing/terminal scenes already carry on-screen text; kinetic captions
#                   would double-caption. Enable only if the brief asks.
# SFX=on  GRADE=<planner picks>
```

Format defaults: captions OFF, SFX ON (whoosh/impact cues lift the scene transitions), grade ON.
The pass never extends/trims the reel and never re-touches the VO mastering.

## Output

- **Canvas:** 1080×1920 (9:16 portrait), 30fps
- **Layout:** Full-frame Remotion scenes, no PIP safe-zone reserved
- **Audio:** ElevenLabs VO, loudnorm'd to -16 LUFS
- **Final file:** `creatives/productions/MM.DD-<title>/final/short.mp4`
- **Cover:** `final/cover.png` (mid-beat frame — money shot, not the Hook scene)

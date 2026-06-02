---
name: p-hf-reel
description: Faceless HyperFrames Reel — a 9:16 vertical reel (~20-40s) where an ElevenLabs cloned-voice voiceover carries the narrative and the visuals are a TRUE f-hyperframes HTML/GSAP motion-graphics composition (animated text beats synced to the VO, GSAP transitions), NOT static cards and NOT an ffmpeg slideshow. Optional user-supplied b-roll clips are woven in as short 1-2s accent inserts inside the composition. No recorded person, no avatar. Renders via the hyperframes CLI, muxes the VO, uploads to R2, and returns the R2 public URL. Trigger on "faceless hyperframes reel", "motion-graphics reel with voiceover", "animated reel no avatar", "hf reel", "make a vertical reel where the graphics are animated and a voiceover narrates", "faceless reel from a script".
when-to-use: Use when the user wants a faceless (no avatar, no recorded person) 9:16 vertical reel where a brand-voice ElevenLabs voiceover narrates and the visuals are genuinely animated HTML/GSAP motion graphics (text beats, charts, transitions) authored in HyperFrames — optionally weaving in short user-supplied b-roll accent clips. NOT for talking-head reels, NOT for static-card slideshows, NOT for footage-with-PIP (use p-reels-fmt1 for that).
version: 1.0.0
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Faceless HyperFrames Reel
  format: 9:16 vertical video
  duration: 20-40s
inputs: [topic, voiceover_script, broll_clips]
dependsOn: [c-audio, f-hyperframes, f-hyperframes-cli, c-ffmpeg]
---

# p-hf-reel — Faceless HyperFrames Reel (9:16)


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Produces a faceless portrait reel: an ElevenLabs **brand cloned-voice voiceover** carries the
narrative, and the visuals are a **TRUE f-hyperframes HTML/GSAP composition** — animated motion
graphics with text beats synced to the VO phrases, GSAP entrances, and scene transitions. No
recorded person, no avatar. Optional user-supplied b-roll clips are woven in as short 1–2s accent
inserts as `<video>` elements **inside** the composition (HyperFrames plays video elements). Final
MP4 is rendered via the hyperframes CLI, muxed with the VO, uploaded to R2, and the **R2 public
URL is the last line of output**.

**This is NOT** a static-PNG-cards-plus-ffmpeg-concat slideshow (that's the old p-gfx-short shape).
**This is NOT** a footage-with-webcam-PIP reel (that's `p-reels-fmt1`). The visuals here are real
animated HyperFrames motion graphics driven off the VO timeline.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `topic` | One of topic/script | — | Topic/hook to write a script from (if no script supplied) |
| `voiceover_script` | One of topic/script | — | TTS-clean VO script. Carries the whole reel. |
| `broll_clips` | No | — | OPTIONAL user-supplied clips, woven in as 1–2s accent inserts inside the composition. NO clips = pure motion graphics. |
| `voice_id` | No | `$ELEVENLABS_DEFAULT_VOICE_ID` | Brand cloned voice. Env-resolved. |
| `style` | No | dark-premium | Brand DESIGN.md > named style > dark-premium default (see Step 0). |
| `music_bed` | No | — | OPTIONAL low instrumental bed mixed under the VO. |

## Parameters

| Param | Default | Notes |
|---|---|---|
| Canvas | `1080x1920` | 9:16 portrait, `data-width="1080" data-height="1920"` |
| FPS | `30` | uniform |
| Target duration | `20-40s` | the VO duration IS the composition duration |
| Composition render | `npx hyperframes render --quality draft` (iterate) → `--quality high` (final) | TRUE motion graphics |
| VO loudness | `loudnorm I=-14 TP=-1.5 LRA=11` | applied once |
| Music bed | mixed ~ -22 to -26 LUFS under the VO | optional, never overpowers VO |

---

## Step 0 — Visual Identity Gate (HARD-GATE — do this BEFORE any HTML)

This recipe routes through the **f-hyperframes Visual Identity Gate**. You MUST resolve a concrete
visual identity before writing a single line of composition HTML. Do NOT write compositions with
default/generic colors (`#333`, `#3b82f6`, `Roboto` = you skipped this step).

Resolve in this order (see `f-hyperframes/SKILL.md` § "Visual Identity Gate"):

1. **Brand `DESIGN.md` exists?** → Read it. Use its exact colors, fonts, motion rules, and "What
   NOT to Do" constraints.
2. **`visual-style.md` exists in the project?** → Read it. Apply its `style_prompt_full`.
3. **User named a style** (e.g. "Swiss Pulse", "dark and techy")? → Read
   `f-hyperframes/visual-styles.md` (8 named presets) and generate a minimal DESIGN.md.
4. **None of the above?** → **Default for THIS recipe = the dark-premium palette**
   (`f-hyperframes/palettes/dark-premium.md`). Generate a minimal DESIGN.md from one of its rows
   (`## Style Prompt`, `## Colors` with hex+roles, `## Typography`, `## What NOT to Do`). Faceless
   motion-graphics reels read as tech/cinematic — dark-premium is the right default unless the brand
   says otherwise.

Every scene must trace its palette + typography back to a DESIGN.md / visual-style.md / explicit
user direction. **Skipping this gate is a banned anti-pattern (see below).**

---

## Step 1 — Voiceover (ElevenLabs brand cloned voice) — get exact duration

The VO is the spine: its duration IS the composition duration, and its phrase timings are the text
beats. Generate it first.

- If `voiceover_script` was supplied → use it verbatim (TTS-clean it: expand numerals/abbreviations).
- If only `topic` was supplied → write a tight short-form VO script first (~55–110 words for a
  20–40s reel; hook-first, one idea per beat), confirm it reads cleanly, then proceed.

Generate via `c-audio` (ElevenLabs through the Floe API; direct ElevenLabs as fallback). The brand
cloned voice is `$ELEVENLABS_DEFAULT_VOICE_ID` unless `voice_id` overrides it:

```bash
# → Skill: c-audio  (Floe primary, direct ElevenLabs fallback)
#   SCRIPT_TEXT=<the VO script>  VOICE_ID="$ELEVENLABS_DEFAULT_VOICE_ID"
#   OUTPUT_PATH=interim/audio/vo.mp3
```

Then get the **exact** VO duration and a phrase-level timeline (transcribe for word/phrase windows):

```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 interim/audio/vo.mp3
cfw-transcribe --input interim/audio/vo.mp3 --out interim/audio/vo.srt --format srt   # phrase windows
```

The SRT timecodes are ground truth for syncing text beats to VO phrases. Round the body duration to
the VO length (e.g. VO = 27.4s → `data-duration="27.4"`).

---

## Step 2 — Author the HyperFrames composition against the VO timeline

Author ONE 1080×1920 standalone `index.html` (`data-composition-id` directly in `<body>` — NO
`<template>` wrapper for the root) with `data-duration` = the VO length. Follow
`f-hyperframes/SKILL.md` + `house-style.md` + `references/motion-principles.md`:

- **Text beats synced to VO phrases.** Read the SRT; for each phrase/idea, author a scene (or a
  beat within a scene) whose entrance lands ON that phrase's timecode. The on-screen text is
  CLEAN/derived display copy (headline, stat, eyebrow) — never a verbatim caption dump of the VO.
- **GSAP motion per `motion-principles.md`.** Entrance animation on EVERY element (`gsap.from()`),
  vary at least 3 eases per scene, 0.3–0.6s, offset the first tween 0.1–0.3s. **NO exit animations
  except the final scene** — the transition IS the exit. Persistent decoratives (radial glow,
  ghost text, hairline grid) with slow ambient motion so scenes aren't empty during staggers.
- **Scene transitions between every scene** (crossfade/wipe/shader per `references/transitions.md`).
  No jump cuts.
- **Palette = the identity resolved in Step 0** (dark-premium unless brand style says otherwise).
  Charts/diagrams hand-built with GSAP+CSS/SVG — never a chart library. `hyperframes add data-chart`
  installs a ready animated-chart block if you'd rather wire one in.
- **Optional b-roll accent inserts (1–2s).** If the user supplied `broll_clips`, weave each in as a
  `<video muted playsinline>` element INSIDE the composition for a short 1–2s accent cut on the beat
  it illustrates (HyperFrames plays video elements — `data-start`, `data-duration` ≈ 1–2s,
  `data-track-index`, trim with `data-media-start`; audio of the b-roll is irrelevant — the VO is a
  separate audio bed muxed in Step 4). These are accents, not the spine: the motion graphics carry
  the reel; clips punctuate it.

```bash
npx hyperframes init hf-reel --non-interactive   # scaffold; then author index.html (1080x1920)
```

Author the end-state layout first (see `f-hyperframes` § "Layout Before Animation"), THEN add
entrances/transitions. The composition has **no audio track** — the VO is muxed in Step 4.

---

## Step 3 — Lint + validate + render via the hyperframes CLI

```bash
npx hyperframes lint                              # 0 errors before rendering
npx hyperframes validate                          # WCAG contrast audit — clear AA warnings
npx hyperframes render --output interim/render/visuals.mp4 --fps 30 --quality draft   # iterate
# final pass once happy:
npx hyperframes render --output interim/render/visuals.mp4 --fps 30 --quality high
ffprobe -v error -show_entries stream=width,height -of default=noprint_wrappers=1 interim/render/visuals.mp4  # expect 1080x1920
```

Lint must be 0 errors and validate AA-clean before rendering. The rendered `visuals.mp4` is
1080×1920 with NO audio (the VO is a separate track).

---

## Step 4 — Mux: VO (+ optional music bed) as the audio track (c-ffmpeg)

The VO is the audio track. The rendered visuals carry no sound, so we mux the loudnormed VO (and an
optional low music bed) onto `visuals.mp4`. Use `c-ffmpeg`.

```bash
# VO only:
ffmpeg -y -i interim/render/visuals.mp4 -i interim/audio/vo.mp3 \
  -filter_complex "[1:a]loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]" \
  -map 0:v -map "[a]" -shortest \
  -c:v copy -c:a aac -ar 48000 -ac 2 -b:a 192k -movflags +faststart interim/render/reel.mp4

# VO + optional low music bed ($MUSIC):
# [1:a] VO loudnormed; [2:a] music ducked low under it; amix; keep VO dominant.
ffmpeg -y -i interim/render/visuals.mp4 -i interim/audio/vo.mp3 -i "$MUSIC" \
  -filter_complex "[1:a]loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[vo];[2:a]volume=0.12,aresample=48000[mus];[vo][mus]amix=inputs=2:duration=first:dropout_transition=0[a]" \
  -map 0:v -map "[a]" -shortest \
  -c:v copy -c:a aac -ar 48000 -ac 2 -b:a 192k -movflags +faststart interim/render/reel.mp4
```

Keep each `filter_complex` on ONE line (no embedded newlines / no `#` comments inside it) — ffmpeg
8.x parses stray whitespace as an empty filter. The music bed must sit clearly UNDER the VO (~ -22
to -26 LUFS) — never overpower it.

---

## Step 5 — QA checklist (BEFORE upload)

Do NOT upload until every box passes. Pull frames + ffprobe to verify:

```bash
ffprobe -v error -show_entries format=duration -show_entries stream=codec_type,width,height,r_frame_rate -of default=noprint_wrappers=1 interim/render/reel.mp4
ffmpeg -v error -i interim/render/reel.mp4 -f null -            # empty output = clean decode
ffmpeg -y -ss 3  -i interim/render/reel.mp4 -frames:v 1 qa-3s.png
ffmpeg -y -ss 15 -i interim/render/reel.mp4 -frames:v 1 qa-15s.png
```

- [ ] **Duration matches the VO** (reel length ≈ VO length; visuals don't run long or get cut short).
- [ ] **1080×1920, 30fps, video + audio both present, clean decode.**
- [ ] **No static-only stretches > 3s** — every >3s window has motion (entrance, ambient, or
      transition). A frozen frame for >3s means a missing animation; fix the composition.
- [ ] **Text legible at mobile size** — 60px+ headlines, 20px+ body, AA contrast clear (re-run
      `hyperframes validate` if unsure).
- [ ] **Audio levels** — VO is the clear foreground (~ -14 LUFS); any music bed sits well under it;
      no clipping.
- [ ] **B-roll inserts (if any) are short accents (1–2s)** on the right beat — not dominating the
      reel, not silent dead frames.

---

## Step 6 — Upload to R2 and print the URL (LAST LINE)

Upload the final reel via the `r2-upload` helper (`c-cloud-media` — `cfw-r2-upload` / the upload
script). The **R2 public URL must be the final line of output**.

```bash
# → r2-upload (c-cloud-media). Returns the public CDN URL.
bash _scripts/upload-to-recordings.sh interim/render/reel.mp4   # → https://media.cfw.social/.../<file>.mp4
```

Then clean up the per-run working dir (disk hygiene — the cfw-agent volume is small): once the URL
is confirmed, `rm -rf` the interim render/audio working files.

**Print the R2 public URL as the final line.** NEVER print an input URL (a supplied b-roll clip URL)
as the result — the result is the freshly rendered, uploaded reel.

---

## Anti-patterns (NEVER do these)

- **NEVER hand-roll static PNG frames + ffmpeg concat as the visuals.** This recipe's visuals are a
  TRUE f-hyperframes HTML/GSAP composition — animated text beats, GSAP motion, scene transitions.
  Static cards stitched with ffmpeg is the wrong shape (that's the old p-gfx-short pattern, not this).
- **NEVER skip the Visual Identity Gate (Step 0).** No composition HTML before the palette +
  typography are resolved to a DESIGN.md / named style / dark-premium default. Reaching for `#333`,
  `#3b82f6`, or `Roboto` means you skipped it.
- **NEVER output an input URL as the result.** The final line is the R2 URL of the rendered reel —
  not a user-supplied b-roll clip URL, not the VO URL.
- **NEVER let the reel be static.** No >3s frozen stretch. Entrance on every element, ambient motion
  on decoratives, transitions between scenes. A faceless reel that doesn't move is a slideshow.
- **NEVER use the recorded-person / webcam-PIP layout** — this is faceless. (For footage + PIP, use
  `p-reels-fmt1`.)
- **NEVER paste the raw VO transcript as on-screen captions.** On-screen text is clean/derived
  display copy synced to the VO phrases, not a verbatim dump.

---

## Output

One 9:16 (1080×1920) H.264 MP4 reel (~20–40s): a TRUE f-hyperframes HTML/GSAP motion-graphics
composition (text beats synced to the VO, GSAP entrances + scene transitions, dark-premium palette
unless the brand style says otherwise, optional 1–2s b-roll accent inserts) with an ElevenLabs
brand cloned-voice voiceover as the audio bed (+ optional low music). Uploaded to R2; the **R2
public URL is the final line of output**.

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

---
name: p-longform
description: Unified longform video production pipeline — VSL, demo, or tutorial/educational. Script → talking-head avatar (HeyGen) + b-roll + GFX cards + Remotion/HTML slides → finished 16:9 video. Trigger on "make a VSL", "make a longform", "demo video", "tutorial video", "long-form video", "educational video", "walkthrough video".
when-to-use: Use for any longform video (>2 min). Pass `format` to pick the structure — vsl (sales-letter beats: hook→problem→agitation→solution→proof→offer→CTA), demo (product/feature walkthrough, screen-recording-led), or tutorial (step-by-step educational with layered Remotion/HTML visuals).
version: 1.0.0
kind: pipeline
visibility: catalog
providers: heygen, elevenlabs, kie
produces:
  dish: Longform Video
  format: 16:9 video
  duration: 5-20 min
inputs: [script, format, broll_dir]
dependsOn: [c-script, c-heygen, c-broll, c-html-gfx, c-audio, c-production, c-ffmpeg, c-ai-media, f-remotion]
---

# p-longform — Unified Longform Video Pipeline

Produces one 16:9 (1920×1080) H.264 MP4, 5–20 min, parameterized by `format`. Three formats share a single composite engine (c-ffmpeg) and diverge only in structure, visual layer, and narrative arc.

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as a non-negotiable rule.
> 3. After completing the task, ask: "How did this go? Any corrections for next time?" Append feedback to `LEARNINGS.md`. Critical items go under **Active Feedback** with `[ACTIVE]` prefix.

---

## Intake — Ask First

Before starting, confirm these three things from the user:

1. **`format`** — `vsl` | `demo` | `tutorial`
2. **`script`** — paste in full, or path to `.txt` (TTS-clean) or `.md` (draft needing approval)
3. **`broll_dir`** — path to an existing b-roll library, screen recordings, or demo captures (optional; say "none" if starting fresh)

Also useful (ask if not obvious from context):
- **`brand`** — brand slug (needed to read brand ref for AI media generation)
- **`production_name`** — folder name under `productions/`
- **`source_video`** — existing green-screen HeyGen render to reuse (skips a new HeyGen job)

---

## Format Parameter Table

| Parameter | Values | Default | Notes |
|---|---|---|---|
| `format` | `vsl` \| `demo` \| `tutorial` | — | Required. Determines narrative structure and visual layers. |
| `script` | path or paste | — | Required. `.txt` = TTS-clean (skip approval); `.md` = draft (show to user first). |
| `broll_dir` | path or `none` | `none` | Library of clips, screenshots, or demo recordings. |
| `source_video` | path or `none` | `none` | Reuse an existing HeyGen green-screen render — skips Step 2. Save credits. |
| `speed` | `1.0`–`1.25` | `1.0` | TTS speed multiplier (ElevenLabs or HeyGen VO). |
| `broll_coverage` | `0%`–`100%` | `80%` | Minimum b-roll coverage target (% of runtime with b-roll over avatar). |
| `num_gfx` | integer | `6` | HTML GFX cards to create (stat reveals, quotes, CTA banners). |
| `num_images` | integer | `4` | AI-generated still images via c-ai-media (supplements GFX). |
| `sfx` | `true` \| `false` | `true` | Mix subtle SFX bed (intro sting, section transitions). |
| `captions` | `true` \| `false` | `false` | Burn word-level captions from SRT (top-center, yellow active word). |
| `remotion` | `true` \| `false` | `false` for vsl/demo; `true` for tutorial | Render Remotion compositions for animated diagram sections. |
| `pip_mode` | `full` \| `corner` \| `none` | `corner` | Avatar layout: `full` = talking-head fills frame; `corner` = PIP bottom-right; `none` = VO only. |

---

## Setup

Read brand path from `~/.gsai/ecosystem.yaml`. Create production folder:

```
{brand_path}/creatives/productions/{production_name}/
  interim/scripts/
  interim/audio/
  interim/broll/segments/
  interim/broll/gfx/
  interim/broll/remotion/
  interim/broll/slides/
  interim/video/base/
  interim/video/compositing/
  final/
```

---

## Format-Specific Structure

---

### FORMAT: vsl — Sales Letter Video

**Narrative arc:** Hook → Problem → Agitation → Solution → Proof → Offer → CTA

The VSL is the primary conversion tool. Every section maps to a sales beat. Avatar is always present (full-frame or PIP). GFX cards appear on every claim, statistic, and benefit. The script must end with a clear single CTA.

**VSL section map template:**

| Section | Duration | Beat | Visual |
|---|---|---|---|
| Hook | 0–30s | Attention-grabbing statement or question | Avatar full-frame, no b-roll |
| Problem | 30s–2m | The pain the viewer is experiencing | Avatar + empathy b-roll |
| Agitation | 2–4m | Consequences of not solving the problem | Avatar + fear/contrast b-roll |
| Solution | 4–8m | Your product/service/methodology | Avatar + product GFX cards |
| Proof | 8–12m | Case studies, testimonials, results | Avatar + stat GFX cards, screenshots |
| Offer | 12–16m | Pricing, bonuses, guarantee | Avatar full-frame + offer GFX |
| CTA | 16–20m | One clear action | Avatar full-frame, CTA card full-screen |

**VSL-specific rules:**
- No numbered chapters or tutorial callouts. Sales copy only.
- Every claim gets a GFX card (stat reveal or quote card). Minimum 1 card per script minute.
- If `num_gfx < 6`, warn the user — a VSL under 6 GFX cards is under-supported.
- CTA must appear on screen as a text card in the final 60 seconds.
- GFX theme: brand dark + accent color (read `brand-ref.md` first). Not tutorial-blue.
- B-roll: lifestyle/aspiration/pain imagery. Screen recordings are wrong for VSL — use c-ai-media or b-roll library.

---

### FORMAT: demo — Product/Feature Walkthrough

**Narrative arc:** Problem statement → Setup → Live demonstration → Result → Next steps

The demo is screen-recording-led. The avatar appears as a PIP (bottom-right or top-right). UI callout overlays highlight key clicks and elements. The viewer should be able to follow along.

**Demo section map template:**

| Section | Duration | Visual |
|---|---|---|
| Context (why this matters) | 0–60s | Avatar full-frame OR screen with voice over |
| Setup / before state | 1–2m | Screen recording + avatar PIP |
| Core demo step 1 | varies | Screen recording, UI callouts, avatar PIP |
| Core demo step N | varies | Screen recording, UI callouts, avatar PIP |
| Result / after state | 1–2m | Screen recording or result screenshots |
| Recap + next steps | 1–2m | Avatar full-frame + summary GFX card |

**Demo-specific rules:**
- Screen recording is the primary visual layer. It drives the timeline — b-roll and GFX are secondary.
- Avatar PIP: bottom-right corner at ~280×280 px (see c-ffmpeg/references/landscape-pip.md for geometry). Never larger — it must not obscure UI.
- UI callouts: use c-html-gfx to generate annotation overlays (arrows, highlight boxes, tooltip labels) as transparent PNGs, composited over the screen recording via c-ffmpeg.
- Trim demo recordings before compositing: cut dead air, mouse drift, loading spinners unless relevant. Use c-ffmpeg trim operations.
- Audio: avatar VO is primary. Screen recording audio is stripped unless a specific sound cue is needed.
- `broll_coverage` applies to screen recording coverage — at minimum 80% of demo sections should show the actual product.

---

### FORMAT: tutorial — Step-by-Step Educational (Visual Composite)

**Narrative arc:** Learning objective → Concept setup → Step-by-step walkthrough → Worked example → Summary + next steps

This is the richest visual format: layered Remotion GFX, HTML explainer slides, demo screen recordings, and optional avatar PIP. Designed for YouTube educational content. This format absorbs the full p-longform-visual pipeline.

**Tutorial section map template (build this before any production):**

| Section | Start | End | Type | Visual Plan |
|---------|-------|-----|------|-------------|
| Intro | 00:00 | 00:30 | talking-head | None — avatar full-frame |
| Concept 1 | 00:30 | 02:00 | concept | Remotion animated diagram |
| Concept 2 | 02:00 | 03:30 | concept | HTML explainer slide |
| Demo | 03:30 | 07:00 | demo-recording | Screen recording, side-by-side |
| Step-by-step | 07:00 | 12:00 | walkthrough | Screen + avatar PIP |
| Summary | 12:00 | 13:00 | talking-head | GFX card: key takeaways |

> Gate: User approves the section map before any rendering starts. The map is the production contract.

**Tutorial visual layers (all built before compositing):**

1. **Remotion GFX** (via f-remotion + c-html-gfx): animated diagrams, stat reveals, step progressions, flow charts. One Remotion composition per `Remotion diagram` section in the map. See Step 3T below.
2. **HTML explainer slides** (via c-html-gfx): progressive reveal slides for conceptual sections. Poppins font, one idea per slide, animated entrance.
3. **Demo screen recordings**: existing recordings from `broll_dir`, or captured fresh. Trim and normalize before compositing.
4. **Avatar PIP** (optional, via c-heygen): talking-head rendered at 1920×1080 green-screen, then composited as PIP (corner or side) over the relevant sections.

**AI-generated broll note (from p-longform-visual LEARNINGS, 2026-05-25):** For fully AI-generated tutorial videos, HTML terminal mockups → Chrome headless screenshots at 1920×1080 are a valid autonomous substitute for screen recordings. Use the freeze-frame approach: PNG → freeze-frame video segment with `ffmpeg -loop 1 -tune stillimage -r 30 -pix_fmt yuv420p`. Map 3–5 screenshots per lesson to script sections.

---

## Shared Production Pipeline (All Formats)

The steps below use labeled variants (V = vsl, D = demo, T = tutorial) where behavior differs.

---

### Step 1 — Script ⛔ CHECKPOINT

If `script` is a `.md` draft: present to user for review and approval.
If `script` is a `.txt` TTS-clean: confirm word count and estimated duration (`c-script` duration calc).

→ Skill: `c-script` → TTS preprocessing (remove stage directions, normalize punctuation)
→ Save TTS-clean to: `interim/scripts/{name}-tts.txt`

**Gate: User approves script before any render.**

---

### Step 2 — Avatar Render ⛔ CHECKPOINT

Skip if `source_video` is provided — jump to Step 3.

→ Skill: `c-heygen` → browser render path
→ Background: `#00FF00` solid (green-screen)
→ Script: full TTS-clean script
→ Voice: brand-configured voice or user-specified

**Gate: User manually triggers HeyGen render and confirms job ID.**

**Reuse principle:** Always prefer `source_video` over a new HeyGen job when the script hasn't changed materially. Never burn HeyGen credits for a layout change.

---

### Step 3 — Poll & Download Avatar

→ Skill: `c-heygen` → poll via API (60s interval)
→ Download to: `interim/video/base/{name}-green-screen.mp4`
→ Verify green-screen quality (edge color uniformity)

If `speed != 1.0`: apply speed adjust → `interim/video/base/{name}-green-screen-{speed}x.mp4`

---

### Step 4 — Transcription

→ Skill: `c-audio` → MLX Whisper on downloaded avatar audio (or extracted audio from MP4)
→ Output: `interim/audio/{name}.srt` + `{name}.txt`

The SRT is ground truth for all b-roll timecodes. All segment boundaries in the plan must use SRT timecodes.

---

### Step 5 — Visual Layer Build (format-specific)

#### Step 5V (vsl) — GFX Cards + AI Images

Run in parallel:

**5Va. HTML GFX Cards:**
→ Skill: `c-html-gfx` → dark studio theme matching brand ref
→ `num_gfx` cards: stat reveals, quote cards, benefit bullets, CTA banner
→ Screenshot to PNG → convert to 5s clips with 1.15x Ken Burns (c-ffmpeg)
→ Output: `interim/broll/gfx/`

**5Vb. AI Images:**
→ Skill: `c-ai-media` → read `brand-ref.md` first
→ `num_images` lifestyle/aspiration/problem images
→ Output: `{brand_path}/creatives/brolls/images/`

**5Vc. Contextual Background:**
→ Skill: `c-ai-media` → generate contextual background matching brand/topic
→ Save to: `interim/video/base/{name}-bg.png`

#### Step 5D (demo) — Screen Recording Processing + Callout Overlays

**5Da. Trim screen recordings:**
→ Skill: `c-ffmpeg` → trim dead air, normalize codec (H.264, 1920×1080, 30fps, no audio)
→ Output: `interim/broll/segments/screen-{section}.mp4`

**5Db. UI callout overlays:**
→ Skill: `c-html-gfx` → generate transparent PNG annotation overlays per section
→ Arrow annotations, highlight boxes, tooltip labels
→ Output: `interim/broll/gfx/callout-{section}.png`

**5Dc. GFX summary card:**
→ Skill: `c-html-gfx` → 1 summary/recap GFX card for the final section
→ Output: `interim/broll/gfx/summary-card.mp4`

#### Step 5T (tutorial) — Remotion Compositions + HTML Slides ⛔ CHECKPOINT

**5Ta. Design Remotion compositions:**
For each section marked `Remotion diagram` in the section map:
→ Skill: `c-html-gfx` + f-remotion → design TSX component (Remotion + Tailwind)
→ Composition types: animated diagram, stat reveal, step progression, flow chart
→ Palette: Poppins/Inter fonts, brand colors (dark bg, accent highlight)

> Gate: User approves Remotion composition designs (TSX sketches) before rendering.

**5Tb. Build HTML explainer slides:**
For conceptual sections (not Remotion, not demo):
→ Skill: `c-html-gfx` → animated explainer slides
→ Rules: progressive reveal, Poppins font, one idea per slide, dark background, animated entrance
→ Output: `interim/broll/slides/slide-{section}.html` + PNG screenshots

**5Tc. Render Remotion:**
→ Skill: f-remotion (via c-html-gfx Remotion render path)
→ Pre-flight: `npm ci --omit=optional` in the Remotion project dir
→ Shared Chromium: `$REMOTION_BROWSER_EXECUTABLE` (do not download a second browser)
→ Font gotcha: never use `var(--font-*)` inside `font-family` — the Remotion compiler resolves it literally and falls back to a generic face. Use a mapped name directly: `'Poppins'`, `'Inter'`, `'Oswald'`, `'JetBrains Mono'`.
→ Output: `interim/broll/remotion/{composition}.mp4`

**5Td. Extend GFX clips to section duration (freeze-frame):**
If a Remotion clip is shorter than its section, freeze the last frame for the remainder:
```bash
ffmpeg -i remotion-clip.mp4 \
  -vf "tpad=stop_mode=clone:stop_duration={extra_seconds}s" \
  -c:v libx264 -c:a aac -y extended-clip.mp4
```

**5Te. AI-generated freeze-frame broll (fully autonomous path):**
When no screen recordings are available, generate HTML terminal mockups or product screenshots → Chrome headless at 1920×1080, then convert to freeze-frame video segments:
```bash
ffmpeg -loop 1 -i screenshot.png -t {section_duration} \
  -tune stillimage -r 30 -pix_fmt yuv420p \
  -c:v libx264 -preset medium -crf 20 -y freeze-{section}.mp4
```
Concat.txt must be written with `printf`; run `cd "$VIDEO_DIR"` before the ffmpeg concat command so relative paths resolve correctly.

---

### Step 6 — B-Roll Plan ⛔ CHECKPOINT

→ Skill: `c-broll` → check library first for reusable assets
→ Use SRT timecodes for all segment boundaries
→ Build the b-roll plan — every row must have:

| Timecode | Speaker Says | Layout | Visual Asset | Zoom |
|---|---|---|---|---|

- Layouts available: `AVATAR_FULL` | `PIP_CORNER` | `PIP_SIDE` | `FULLSCREEN_BROLL` | `SIDE_BY_SIDE`
- Quality guard: ≥4 unique assets, ≥`broll_coverage`% of runtime

**Gate: User reviews and approves b-roll plan before generating assets.**

---

### Step 7 — Composite ⛔ CHECKPOINT

→ Skill: `c-ffmpeg` → assemble per section map and b-roll plan

**Pre-composite: process avatar background**
Sample avatar edge pixels at a mid frame to detect background type:
- Dominant edge ≈ `#00FF00` → `bg_type=green_screen`: apply two-pass colorkey before scaling
  (`colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01` — use `colorkey`, NOT `chromakey`)
- Anything else → `bg_type=opaque`: skip chroma-key; avatar shows inside PIP card as-is

**For vsl / demo composite (landscape PIP):**
→ Reference: `c-ffmpeg/references/landscape-pip.md`
1. Pre-render: avatar on contextual background → `video/base/avatar-on-bg.mp4` (with `-g 25`)
2. Build segment list per b-roll plan (AVATAR_FULL / PIP / FULLSCREEN)
3. Each segment carries synced audio
4. Concat all segments → `video/compositing/composite-v1.mp4`
5. Verify with ffprobe

**For tutorial composite (section-by-section stitch):**
Assemble per section type in the approved section map:
- `talking-head` sections: avatar video as-is (full-frame)
- `demo-recording` sections: screen recording primary + avatar PIP (if `pip_mode=corner`)
- `concept` sections (Remotion/slides): GFX/slide clip as primary + avatar VO
- `side-by-side` sections: `hstack` or `vstack` of screen + avatar:
  ```bash
  ffmpeg -i main-scaled.mp4 -i demo-trimmed.mp4 \
    -filter_complex "[0:v][1:v]hstack=inputs=2[v]" \
    -map "[v]" -map "0:a" -c:v libx264 -c:a aac -y side-by-side.mp4
  ```
→ Output: `video/compositing/composite-v1.mp4`

**Gate: User reviews first composite before post-processing.**

If verify fails: fix and recomposite before proceeding — never carry a broken composite into post.

---

### Step 8 — Post-Processing

**8a. SFX Mix** (if `sfx: true`):
→ Skill: `c-ffmpeg` → reference `c-ffmpeg/references/audio-processing.md`
→ Check SFX library first for brand intro sting and transition cues
→ Mix at -18 dB moderate (never drown VO)

**8b. Loudness Normalize:**
→ Two-pass loudnorm to **-14 LUFS** (two-pass gets within ±0.5 LUFS on speech TTS)
```bash
# Pass 1 — measure
ffmpeg -i composite.mp4 -af loudnorm=I=-14:LRA=11:TP=-1.5:print_format=json -f null - 2>&1

# Pass 2 — apply with measured values
ffmpeg -i composite.mp4 \
  -af "loudnorm=I=-14:LRA=11:TP=-1.5:measured_I={I}:measured_LRA={LRA}:measured_TP={TP}:measured_thresh={thresh}:linear=true" \
  -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 -y loudnorm.mp4
```

**8c. Captions** (if `captions: true`):
→ Burn word-level captions from SRT → top-center, yellow active word
→ Skill: `c-ffmpeg`

---

### Step 9 — Delivery ⛔ CHECKPOINT

→ Skill: `c-production` → run 12-point delivery checklist
→ Final naming: `ls-{category}01-{description}.mp4` → copy to `final/`

**Gate: All 12 checks pass. User reviews final before marking done.**

---

### Step 10 — Archive

→ Skill: `c-broll` → archive reusable clips from `interim/broll/` to `{brand_path}/creatives/brolls/`
→ Update library `.md` index files
→ Run `/deliver` to mark production complete

---

## Acceptance Criteria

Before handing off the final file, confirm all of these:

- [ ] Duration within target range for format (vsl: 10–20 min; demo: 5–15 min; tutorial: 5–20 min)
- [ ] Audio: -14 LUFS ±1 LU, no clipping, no silence gaps > 2s
- [ ] Video: 1920×1080, H.264, yuv420p, 25fps, `+faststart`
- [ ] B-roll coverage ≥ `broll_coverage` parameter
- [ ] All GFX cards appear at the correct timecodes per b-roll plan
- [ ] No unintended green fringe on avatar (if green-screen path used)
- [ ] CTA visible in final 60s (vsl only)
- [ ] For tutorial: section titles/chapter markers visible at section boundaries
- [ ] ffprobe passes: correct codec, dimensions, sample rate, channel count
- [ ] File named per naming convention and written to `final/`

---

## Anti-Patterns & Gotchas

**No `#` comments inside ffmpeg `filter_complex` strings** — parse error. Save complex filter graphs to a `.sh` file if they exceed 3 lines.

**Remotion font gotcha:** Never put `var(--font-*)` inside a `font-family` value in a Remotion/HyperFrames component. The Remotion compiler resolves font-family literally — a CSS var falls back to a generic face. Always use a mapped font name: `'Poppins'`, `'Inter'`, `'Oswald'`, `'JetBrains Mono'`.

**Concat.txt path resolution:** Always `cd "$VIDEO_DIR"` before running an ffmpeg concat command with a concat.txt. Relative paths in concat.txt break when the working directory is different. Write the concat.txt with `printf`, not `echo`.

**Freeze-frame segment:** Use `-loop 1 -tune stillimage -r 30 -pix_fmt yuv420p` for PNG-to-video. `-tune stillimage` only applies to H.264 — omit if using another codec.

**Two-pass loudnorm is mandatory for TTS.** A single-pass loudnorm on TTS audio can land 1–2 LU off target. Two-pass gets within ±0.5 LU.

**Never reuse `source_video` from a different script without re-transcribing.** The SRT must match the audio in `source_video`. If you skip HeyGen but use a cached render, run c-audio transcription on the cached MP4, not on the new script text.

**`colorkey` not `chromakey`.** This build's ffmpeg does not have `chromakey`. Use `colorkey=0x00FF00:0.25:0.05` (two-pass: run it twice with slightly different similarity/blend values to clean up fringe).

**Section map is the production contract.** For the tutorial format, the section map is approved by the user before any rendering. Changes to the section map after Step 5T starts require explicit user approval and may invalidate already-rendered Remotion clips.

**Demo audio stripping:** Always strip audio from screen recordings before compositing. The avatar VO is the single audio master. Mixing screen recording audio and avatar VO creates phase and level problems.

**VSL GFX theme ≠ tutorial theme.** VSL GFX cards use brand dark + accent (sales/conversion aesthetic). Tutorial slides use a lighter educational aesthetic. Never copy GFX from one format to the other.

---

## Self-Improvement Feedback Loop

After completing the task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with today's date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md` with the `[ACTIVE]` prefix.

---
name: p-reels-fmt4
description: Turn a script into a fully rendered explainer reel with no talking head — one REAL animated HyperFrames motion-graphics composition per beat (charts that draw/count on, terminals that type, diagrams that flow, checklists that check off) plus voiceover. NO stock/AI b-roll, NO static stills. Trigger on "make an explainer reel from this script", "faceless animated short with VO", "no-avatar explainer video", "script to animated reel with voiceover".
when-to-use: Use when the user wants a faceless explainer reel — numbered/listicle or beat-by-beat brand motion-graphics with a voiceover, NO talking-head avatar and NO random b-roll. Every beat's visual is a genuinely animated HyperFrames composition, not a still card.
version: 4.2.0
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Faceless Explainer Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-audio, c-ffmpeg, f-hyperframes, f-hyperframes-cli, c-cloud-media]
---

# p-reels-fmt4 — Script → Faceless Explainer Reel (No Talking Head)


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

A 9:16 vertical reel built from a SCRIPT: voiceover (TTS) + **one genuinely-animated
HyperFrames motion-graphics composition per beat** — charts that draw and count on,
terminals that type a command and print output, before/after panels that slide, diagrams
whose arrows draw on, checklists that check off — plus an optional brand outro. **No HeyGen,
no avatar. No stock or AI b-roll. No static stills.**

**v4 fix (2026-05-27):** v3 rendered each beat as an HTML *still* and faked motion with an
ffmpeg Ken Burns zoom. That is NOT acceptable — a slow pan over a frozen card is not a motion
graphic. v4 makes the **PRIMARY path real HyperFrames compositions** authored with GSAP
timelines (`hyperframes init` → edit `index.html` → `hyperframes lint` → `npx hyperframes
render`). Each beat is its own short 1080×1920 composition rendered to MP4; the elements
genuinely animate IN, the chart bars genuinely grow, the terminal genuinely types. The
HTML-still + Ken Burns path is demoted to a **last-resort fallback** only used if the
HyperFrames render genuinely fails (report the exact error first — never silently fall back).

Verified end-to-end (v4) 2026-05-27 (MGG "Top 20 Claude Code Skills" listicle, HOOK + #1–#6,
44.1s, 1080×1920 H.264+AAC; 7 HyperFrames compositions, all lint-clean, rendered with
`npx hyperframes render --quality high`). The recipe below is exactly what produced it. Output:
`creatives/tests/reels-preview-2026-05-27/fmt4-v4/faceless-explainer-reel-v4.mp4`. Proof-of-motion:
frames extracted at two timestamps inside the same beat differ (terminal command types on; the
two parallel bars are partway-filled at t=1.5s and fully-filled with the serial lane + `2×` badge
revealed at t=5.0s) — finite PSNR ~25–29 dB between the pairs, not `inf` (which a still would give).

## Visual doctrine (the load-bearing rule)

- **One REAL animated composition per beat**, driven by the script line + its whisper-timed window.
  Every element must animate IN (`gsap.from(...)`); charts/bars/counters must visibly change over
  the beat's duration. A frozen card with a zoom is a FAILURE of this format.
- **Brand graphics only — visual identity resolves from the BRAND, never hard-coded in this skill
  or in the brief (Visual Identity Gate — HARD GATE, resolve BEFORE writing any HTML).** Resolve in
  this order (see `f-hyperframes/SKILL.md` § "Visual Identity Gate"):
  1. **The Brand Brief** appended to the production brief (`brand_dna.guidelines` — colors, fonts,
     patterns, reference renders). This is the normal production path: the worker appends it
     automatically; use its exact palette + typography.
  2. **A brand `DESIGN.md` / `visual-style.md`** if one is referenced.
  3. **A user-named style** → `f-hyperframes/visual-styles.md` presets.
  4. **None of the above** → dark-premium default (`f-hyperframes/palettes/dark-premium.md`).
  Reaching for `#333`, `#3b82f6`, or `Roboto` = you skipped this gate. Glow + faint grid behind the
  content so the background never reads flat; a giant faint "ghost" number/glyph behind each card
  for depth.
- **GHOST GLYPH — MANDATORY: the giant background ghost is a thematic number or single letter, never
  a placeholder word.** Use the beat's index (`01`, `02`, …), the listicle total (`5`), or a single
  on-theme initial — and a real value, never a layout/dev label. Round-1 certification shipped a beat
  whose ghost literally spelled **"CTA"** (a placeholder label that bled through as the background
  glyph) — that reads as an unfinished template. If the ghost text isn't a number or a deliberate
  thematic letter you chose for THAT beat, it's wrong.
- **NEVER** drop random stock footage or AI-generated b-roll clips behind the cards. If a beat needs
  a visual you don't have, build the diagram — don't reach for a clip.
- **Font caveat:** if the brand's display font does not auto-resolve in the HyperFrames compiler
  (e.g. Barlow Condensed — see the font gotcha in Step 4), substitute the closest auto-resolving
  face (Oswald for condensed display) and note the substitution in your output. Never let a
  non-resolving font silently fall back to a generic.

## Inputs / Params

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `$SCRIPT` | Yes | — | Path to the script (markdown). HOOK + listicle beats. |
| `$OUT_DIR` | Yes | — | Output folder (mkdir -p). |
| `$VOICE_ID` | No | `$ELEVENLABS_DEFAULT_VOICE_ID` | ElevenLabs voice (c-audio presets). |
| `$PALETTE` | No | from Visual Identity Gate | Brand palette for the graphics — resolved via the Visual Identity Gate (Brand Brief → DESIGN.md → named style → dark-premium). Never hard-code. |
| `$OUTRO` | No | brand outro 5s | Appended tail clip (must be 1080×1920 w/ audio). |
| `$TARGET` | No | 30–45s | Reel length; pick beat count to fit. |

## Tooling (verified available)

- **TTS:** ElevenLabs direct API (`eleven_turbo_v2_5`) — key `ELEVENLABS_API_KEY` in `~/.gsai/secrets.env`.
- **Timings:** `cfw-transcribe` (Gemini cloud default; MLX fast-path on macOS) → SRT. SRT timecodes are ground truth for beat windows. <!-- 05-STT removed: mlx_whisper direct call — see cfw-transcribe -->
- **Graphics (PRIMARY):** HyperFrames CLI (`npx hyperframes`, v0.6.52+) — `init` / `lint` / `render`.
  Renders a 1080×1920 GSAP composition to MP4 in seconds (a ~5s beat renders in 3–6s at `--quality high`
  on a 14-core Mac). The compiler embeds Google Fonts automatically (see the font gotcha below).
- **Composite:** `ffmpeg` (`/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg`).

## Steps (runnable)

### 1 — Write the VO script
Extract HOOK + the listicle beats you want (e.g. #1–#6 for ~40s). Write ONE continuous VO line —
spell tricky tokens for TTS (`/terminal` → "slash terminal", `todo.md` → "todo dot m d", `2x` → "twice as fast").
Save to `$WORK/vo-script.txt`.

### 2 — Generate voiceover (c-audio)
```bash
source ~/.gsai/secrets.env
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" -H "Content-Type: application/json" \
  -d "$(python3 -c "import json;print(json.dumps({'text':open('$WORK/vo-script.txt').read().strip(),'model_id':'eleven_turbo_v2_5','voice_settings':{'stability':0.5,'similarity_boost':0.75,'style':0.0}}))")" \
  --output "$WORK/vo.mp3"
```
Verify it's a real MP3 (`file vo.mp3`) and check duration fits `$TARGET`.

### 3 — Transcribe for beat timing (c-audio)
```bash
# Transcribe — Gemini in container, MLX fast-path on macOS
cfw-transcribe --input "$WORK/vo.mp3" --out "$WORK/vo.srt" --format srt
```
<!-- 05-STT removed: mlx_whisper direct call — see cfw-transcribe -->
SRT ground truth for beat windows. Gemini segment timings ±1s; for word-level accuracy use
ElevenLabs Scribe (`$ELEVENLABS_API_KEY`).
Read `vo.srt`. Map each beat (hook, #1, #2 …) to its `[start → end]` window. The **duration of
each beat's composition = the span of its VO lines** — the animated graphic for beat N plays
exactly while its VO line is spoken. Set each composition's `data-duration` to that span so the
concatenated body lines up with the VO with no per-beat audio cuts (one continuous VO bed).

Example windows from the verified v4 render (VO 39.15s):

| Beat | Window (from SRT) | data-duration | Composition |
|---|---|---|---|
| HOOK | 0.00 → 3.78 | 3.8 | big "20" + headline, glow/grid/ghost entrances |
| #1 /terminal | 3.78 → 9.10 | 5.3 | terminal types `pnpm test --run`, prints green ✓ output |
| #2 /new | 9.10 → 14.22 | 5.1 | cluttered old-session bars → arrow → one clean `/new` bar |
| #3 Read→Edit | 14.22 → 21.84 | 7.6 | Read card → SVG arrow draws on → Edit card, red ✕ row |
| #4 Parallel | 21.84 → 27.82 | 6.0 | grep+glob bars grow together vs slow serial lane, `2×` badge |
| #5 todo.md | 27.82 → 33.82 | 6.0 | checklist items check off one by one, one goes "▶ now" |
| #6 Diff view | 33.82 → 39.15 | 5.3 | diff window: red `-` / green `+` highlight, Approve/Reject chips |
| outro | 39.15 → ~44 | — | brand outro clip (keeps its own audio) |

### 4 — Author one ANIMATED HyperFrames composition per beat (PRIMARY PATH)
For EACH beat, scaffold a project and author a full-frame 1080×1920 composition whose visual is
genuinely animated and purpose-built to illustrate THAT beat's line:

```bash
cd "$WORK/gfx"
npx hyperframes init beatN-<slug> --non-interactive    # scaffold (creates index.html)
# author index.html (see structure + per-beat ideas below)
( cd beatN-<slug> && npx hyperframes lint )            # 0 errors required before render
( cd beatN-<slug> && npx hyperframes render --output beatN-<slug>.mp4 --fps 30 --quality high )
```

**Composition structure** (this is the shape the compiler expects — matches the MGG promo):

```html
<!doctype html><html><head>
  <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
  <style>/* opaque navy bg, glow, faint grid, ghost number, scene flex column */</style>
</head><body>
  <div id="root" data-composition-id="main" data-start="0" data-duration="5.3"
       data-width="1080" data-height="1920">
    <div class="bg-glow"></div><div class="grid"></div><div class="ghost">01</div>
    <div class="scene"> ...beat content with ids... </div>
  </div>
  <script>
    window.__timelines = window.__timelines || {};
    const tl = gsap.timeline({ paused: true });
    tl.from("#glow", { scale: 0.6, opacity: 0, duration: 0.8, ease: "power2.out" }, 0);
    // ...every element animates IN; charts grow; terminal types via tl.call()...
    window.__timelines["main"] = tl;   // REQUIRED — register the timeline by composition id
  </script>
</body></html>
```

**Make it genuinely move — per-beat animation ideas (each verified in v4):**
- **Terminal mockup** (`/terminal`): a window with traffic-light dots; type a command on char-by-char
  with `tl.call(() => el.textContent = cmd.slice(0,i), null, t0 + i*0.07)`, blink a `.cursor`, then
  reveal `running…` and a green output line whose checkmark is an **inline SVG** (not a `✓` char).
- **Before/after slide** (`/new`): an "old session" panel whose context bars `scaleX` in to fill
  (clutter), a green **SVG arrow** that pops + nudges, then a "clean" panel with ONE short bar + a badge.
- **Drawing arrow + flow** (`Read → Edit`): two icon cards; the connecting SVG arrow draws on via
  `strokeDasharray`/`strokeDashoffset` tweened to 0; a red **SVG cross** row slams in.
- **Growing bar chart** (`Parallel`): two `.fill` bars `scaleX` from 0→1 AT THE SAME TIME (parallel),
  contrasted with a serial lane whose two bars grow ONE AFTER THE OTHER; a `2x` badge pops at the end.
- **Checklist that checks off** (`todo.md`): items `.add("done")` via `tl.call()` on a stagger, each
  box punching scale 1→1.25→1, with strike-through; one item flips to an active state marked with an
  **SVG triangle** (not a `▶` char).
- **Diff highlight** (`Diff view`): a `-` red line and `+` green line slide in; flash their background
  with `fromTo(..., {backgroundColor}, {backgroundColor, yoyo:true, repeat:1})`; Approve/Reject chips pop.

> Every icon above is a SHAPE you draw (SVG/CSS), not a character you type. See the ICONS rule below.

**HyperFrames rules that matter here (from f-hyperframes house style):**
- Register the timeline as `window.__timelines["<data-composition-id>"]`, `paused: true`.
- `data-duration` is authoritative (not the GSAP timeline length) — set it to the beat's VO span.
- Every element animates IN via `gsap.from()`; **no exit animations** except the final element fade.
- Vary eases (use ≥3 different eases per beat); stagger entrances; keep ambient glow/grid alive.
- **AMBIENT MOTION — MANDATORY: no beat may freeze.** A beat whose elements all pop in over the first
  ~1s and then hold a static frame for the rest of its window reads as a slideshow card, not a motion
  graphic (round-1 certification: a beat sat frame-identical for 2s after its entrance — PSNR ≈ 64dB
  between two mid-beat frames). Give EVERY beat continuous low-amplitude motion that runs the whole
  `data-duration`: a slow `yoyo`/`repeat:-1` drift or pulse on the glow/grid/ghost, a gentle scale or
  opacity breathe on the focal element, a cursor blink, a counter still ticking, a bar still easing.
  Stagger the entrances LATER into the window (don't cram them all into the first second) so the beat
  keeps revealing through its duration. Target: pick any two frames ≥1s apart inside a beat and they
  must visibly differ (the Step 8 motion proof enforces this).
- **Font gotcha:** the compiler resolves `font-family` literally and auto-embeds the named Google
  Font. Use auto-resolved faces — **`Oswald`** (condensed display) + **`JetBrains Mono`** (code/data)
  are confirmed to resolve. Do NOT use `var(--font-*)` in `font-family` (falls back to a generic),
  and avoid Barlow Condensed (does not auto-resolve → wrong-font fallback). Inter also resolves but
  is house-style-discouraged; Oswald + JetBrains Mono is the proven pairing for this format.
- **ICONS — MANDATORY: never use a unicode emoji or icon-font glyph as an icon.** The headless
  render has **no emoji font installed**, so every emoji (📊 🏢 🔒 😐 ⚡ 🤖 …) and every
  private-use icon-font codepoint renders as a **`□` "tofu" box** — a visible defect (round-1
  certification: the AGENCY card and a "you vs them" circle both came out as empty boxes). Coverage
  is roulette: one emoji may render while the next on the same beat does not, so "it worked once" is
  not safe. Build EVERY icon/glyph as **inline SVG or CSS shapes** (an `<svg>` path, a styled `<div>`,
  a CSS-drawn checkmark/arrow/lightning), never a character. The only safe text characters are plain
  ASCII letters/digits/punctuation in the resolved Latin fonts (Oswald / JetBrains Mono) — and even
  there, avoid decorative dingbats like `✓ ✕ → ▶ ⚡`; draw those as SVG too. If you catch yourself
  typing an emoji into the HTML, that's the bug — replace it with an SVG before rendering.
- `npx hyperframes lint` MUST be 0 errors before render. `--quality high` for delivery, `--quality
  draft` while iterating. If render fails, run `npx hyperframes doctor` and report the exact error.

### Scene sequencing — MANDATORY (one beat visible at a time)

> **Failure mode this prevents (from the p-hf-reel certification):** a live render stacked EVERY
> text beat on screen at once — headlines from different beats jumbled on top of each other —
> because the scenes had no explicit timing and all rendered simultaneously. The rules below make
> that impossible.

- **The fmt4 default architecture already enforces this BETWEEN beats:** one composition per beat,
  rendered separately and concatenated in Step 5 — two beats can never share a frame. Do NOT
  "optimize" by lumping all beats into one big untimed composition; that is exactly the layout that
  produced the overlap failure.
- **If you ever do author a multi-beat composition** (e.g. a single composition spanning the whole
  reel), every text beat MUST be its own clip with EXPLICIT timing: `data-start` +
  `data-duration` (never `data-end`), consecutive text beats on the **same `data-track-index`** so
  the framework itself forbids overlap (same-track clips cannot overlap — `f-hyperframes/SKILL.md`
  § "Data Attributes"). Exactly ONE beat's text visible at any timestamp.
- **WITHIN a single beat's composition:** any element that appears later than t=0 starts fully
  hidden — CSS `opacity: 0; visibility: hidden` as the static state, or `tl.set(selector,
  { autoAlpha: 0 }, 0)` at the timeline head — and is revealed by its entrance tween. Never
  `gsap.set()` on clip elements from later scenes (they don't exist in the DOM at page load).
  Never let an element that should animate in at t=2s sit fully-formed on screen from t=0.
- **Map each beat's window to its VO phrase timestamps** from the SRT (Step 3). The SRT is ground
  truth — do not eyeball the windows.

### Local media — MANDATORY (download + ffprobe before authoring; never remote URLs)

> **Failure mode this prevents (from the p-hf-reel certification):** a live render referenced
> remote media URLs directly inside the composition and they NEVER appeared — remote `http(s)://`
> URLs silently fail to load inside the headless browser render.

- **BEFORE authoring any HTML**, download every media file the composition will reference (logo,
  outro clip, any image/video the brief supplies) to a local file in the work dir and probe it:

  ```bash
  curl -L -o asset_N.<ext> "<asset_url_N>"
  ffprobe -v error -show_entries format=duration -show_entries stream=codec_type \
    -of default=noprint_wrappers=1 asset_N.<ext>     # videos: must show codec_type=video + duration
  file asset_N.<ext>                                  # images/fonts: must show the real type
  ```

  If a download fails or the probe shows the wrong type, STOP and report it — do not silently skip
  the asset or fall back to the remote URL.
- **Reference ONLY local relative paths** inside compositions (`<img src="asset_1.png">`,
  `<video src="asset_2.mp4" muted playsinline>`). **NEVER put a remote `http(s)://` URL in any
  `src`** — it will not load in the headless render and the element comes out blank. (The only
  exception: the GSAP CDN `<script>` tag, which the compiler handles.)
- The `$OUTRO` clip is consumed by ffmpeg in Step 7, not inside a composition — but the same rule
  applies: it must be a local file, downloaded + ffprobed first if the brief supplied it as a URL.

### 5 — Concat the animated beat segments (c-ffmpeg)
Each rendered beat is already 1080×1920 MP4 with no audio. Normalize to a uniform encode (30fps,
yuv420p) and concat in order (absolute paths in the list):
```bash
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
for b in beat0-hook beat1-terminal beat2-new beat3-readedit beat4-parallel beat5-todo beat6-diff; do
  $FF -y -i "gfx/$b/$b.mp4" -vf "scale=1080:1920,setsar=1,fps=30,format=yuv420p" -an \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "seg-$b.mp4"
  echo "file '$PWD/seg-$b.mp4'" >> seglist.txt
done
$FF -y -f concat -safe 0 -i seglist.txt -c copy body-video.mp4
```

### 6 — Mux the VO onto the body (c-ffmpeg)
The graphics carry no audio — map the VO straight onto the concatenated body video. Because each
beat's `data-duration` matched its VO window, the graphics and narration stay in sync:
```bash
$FF -y -i body-video.mp4 -i vo.mp3 \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 -shortest body.mp4
```

### 7 — Append outro + final encode (c-ffmpeg)
Outro fps/sample-rate usually differ (25fps / 48k mono) — normalize via filter concat:
```bash
$FF -y -i body.mp4 -i "$OUTRO" -filter_complex "\
[0:v]scale=1080:1920,fps=30,setsar=1[v0];[1:v]scale=1080:1920,fps=30,setsar=1[v1];\
[0:a]aresample=48000,aformat=channel_layouts=stereo[a0];[1:a]aresample=48000,aformat=channel_layouts=stereo[a1];\
[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.0 -preset medium -crf 18 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "$OUT_DIR/faceless-explainer-reel.mp4"
```
**No `#` comments inside `filter_complex`** and **no stray newlines mid-filter** — both cause ffmpeg
parse errors. Keep long graphs in a `.sh` script.

### 8 — Visual QA Gate (MANDATORY — uses your vision + proof of motion)

> A render that was never looked at is NOT done. The failures that broke live reels (text beats
> stacked on screen at once; media that never appeared; stills pretending to be animations) are
> ALL invisible to ffprobe — they only show up when you actually LOOK at the frames. This gate is
> non-negotiable.

First, the mechanical checks (decode + container):

```bash
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -show_entries format=duration -of default=nw=1 OUT.mp4
$FF -v error -i OUT.mp4 -f null -                                  # clean decode = no output
$FF -sseof -4 -i OUT.mp4 -af volumedetect -f null - 2>&1 | grep mean_volume   # outro tail has audio
```

Assert 1080×1920 (9:16), both video+audio streams, duration in `$TARGET`, clean decode.

**Then extract 6 sample frames spread across the duration** (at 5%, 20%, 40%, 60%, 80%, 95% of the
reel length — compute each `<t>` from the ffprobed duration, e.g. `<t> = 0.40 * DURATION`):

```bash
# DURATION = ffprobed reel length in seconds; compute t at 5/20/40/60/80/95%
for pct in 05 20 40 60 80 95; do
  $FF -y -ss <t_pct> -i OUT.mp4 -frames:v 1 qa_frame_$pct.png
done
```

**READ each `qa_frame_N.png` — you (the executing agent) have vision. Actually open and look at
every frame.** For each frame, CHECK:

- [ ] **(a) No overlapping / jumbled text** — every visible word belongs to exactly ONE beat. Two
      beats' text stacked on top of each other = the scene sequencing failed → fix the beat
      composition / clip timing in Step 4 and re-render.
- [ ] **(b) The visual is a brand motion graphic** — a diagram/terminal/chart/checklist in the
      brand palette, never a photo, never stock footage, never a blank/dark rectangle where an
      asset should be (blank = a remote URL that wasn't localized → fix per the Local-media gate).
- [ ] **(c) Text legible at mobile size** — 60px+ headlines, 20px+ body, AA contrast clear (re-run
      `hyperframes validate` if unsure).
- [ ] **(d) Brand colors correct** — the palette matches the Visual Identity Gate resolution (Brand
      Brief first); not washed out, not defaulted to white-on-black, not this skill's old
      hard-coded colors.
- [ ] **(e) No `□` tofu boxes / missing-glyph rectangles** — scan every frame for an empty box where
      an icon should be. One `□` = a unicode emoji/icon-font glyph that didn't render → replace that
      icon with inline SVG (per the ICONS rule, Step 4) and re-render. This is the single most common
      round-1 defect; look for it specifically.
- [ ] **(f) No placeholder ghost text** — the giant background ghost glyph is a thematic number/letter
      (`01`, `5`), never a layout/dev word like "CTA", "HEADER", "TITLE". A word-shaped ghost = a
      placeholder that leaked → fix in Step 4 and re-render.

**Then prove EVERY beat actually MOVES (not just layout)** — for each beat, extract two frames at
different timestamps WITHIN that beat's window and confirm they differ (a still would be identical
→ `inf` PSNR):

```bash
# for each beat N with window [start, end): pick t_early = start + 25% span, t_late = start + 75% span
$FF -y -ss <t_early> -i OUT.mp4 -frames:v 1 beatN_a.png
$FF -y -ss <t_late>  -i OUT.mp4 -frames:v 1 beatN_b.png
$FF -i beatN_a.png -i beatN_b.png -lavfi psnr -f null - 2>&1 | grep average
# PASS: average PSNR ≤ 45 dB (frames visibly differ → real motion through the window).
# FAIL: 'inf' (frozen still) OR ≥ 50 dB (near-identical → elements popped in then HELD static, the
#       slideshow failure). A beat that fails = add continuous ambient motion (Step 4 "AMBIENT
#       MOTION" rule) and re-render. Test BOTH the early-vs-mid AND mid-vs-late halves so a beat that
#       moves only in its first second is caught.
```

A mid-beat frame must show the animation partway (a bar half-grown, a command half-typed, a
checklist mid-check). Also confirm: **VO is the clear foreground**, **no static-or-near-static stretch
> 2s** (every >2s window must show visible change — ambient drift counts, a frozen card does not).

**If ANY check on ANY frame or ANY beat fails: fix the composition and RE-RENDER. Re-extract the
frames and look again. Repeat until everything passes. NEVER upload a reel that fails this gate.**

### 9 — Upload to R2 and print the URL (LAST LINE)

The rendered file on local disk is NOT the deliverable — in production the worker recovers the
result by scraping your reply for an R2/CDN media URL. No uploaded URL = the job reports
"finished without producing an asset" and FAILS, even if the render was perfect.

Upload the final reel via the `r2-upload` helper (`c-cloud-media`):

```bash
# → r2-upload (c-cloud-media). Returns the public CDN URL.
bash _scripts/upload-to-recordings.sh "$OUT_DIR/faceless-explainer-reel.mp4"   # → https://media.cfw.social/.../<file>.mp4
```

Then clean up the per-run working dir (disk hygiene — the worker volume is small): once the URL is
confirmed, `rm -rf` the interim gfx/audio working files.

**Print the R2 public URL as the final line of output.** NEVER print an input URL (script source,
outro clip, reference image) as the result — the result is the freshly rendered, uploaded reel.

## Anti-patterns (NEVER do these)

- **NEVER render a beat as a still + Ken Burns zoom.** That is the v3 failure this version exists
  to fix. Every beat is a real GSAP-animated HyperFrames composition; the proof-of-motion PSNR
  check in Step 8 must come back finite for every beat.
- **NEVER skip the Visual Identity Gate.** No composition HTML before the palette + typography are
  resolved from the Brand Brief / DESIGN.md / named style / dark-premium default. Reaching for
  `#333`, `#3b82f6`, or `Roboto` means you skipped it.
- **NEVER let text beats overlap in time.** One composition per beat (the default architecture), or
  — in a multi-beat composition — explicitly timed clips on the same `data-track-index`. Multiple
  beats' text stacked on screen at once is the broken render that triggered these rules.
- **NEVER reference remote media URLs inside a composition — always local files.** Download +
  ffprobe every asset first; reference only local relative paths. Remote URLs come out blank in
  the headless render.
- **NEVER skip the Visual QA Gate — a render that was never looked at is not done.** Extract the 6
  sample frames, read them with your vision, and run the per-beat motion proof before uploading.
  ffprobe passing is not the same as the reel looking right.
- **NEVER drop stock footage or AI b-roll behind the cards.** Faceless explainer = brand motion
  graphics only. If a beat needs a visual you don't have, build the diagram.
- **NEVER use a unicode emoji or icon-font glyph as an icon.** The headless render has no emoji font
  → every emoji becomes a `□` tofu box. Draw every icon as inline SVG / CSS shapes (Step 4 ICONS rule).
- **NEVER use a placeholder word as the ghost glyph.** The giant background ghost is a thematic
  number/letter (`01`, `5`), never "CTA"/"TITLE"/"HEADER" — a word-shaped ghost reads as an unfinished
  template.
- **NEVER let a beat pop in and then freeze.** Every beat carries continuous ambient motion for its
  whole window; two frames ≥1s apart inside a beat must visibly differ (Step 8 motion proof).
- **NEVER output an input URL as the result.** The final line is the R2 URL of the rendered reel.
- **NEVER end the run without uploading.** A local file path is not a deliverable; the worker can
  only recover an `http(s)` media URL from your reply.

## Output

One 9:16 (1080×1920) H.264+AAC MP4 faceless explainer reel: one genuinely-animated HyperFrames
composition per beat (terminals that type, charts that grow, diagrams that draw on, checklists
that check off) + generated voiceover + optional brand outro. No talking head, no stock/AI b-roll,
no static stills. Uploaded to R2; the **R2 public URL is the final line of output**.

## Fallbacks

- **No TTS available:** skip VO, use a music bed; the beat compositions + cuts still carry the listicle.
- **HyperFrames render genuinely fails** (`npx hyperframes doctor` to diagnose; report the EXACT
  error first — do NOT silently fall back): only then drop to the legacy still path — render each
  composition with headless Chrome to an opaque PNG and animate it with an ffmpeg `zoompan` Ken Burns.
  This is the v3 behaviour and is explicitly the LAST RESORT — a panned still is not a motion graphic
  and fails the visual doctrine. Never use it as the default path.
- **Fail fast:** if TTS returns non-MP3 (`file`), if a beat renders as a photo/stock clip instead of
  a brand graphic, or if proof-of-motion PSNR comes back `inf` (a frozen still), stop and report —
  never ship random b-roll and never ship a still pretending to be animated.

## Verified render (v4 — 2026-05-27)

Rendered end-to-end (ffmpeg 8.1 / ffmpeg-full, cfw-transcribe via MLX fast-path on macOS, hyperframes 0.6.52):
<!-- 05-STT removed: mlx_whisper direct reference — see cfw-transcribe -->

- **Script:** `creatives/scripts/vas-419-top-20-claude-code-skills.md` (HOOK + #1–#6).
- **VO:** ElevenLabs `eleven_turbo_v2_5` (39.15s), timed with `cfw-transcribe --format srt`
  (Gemini in container, MLX fast-path on macOS) → SRT; each beat's `data-duration` set to its
  SRT span so graphics play during their spoken line (one continuous VO bed).
- **Graphics (PRIMARY path — 7 HyperFrames compositions, all `hyperframes lint` 0 errors, rendered
  `npx hyperframes render --quality high`):**
  - HOOK (3.8s) — big "20" + "Skills Most Devs Never Use", glow/grid/ghost + staggered entrances
  - #1 /terminal (5.3s) — terminal types `pnpm test --run` char-by-char, prints green `✓ 42 passed`
  - #2 /new (5.1s) — old-session context bars fill (clutter) → arrow nudges → clean `/new` panel + badge
  - #3 Read→Edit (7.6s) — Read card, SVG arrow DRAWS on (strokeDashoffset), Edit card, red `✕ no hallucinated lines`
  - #4 Parallel (6.0s) — grep+glob bars `scaleX` grow TOGETHER vs a serial lane growing one-after-other, `2×` badge pops
  - #5 todo.md (6.0s) — checklist items check off on a stagger (box punch + strike-through), one flips to "▶ now"
  - #6 Diff view (5.3s) — diff window red `-` / green `+` lines slide + flash, Approve/Reject chips pop
  - outro — `brand-assets/outros/mgg-outro-vertical-5s.mp4`
- **Fonts:** Oswald (display) + JetBrains Mono (code/data) — both auto-resolved by the HyperFrames
  compiler from Google Fonts. (Barlow Condensed avoided — does not auto-resolve.)
- **Technique:** per-beat 1080×1920 HyperFrames compositions (GSAP timelines registered in
  `window.__timelines["main"]`) rendered to MP4; concatenated in SRT order; VO muxed once as the
  continuous bed; outro appended via filter concat. **No stills, no Ken Burns.**
- **Result:** `creatives/tests/reels-preview-2026-05-27/fmt4-v4/faceless-explainer-reel-v4.mp4` —
  1080×1920, 30fps, 44.11s, H.264 high/yuv420p + AAC stereo 48k, ~4.9 MB, clean decode. Proof-of-motion:
  finite PSNR ~25–29 dB between two-timestamp frame pairs inside the terminal/parallel/todo beats (a
  still would be `inf`); frame spot-checks show the terminal command fully typed, the parallel/serial
  bars at different fills, and the checklist mid-check. Composition sources saved under
  `fmt4-v4/work/gfx/beat*/index.html`; assembly script at `fmt4-v4/work/assemble.sh`.

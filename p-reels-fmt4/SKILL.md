---
name: p-reels-fmt4
description: Turn a script into a fully rendered explainer reel with no talking head — one REAL animated HyperFrames motion-graphics composition per beat (charts that draw/count on, terminals that type, diagrams that flow, checklists that check off) plus voiceover. NO stock/AI b-roll, NO static stills. Trigger on "make an explainer reel from this script", "faceless animated short with VO", "no-avatar explainer video", "script to animated reel with voiceover".
when-to-use: Use when the user wants a faceless explainer reel — numbered/listicle or beat-by-beat brand motion-graphics with a voiceover, NO talking-head avatar and NO random b-roll. Every beat's visual is a genuinely animated HyperFrames composition, not a still card.
version: 4.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Faceless Explainer Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-audio, c-ffmpeg, f-hyperframes, f-hyperframes-cli]
---

# p-reels-fmt4 — Script → Faceless Explainer Reel (No Talking Head)

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
- **Brand graphics only** — author HyperFrames HTML compositions in the brand explainer style.
  Palette (MGG): navy `#0f172a`, accent green `#22c55e`, light `#f1f5f9`. Glow + faint grid behind
  the content so the navy never reads flat; a giant faint "ghost" number/glyph behind each card for
  depth (the canonical MGG explainer look).
- **NEVER** drop random stock footage or AI-generated b-roll clips behind the cards. If a beat needs
  a visual you don't have, build the diagram — don't reach for a clip.
- **Source the style** from the brand's existing HyperFrames productions, e.g. the promo at
  `…/ord-20260511-001-mgg-4s-hf-promo/hyperframes/index.html` (GSAP timeline registered in
  `window.__timelines[id]`, big numbers, staggered entrances) and the v4 sources in this skill's
  verified-render section. Brand HTML style ref: `creatives/tests/explainer-style-template.html`.

## Inputs / Params

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `$SCRIPT` | Yes | — | Path to the script (markdown). HOOK + listicle beats. |
| `$OUT_DIR` | Yes | — | Output folder (mkdir -p). |
| `$VOICE_ID` | No | `$ELEVENLABS_DEFAULT_VOICE_ID` | ElevenLabs voice (c-audio presets). |
| `$PALETTE` | No | navy/green/light | Brand palette for the graphics (MGG: `#0f172a` / `#22c55e` / `#f1f5f9`). |
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
  reveal `running…` and a green `✓ N passed` output line.
- **Before/after slide** (`/new`): an "old session" panel whose context bars `scaleX` in to fill
  (clutter), a green arrow that pops + nudges, then a "clean" panel with ONE short bar + a badge.
- **Drawing arrow + flow** (`Read → Edit`): two icon cards; the connecting SVG arrow draws on via
  `strokeDasharray`/`strokeDashoffset` tweened to 0; a red `✕` row slams in.
- **Growing bar chart** (`Parallel`): two `.fill` bars `scaleX` from 0→1 AT THE SAME TIME (parallel),
  contrasted with a serial lane whose two bars grow ONE AFTER THE OTHER; a `2×` badge pops at the end.
- **Checklist that checks off** (`todo.md`): items `.add("done")` via `tl.call()` on a stagger, each
  box punching scale 1→1.25→1, with strike-through; one item flips to an "▶ now" active state.
- **Diff highlight** (`Diff view`): a `-` red line and `+` green line slide in; flash their background
  with `fromTo(..., {backgroundColor}, {backgroundColor, yoyo:true, repeat:1})`; Approve/Reject chips pop.

**HyperFrames rules that matter here (from f-hyperframes house style):**
- Register the timeline as `window.__timelines["<data-composition-id>"]`, `paused: true`.
- `data-duration` is authoritative (not the GSAP timeline length) — set it to the beat's VO span.
- Every element animates IN via `gsap.from()`; **no exit animations** except the final element fade.
- Vary eases (use ≥3 different eases per beat); stagger entrances; keep ambient glow/grid alive.
- **Font gotcha:** the compiler resolves `font-family` literally and auto-embeds the named Google
  Font. Use auto-resolved faces — **`Oswald`** (condensed display) + **`JetBrains Mono`** (code/data)
  are confirmed to resolve. Do NOT use `var(--font-*)` in `font-family` (falls back to a generic),
  and avoid Barlow Condensed (does not auto-resolve → wrong-font fallback). Inter also resolves but
  is house-style-discouraged; Oswald + JetBrains Mono is the proven pairing for this format.
- `npx hyperframes lint` MUST be 0 errors before render. `--quality high` for delivery, `--quality
  draft` while iterating. If render fails, run `npx hyperframes doctor` and report the exact error.

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

### 8 — Verify (ffprobe + decode + PROOF OF MOTION)
```bash
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -show_entries format=duration -of default=nw=1 OUT.mp4
$FF -v error -i OUT.mp4 -f null -                                  # clean decode = no output
$FF -sseof -4 -i OUT.mp4 -af volumedetect -f null - 2>&1 | grep mean_volume   # outro tail has audio
```
Assert 1080×1920 (9:16), both video+audio streams, duration in `$TARGET`, clean decode. Then
**prove the graphics actually MOVE** — extract two frames at different timestamps WITHIN one beat
and confirm they differ (a still would be identical → `inf` PSNR):
```bash
$FF -y -ss <t_early> -i OUT.mp4 -frames:v 1 a.png
$FF -y -ss <t_late>  -i OUT.mp4 -frames:v 1 b.png
$FF -i a.png -i b.png -lavfi psnr -f null - 2>&1 | grep average   # finite dB (≈25–29) = motion; 'inf' = a frozen still (FAIL)
```
Eyeball a frame from each beat: it must be a brand graphic (navy/green diagram/terminal/chart),
never a photo, and a mid-beat frame must show the animation partway (e.g. a bar half-grown, a
command half-typed).

## Output

One 9:16 (1080×1920) H.264+AAC MP4 faceless explainer reel: one genuinely-animated HyperFrames
composition per beat (terminals that type, charts that grow, diagrams that draw on, checklists
that check off) + generated voiceover + optional brand outro. No talking head, no stock/AI b-roll,
no static stills.

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

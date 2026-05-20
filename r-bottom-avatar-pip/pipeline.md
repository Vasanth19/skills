# Pipeline — r-bottom-avatar-pip

24-step production sequence. For HeyGen mode details see `heygen-workflow.md`. For first-frame rule see `first-frame-rule.md`. For acceptance criteria see `acceptance.md`.

---

1. **`task-create-production-folders`** — create `MM.DD-<title>/` (month.day + kebab-title, e.g. `05.14-knowai-gemini-docs`) with `final/`, `renders/`, `heygen/`
2. **`script-write-short`** — if topic given instead of full script, draft 45-60 words
3. **`script-preprocess-tts`** — clean for HeyGen (expand abbreviations, strip markdown)
4. **`script-analyze-duration`** + **`script-rewrite-to-duration`** — hit `targetDuration` ±2s at natural pace
   - As of 2026-05-17 HeyGen renders come pre-speedened upstream. Pass `speed=1.0` — no post-multiplier.
   - Example: `targetDuration=20s` → write for ~48 words at 145 wpm. What HeyGen returns is the duration you ship.
5. **HeyGen render** — default `heygen-request-human`. Post render spec as a Paperclip comment, halt. Resume when a comment matching `heygen_video_id: <id>` appears. See `heygen-workflow.md` for full mode decision.
6. **`heygen-poll-download`** — poll + download to `production/heygen/raw-avatar.mp4`
7. **(removed 2026-05-17)** — no post-speed adjust step. Pass `heygen/raw-avatar.mp4` directly to downstream steps. Pre-2026-05-17 productions used `heygen/raw-avatar.mp4` here.
8. **Detect avatar background** — sample 8 edge pixels at 3 timestamps on `heygen/raw-avatar.mp4`. See `brand-params.md` for detection logic and branch rules.
9. **`broll-library-read`** — parse `creatives/brolls/<theme>-broll-library.md`
10. **`broll-match-to-script`** — pick b-rolls matching script beats
11. **`broll-placement-plan-portrait`** — time b-rolls against voiceover (9:16 full-frame layout)
12. **`broll-extract-clip`** — cut specific sections from source b-roll
13. **Remotion scene authoring constraint** — when writing TSX scenes for this order, scene 1 MUST render visible brand-content at frame 0. No fade-in from black/navy.
14. **`ffmpeg-concat`** — stitch b-rolls to cover duration
15. **Chroma-key (CONDITIONAL — only if `bg_type=green_screen` from step 8)**
    - Input: `heygen/raw-avatar.mp4` (speed-adjusted), never the raw
    - Green-screen → `ffmpeg-colorkey-composite` strips `#00FF00` → transparent, feed alpha'd avatar to step 16
    - Opaque → skip entirely; avatar retains its bg inside the PIP frame
16. **`ffmpeg-compose-portrait-bottom-avatar`** — PIP compose per `brand-params.md` spec. Works for both alpha'd and opaque avatars. Avatar source = `heygen/raw-avatar.mp4`.
17. **`ffmpeg-loudnorm`** — normalize audio levels
18. **`caption-burn`** — (optional) burn word-level karaoke captions
19. **Outro append** — `ffmpeg-outro-append`. Outro MUST have audio (CTA voiceover or brand music sting).

    **CRITICAL — channel layout must match across concat boundary.** Composed video = stereo 48kHz. If the outro source is mono (MGG's `mgg-outro-cta-vertical.mp4` is mono 44.1kHz), re-encode first:

    ```bash
    ffmpeg -y -i <outro-source>.mp4 \
      -vf "scale=1080:1920,setsar=1,fps=30" \
      -af "aformat=sample_rates=48000:channel_layouts=stereo" \
      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30 -fps_mode cfr \
      -c:a aac -b:a 192k -ar 48000 -ac 2 \
      renders/outro-normalized.mp4
    ```

    Use the **concat filter** (not concat demuxer) to stitch — filter re-encodes cleanly; demuxer `-c copy` preserves per-packet channel config → knocking/jitter artifact.

    **Verify no-jitter:**
    ```bash
    ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels -of csv=p=0 renders/composed.mp4
    ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels -of csv=p=0 renders/outro-normalized.mp4
    # Both must print: 48000,2
    ```

    **Verify outro audio present:**
    ```bash
    ffmpeg -y -sseof -5 -i <composed-with-outro>.mp4 -af volumedetect -f null - 2>&1 | grep mean_volume
    # mean_volume must be > -60 dB
    ```

20. **`cover-frame-generate`** — produce `final/cover.png` (1080×1920). Required, not optional.
21. **Prepend cover as first frame** — single-pass ffmpeg encode per `first-frame-rule.md`. Output: `final/short.mp4`.
22. **First-frame sanity check** — `MAX_BROLL > 0x30` per `first-frame-rule.md`. Fail-fast if it doesn't pass.
23. **`ffmpeg-verify-output`** + **`ffmpeg-delivery-checklist`** — QA pass (12 mandatory checks)
24. **CONDITIONAL — landscape long-form only:** if `format=landscape-vsl` and final duration ≥ 60s, run **`capture-thumbnail-generation`** (Path A — HTML + brand palette, default; Path B — Nano Banana / Floe AI gen, optional). Output: `final/thumbnail-yt.jpg` (1280×720 JPG, ≤ 2 MB).
    - Brand palette tokens for the HTML template (`_skills/capture-thumbnail-generation/template-html-brand.html`):
      ```
      --bg: #0F172A          (deep navy)
      --primary: #F97316     (coral orange — TRAP/hook word)
      --secondary: #06B6D4   (teal cyan — sub-accent)
      --text: #FFFFFF
      ```
    - Avatar cutout: reuse `creatives/brolls/avatar/cutout.png` if present, else extract via `ffmpeg -ss 25 -frames:v 1` and chroma-key.
    - **Hard rule:** Shorts SKIP this step (Shorts use first-frame as feed thumbnail). Long-form REQUIRES it — the CMO will reject the publish handoff if `final/thumbnail-yt.jpg` is missing.
    - Reference impl: VAS-71 (`creatives/productions/ord-20260426-001-hermes-vsl-v2/temp/thumbnail/thumbnail-v2.html`).
25. **`cloud-r2-upload`** (optional) — publish video + cover to CDN. For long-form, also upload `final/thumbnail-yt.jpg`.

**Re-render on post-launch feedback:** re-run steps 14–24 on the cached `production/heygen/raw-avatar.mp4`. Update `final/short.mp4`, `final/cover.png`, and (long-form) `final/thumbnail-yt.jpg` if spec changed. Flag for re-upload. Do NOT only update the recipe — apply the fix to the flagged deliverable too.

---

## Production Learnings (2026-05-17)

### Ken Burns safe zoom
Use `zoompan=z='min(zoom+0.00017,1.05)'` — max 1.05×. The old 1.15× crops ~81px per side at peak, visibly cutting off right-edge HTML content. At 1.05× only 27px/side is cropped. Safe with 120px HTML horizontal padding.

### HTML segment padding (hard rule)
All HTML segments MUST use `padding: 0 120px` (or wider) on the body. Anything rendered outside x=120 to x=960 risks clipping at 1.05× zoom. Set `width:1080px` on body but keep live content within the inner 840px.

### HeyGen resolution varies — auto-detect crop
HeyGen renders at 1920×1080 OR 1280×720 depending on the template/plan. Always `ffprobe` the avatar before composing:
```bash
ffprobe -v error -show_entries stream=width,height -of default=noprint_wrappers=1 heygen/raw-avatar.mp4
```
Then compute square crop: `short_side = min(w, h)`, `x_offset = (w - short_side) / 2`, crop = `crop={short_side}:{short_side}:{x_offset}:0`.

### Paperclip: set projectId before assigning non-C-suite agent
PATCH with `projectId` first, then PATCH `status + assigneeAgentId`. Sending both in one call returns 422 if no project is set.

### Reuse pip-mask.png across productions
PIL may not be in PATH. Copy `pip-mask.png` from the previous production rather than regenerating each time. The mask is identical for all reels (540×540, r=54).

### Real tool website screenshots — Cloudflare blocks headless Chrome
Perplexity.ai and Claude.ai both return Cloudflare bot-verification pages to headless Chrome. Use `claude-in-chrome` MCP (user's live browser session) to capture real tool UIs instead.

### HTML segments — use Chrome headless, not Playwright CLI
`npx playwright screenshot` requires browser binaries installed via `npx playwright install`. Avoid; use Chrome directly:
```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-sandbox \
  --window-size=1080,1920 \
  --screenshot="output.png" "file:///abs/path/to/segment.html"
```
Writes directly to the path. Fast, no extra deps.

### Real tool scroll b-roll — screenshot → scroll clip
Browser screenshots from `claude-in-chrome` land as 1080×2400 PNGs. Convert to a scrolling video clip:
```bash
# DURATION=7s, MAX_OFFSET=2400-1920=480
ffmpeg -y -loop 1 -i screenshot.png \
  -vf "crop=1080:1920:0:'min(480,480*n/209)',fps=30,format=yuv420p" \
  -t 7 -r 30 -c:v libx264 -preset medium -crf 18 -an scroll.mp4
```
Frame formula: `n/(frames-1)` where frames = duration × 30. Use these as b-roll clips alongside designed HTML segments. No audio track on scroll clips; avatar audio carries through.

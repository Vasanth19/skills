# Pipeline — r-screen-rec-vo

Step-by-step. For scene details see `scene-bank.md`. For anti-patterns/gotchas see `anti-patterns.md`. For DoD see `acceptance.md`.

---

### Step 1 — HeyGen render

Standard brand voice, Marcus avatar (or whichever brand config points at). The visual is discarded — you still need HeyGen for the voice. Do not substitute ElevenLabs unless the brand config authorizes it.

### Step 2 — Speed-adjust

```bash
ffmpeg -y -i heygen/raw-avatar.mp4 \
  -filter:v "setpts=PTS/1.25" \
  -filter:a "atempo=1.25" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30 \
  heygen/avatar_1.25x.mp4
```

Target check: final audio duration should land inside `35-46s`. If raw <45s, `1.1×` may be fine; if raw >50s, use `1.25×`. See `brand-params.md`.

### Step 3 — Extract VO audio (discard video)

```bash
ffmpeg -y -i heygen/avatar_1.25x.mp4 -vn -c:a aac -b:a 192k -ar 48000 -ac 2 \
  renders/marcus-vo.aac
```

### Step 4 — Remotion full-frame 7-scene broll

Copy the most recent `r-screen-rec-vo` Remotion project as a template (e.g., `ord-20260421-003-mgg-day2-cold-email-prompt/gfx/remotion/`). Fresh `npm install` in the new order folder — pnpm-installed `node_modules` do not survive a filesystem copy.

Budget the scenes against the extracted audio length. Example for 42.56s VO:

| # | Scene | Budget (f @ 30fps) | Beat |
|---|---|---|---|
| 1 | SceneHook | 80 | 3-line text hook |
| 2 | SceneClaudeUiIdle | 60 | Empty Claude shell, cursor blinking |
| 3 | ScenePromptReveal | 490 | Prompt typewriter in monospace |
| 4 | SceneResponseReveal | 270 | AI response renders + 3 callout pills |
| 5 | SceneProof | 145 | Big result number + timeline pill |
| 6 | SceneCta | 195 | Comment mock + DM card |
| 7 | SceneDayCount | 60 | Day N / 100 + handle |
| **Total** | **1300f** | **43.33s** (+23f margin over 42.56s audio) |

```bash
cd gfx/remotion && ./node_modules/.bin/remotion render ColdEmailShort out/broll.mp4 --log=info --concurrency=2
```

### Step 5 — Compose video + VO + loudnorm

```bash
ffmpeg -y -i gfx/remotion/out/broll.mp4 -i renders/marcus-vo.aac \
  -filter_complex "[0:v]null[outv];[1:a]loudnorm=I=-16:TP=-1.5:LRA=11[outa]" \
  -map "[outv]" -map "[outa]" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30 -fps_mode cfr \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -shortest \
  renders/composed.mp4
```

`-shortest` trims the video to the audio's exact duration. No PIP overlay step.

### Step 6 — Append outro + canonical re-encode

```bash
# normalize outro if needed
cp brand-assets/outros/mgg-outro-vertical-5s.mp4 renders/outro-normalized.mp4

# concat list
echo "file 'composed.mp4'" > renders/concat-list.txt
echo "file 'outro-normalized.mp4'" >> renders/concat-list.txt
ffmpeg -y -f concat -safe 0 -i renders/concat-list.txt -c copy renders/composed-with-outro.mp4

# canonical re-encode (concat -c copy breaks time_base + introduces B-frames from outro source)
ffmpeg -y -i renders/composed-with-outro.mp4 \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30 -fps_mode cfr \
  -bf 0 -g 60 -video_track_timescale 30000 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
  final/short.mp4
```

### Step 7 — Cover extract

```bash
ffmpeg -y -ss <mid-beat-seconds> -i final/short.mp4 -frames:v 1 -q:v 2 final/cover.png
```

Pick a timestamp where the Claude UI + prompt or AI response is most legible — usually mid-PromptReveal or start of ResponseReveal. **Not the Hook scene** (abstract text; cover should show the "money shot").

### Step 8 — Delivery checklist

Run all 12 spec checks. For this recipe:
- Resolution: 1080×1920
- FPS: 30 · time_base: 1/30000 · start_time: 0.000
- Audio: aac 48000 Hz stereo
- B-frames: {I, P} only (outro source has them; re-encode strips)
- PIP safe zone: n/a — document "no PIP by design"

### Step 9 — CMO handoff

Standard CMO template. **Flag duration drift** if final is over the 35-46s target ceiling (the +5s outro often pushes final to 47-51s). Note that it remains well within the 60s Shorts hard cap.

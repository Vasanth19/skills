---
name: c-avatar-screenshot-broll
description: Avatar-led longform video compositing pipeline for HeyGen/talking-head videos that need realistic website, product, docs, and GitHub screenshot b-roll. Use when creating or revising landscape educational videos with Remotion or HyperFrames, removing side bands from square avatar footage, adding hook text, using live screenshots with Ken Burns motion, keeping b-roll segments under 15 seconds, and verifying screenshot coverage and final MP4 quality.
kind: pipeline
visibility: internal
dependsOn: [c-ffmpeg, c-html-gfx, c-broll, c-heygen]
---

# Avatar Screenshot B-Roll Pipeline


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Create a landscape longform avatar video where the speaker stays on one side and the other side carries realistic b-roll: live website screenshots, GitHub, docs, product pages, browser-framed captures, and simple explainer graphics. This skill is for videos like "I tested X tools" or "Here are the best workflows" where abstract cards alone feel empty or repetitive.

## Inputs

Required:
- Source avatar video or HeyGen video ID.
- Brand voice and visual style.
- Topic/script/transcript, or source video to analyze.

Optional:
- URLs to show as realistic b-roll.
- Existing Remotion/HyperFrames project.
- Requested zoom, such as `1.1x`.
- Minimum real screenshot coverage, usually `20%+`.

## Output Contract

Deliver:
- Final MP4 in `{production}/final/{slug}-broll-vN.mp4`.
- Cropped/clean avatar source in `{production}/interim/video/base/`.
- Screenshot assets in the composition `public/` folder or `{production}/interim/broll/screenshots/`.
- Inspection stills/contact sheet in `{production}/interim/video/inspect/`.

Hard requirements:
- Landscape output: `1920x1080`, usually `25fps`.
- B-roll segment duration: under 15 seconds; target `10-13s`.
- Real screenshot coverage: at least user-requested threshold; default `20%`, preferred `40-60%`.
- No blank right pane at the start. Show hook text from frame 0.
- No repeated empty rail gaps between b-rolls. Use dense timing or small overlaps.
- If input is landscape with square avatar and white side bands, crop the bands before compositing.

## Workflow

### 1. Prepare The Avatar

If the HeyGen output is landscape with square avatar footage centered between white side bands, crop to the square content first:

```bash
ffmpeg -i heygen-raw-landscape.mp4 \
  -vf "crop=1080:1080:420:0" \
  -c:v libx264 -c:a aac -y heygen-avatar-square-cropped.mp4
```

Adjust crop values after probing dimensions. For a `1920x1080` source with centered `1080x1080` avatar, the left offset is usually `420`.

Verify:
- No white side bands remain.
- Audio is preserved.
- Avatar framing is not cut too tight.

### 2. Build The Beat Map

Use transcript timing to create 10-13 second b-roll beats. Prefer many short beats over a few long overlays.

Do not build the video by cycling a generic list of b-roll cards across the runtime. Every beat must be explicitly tied to the words being spoken in that exact time window. If the visible title, screenshot, or explainer would not make sense when compared against the local transcript chunk, replace it before rendering.

Beat map fields:
- `start`
- `duration`
- `kind`: `screenshot`, `cards`, `flow`, `terminal`, `chart`, `stack`
- `title`
- `accent`
- `asset` for screenshot beats
- `source` label for browser chrome

Timing rules:
- First right-pane visual starts at `0s` with a hook.
- Main b-roll can start around `3s`.
- Cadence should be close to duration: e.g. `duration=13`, `cadence=12.6` gives a small overlap and avoids gaps.
- Never exceed `15s` for a single b-roll segment.
- Keep each title/accent grounded in the transcript segment, not in the broader topic.

### 3. Capture Realistic Screenshots

Use real pages whenever possible:
- Product site: `claude.ai`, product pages, app pages.
- Company site: `anthropic.com` or brand official site.
- Docs: official documentation pages.
- GitHub: repo, issues, pull requests, actions, README, releases.

Capture with headless Chrome or Playwright at `1440x1000` or larger. Example:

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --no-first-run \
  --window-size=1440,1000 \
  --screenshot=github-repo.png \
  https://github.com/anthropics/claude-code
```

Reject captures with:
- bot/security verification pages unless the page itself is the point.
- blank hero panels or skeleton loaders.
- large cookie banners covering content.
- cropped text that cannot be understood.

### 4. Compose The Layout

Default landscape layout:
- Left: cropped avatar, around `680-720px` square, rounded rectangle.
- Right: b-roll rail with screenshots and graphics.
- Bottom-left: brand label and tagline.
- Right pane: browser-framed screenshot cards or explainer graphics.

If the user asks to "zoom/click the final product by 1.1x", apply a composition-level scale and re-check cropping:

```tsx
<AbsoluteFill style={{transform: 'scale(1.1)', transformOrigin: 'center center'}}>
  {/* avatar + b-roll layout */}
</AbsoluteFill>
```

After scaling, move/resize the avatar and rail inward if labels or rounded corners clip.

### 5. Add Hook Text At Frame 0

Never leave the right pane empty for the first few seconds. Add a short hook card from `0s` to `3s`.

Hook pattern:
- Eyebrow: `WATCH THIS FIRST`
- Big claim: `I tested 100+ Claude Code skills. These are the ones worth using.`
- Three payoff chips: `Build faster`, `Catch mistakes`, `Sell outcomes`

The hook should be visible immediately. Do not fade from zero opacity if the user complained about blank first frames.

### 6. Use Screenshot Motion

For still screenshots, add Ken Burns movement:
- Slow scale from `1.03 -> 1.14` or reverse.
- Small pan `20-40px` horizontal/vertical.
- Browser chrome wrapper to make the capture feel like real product footage.

Label screenshot cards subtly:
- URL/source bar: `GitHub repository`, `Claude Code docs`, etc.
- Optional badge: `Real screenshot b-roll`.

### 7. Render And Verify

Use Remotion or HyperFrames according to project context. For Remotion, use the local Chrome binary; do not let Remotion download a browser:

```bash
npx remotion render src/index.ts CompositionId final.mp4 \
  --browser-executable="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --concurrency=4 --crf=20 --audio-bitrate=192k --x264-preset=medium
```

Verification checklist:
- `ffprobe`: dimensions, fps, duration, audio stream.
- Frame 0: hook text visible on the right pane.
- Early b-roll frame: screenshot or graphic visible; no blank rail.
- Mid-video samples every 60-90 seconds: no repeated blank gaps.
- Transcript alignment: compare each sampled frame's visible headline and asset to the words spoken at that timestamp.
- Coverage calculation: screenshot segments / total segments >= requested threshold.
- Max b-roll segment duration < 15 seconds.

Sample coverage report:

```json
{
  "segments": 55,
  "maxSegmentSeconds": 13,
  "screenshotSegments": 28,
  "screenshotCoveragePercent": 51,
  "overlapSeconds": 0.4
}
```

## Coordination With Other Skills

Use these skills when available:
- `c-heygen`: poll/download HeyGen video and handle avatar footage.
- `c-broll`: capture website screenshots or scroll b-roll, and register reusable b-roll assets in the brand library when the output should become part of the library.
- `c-html-gfx`: create graphics, browser frames, and Remotion compositions.
- `c-ffmpeg`: crop, probe, sample frames, contact sheets, and final verification.

## Example Output

Open `assets/example-output.html` to see a ten-frame visual mockup of the expected layout: hook frame, Claude/Anthropic/GitHub screenshots, and supporting explainer graphics.

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.


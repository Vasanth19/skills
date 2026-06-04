---
name: p-reels-rmtn-fmt5
description: Make a vertical reel from an UPLOADED talking-head video as a small bottom PIP over an INTERACTIVE REMOTION background — the background is built beat-by-beat from the speaker's transcript as data-driven Remotion scenes (a typing UI/terminal card, hook title cards, etc. — the "day13" interactive look), with 1-2 uploaded b-roll moments where they fit. Opus plans the scenes + props (flat-cost Max OAuth), kimi just renders the shipped Remotion project from --props (no code authoring). The Remotion sibling of p-reels-hf-fmt5 (which uses HyperFrames text cards). Trigger on "interactive remotion reel with my talking head", "typing/terminal UI reel from my video", "day13-style reel with avatar PIP", "remotion scenes + talking head PIP", "screen-rec style reel with my face".
when-to-use: Use when the user wants the INTERACTIVE Remotion look (typing prompt reveals, terminal/UI mockups, animated React scenes — like the day13 cold-email reel) AND their own UPLOADED talking head as a small bottom PIP. Sibling of p-reels-hf-fmt5 (HyperFrames text cards, cheaper/simpler) and p-screen-rec-vo (Remotion, but VO-only no PIP) and p-bottom-avatar-pip (HeyGen avatar PIP over b-roll).
version: 1.0.0
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Interactive Remotion Reel (Uploaded PIP)
  format: 9:16 vertical video
  duration: 20-60s
inputs: [talking_head_video, broll_media]
dependsOn: [c-audio, c-broll, c-ffmpeg, f-remotion, c-cloud-media]
---

# p-reels-rmtn-fmt5 — Uploaded Talking-Head PIP over an INTERACTIVE Remotion background

The **Remotion sibling of `p-reels-hf-fmt5`**. Same plan-on-Opus / execute-on-kimi architecture and the
same uploaded-PIP composite — but the background beats are **data-driven Remotion scenes** (the
interactive "day13" look: a `claude.ai`/terminal card that TYPES a prompt out char-by-char, hook
title cards, etc.) instead of HyperFrames text cards. Read
`.claude/knowledge/decisions/plan-opus-execute-ollama-render-architecture.md` and `p-reels-hf-fmt5`
first — the structure is identical; only the GRAPHICS-beat renderer differs.

**The cheap executor never authors React.** The skill ships a parameterized, data-driven Remotion
project (`remotion/`) whose `ReelBg` composition renders any scene plan passed via `--props`. Opus
picks the scene `type` + fills its `props` per beat; kimi just runs `remotion render … --props=…`.

## Scene bank (data-driven — add a type by adding a component + 1 registry line)

| `type` | Props | Look |
|---|---|---|
| `hook` | `{eyebrow, title, accent}` | Big eyebrow + headline + glowing accent word |
| `typing` | `{label, text}` | A window card (`label`, e.g. `claude.ai`) that TYPES `text` char-by-char with a blinking caret — the interactive prompt-reveal |
| `text` | `{eyebrow, title, accent}` | Generic title beat (default/fallback) |

All scenes keep content in the **top ~55%** so the bottom-left PIP never covers it. Brand via
`props.theme` (defaults to MGG slate/orange). Extend the bank by adding `remotion/src/scenes/<X>.tsx`
+ one line in `remotion/src/ReelBg.tsx` REGISTRY — never by authoring code per render.

## Inputs / Params

Same as `p-reels-hf-fmt5`: `talking_head_video` (REQUIRED — the PIP + the only voice), `broll_media[]`
(supplement, up to `broll_coverage` of the reel, trimmed to cue; default 0.30; **0** when none or a
no-b-roll instruction), `brand`, optional `music_bed`. PIP = SMALL (400×540 box), **portrait →
bottom-LEFT, square/landscape → bottom-CENTER** (identical to fmt5 Step 5).

## Steps

`$TH` = talking-head upload, `$W` = scratch work dir, `$FF` = ffmpeg, `$OUT` = final.

### 1-2 — Localize + transcribe (identical to p-reels-hf-fmt5)
Download + ffprobe `$TH` and each clip; transcribe `$TH` → `$W/th_transcript.json` and each audio-
carrying clip → `$W/broll_cues.json`. (See fmt5 Steps 1-2.)

### 3 — PLAN with OPUS (curated scenes + props; kimi fallback)
Nested Opus `claude --print` (unset the Ollama routing, as in fmt5 Step 3). Opus outputs `plan.json` —
an array of beats covering the full VO. Each beat:
```json
{ "start": <s>, "end": <s>, "kind": "graphics" | "broll",
  "scene": { "type": "hook"|"typing"|"text", "props": { ... } },   // when kind=graphics
  "broll": { "clip": "<file>", "in": <s>, "out": <s> } }           // when kind=broll
```
Prompt rules: MOST beats are `graphics`; choose the scene `type` that fits the line (use `typing` when
the VO is about a prompt/command/UI — pass the literal text to type); b-roll total ≤
`broll_coverage × total_duration` (0 → all graphics), matched to the clip's own cue. Keep titles short.
Fallback to kimi planning if Opus is unavailable (log it — see the OAuth-fallback follow-up).

### 4 — EXECUTE every beat IN PARALLEL on kimi (render Remotion / cut clip — never author)
ONE-TIME setup, then bounded-parallel per-beat builds:
```bash
SKILL_DIR=$(find "$HOME/.claude/skills" -maxdepth 2 -type d -name p-reels-rmtn-fmt5 2>/dev/null | head -1)
RMTN="$W/remotion"; cp -r "$SKILL_DIR/remotion" "$RMTN"
( cd "$RMTN" && npm install --no-audit --no-fund --loglevel=error )   # ~20s, once

build_beat() {   # $1 = beat index
  python3 - "$1" "$W/plan.json" "$W" "$FF" "$RMTN" <<'PY'
import json,sys,os,subprocess
i=int(sys.argv[1]); beat=json.load(open(sys.argv[2]))[i]; W=sys.argv[3]; FF=sys.argv[4]; RMTN=sys.argv[5]
dur=float(beat["end"])-float(beat["start"]); out=f"{W}/bg_beat{i}.mp4"
if beat["kind"]=="broll" and beat.get("broll"):
    b=beat["broll"]
    subprocess.run([FF,"-ss",str(b["in"]),"-to",str(b["out"]),"-i",f'{W}/src/{b["clip"]}',
      "-vf","scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p",
      "-an","-c:v","libx264","-preset","medium","-crf","20","-y",out],check=True)
else:
    sc=beat["scene"]; sc["durationInFrames"]=max(1,round(dur*30))
    props=json.dumps({"scenes":[sc]})
    pf=f"{W}/props_beat{i}.json"; open(pf,"w").write(props)
    subprocess.run([f"{RMTN}/node_modules/.bin/remotion","render","ReelBg",out,
      "--props="+pf,"--concurrency=1","--log=error"],cwd=RMTN,check=True)
PY
}
NPROC=$(nproc 2>/dev/null || echo 4); MAXJOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))
N=$(python3 -c "import json;print(len(json.load(open('$W/plan.json'))))")
for i in $(seq 0 $((N-1))); do build_beat "$i" &
  while [ "$(jobs -r | wc -l)" -ge "$MAXJOBS" ]; do wait -n; done; done
wait
for i in $(seq 0 $((N-1))); do [ -s "$W/bg_beat$i.mp4" ] || { echo "beat $i did not render"; exit 1; }; done
```
> Each graphics beat renders the data-driven `ReelBg` with a single-scene `--props` — the model passes
> data, never writes React. Remotion is the heavy pole; cap at cores-1. (Per-beat render keeps the
> b-roll beats interleaved exactly like fmt5.)

### 5 — Build + VERIFY the background track (identical to fmt5 Step 4)
Concat the `bg_beat*.mp4` → `$W/bg-all.mp4`; brightness-verify it is not black.

### 6 — Composite the SMALL uploaded-PIP (identical to fmt5 Step 5)
ffprobe `$TH`; scale-to-FIT into a 400×540 card (whole face, no crop); **portrait → bottom-LEFT,
square/landscape → bottom-CENTER**, 80px margins; map the talking head's own audio.

### 7-9 — Audio mix (optional) → Visual QA Gate (MANDATORY, read 6 frames: scenes animate, typing is
legible, PIP shows the full face + margin, no black) → upload to R2 + print the URL on the LAST line.
(Identical to fmt5 Steps 6-9.)

## Output
One 9:16 H.264 MP4: an interactive Remotion background (typing UI cards + hook beats, Opus-planned) +
1-2 trimmed b-roll moments, the uploaded talking head as a small bottom-left PIP, owner's real voice.

## Notes
- **Never authors React** — the Remotion project is shipped + data-driven; kimi only passes `--props`.
- **Relationship:** `p-reels-hf-fmt5` = HyperFrames text cards (cheaper, simpler). This = interactive
  Remotion scenes (richer, the day13 look). `p-screen-rec-vo` = Remotion but VO-only (no PIP).
  `p-bottom-avatar-pip` = HeyGen avatar PIP over b-roll. This one = uploaded PIP + Remotion scenes.
- **npm install per render** (~20s) — the project ships without node_modules. Cached work dir reuse is
  a future optimization.

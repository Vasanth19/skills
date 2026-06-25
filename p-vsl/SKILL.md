---
name: p-vsl
description: Full VSL longform production pipeline. Produces one 16:9 (1920×1080) landscape sales video with a varied avatar grammar (avatar-front / b-roll-fullscreen / corner-PIP), transcript-synced b-roll + HyperFrames motion graphics, premium SFX + color grade, optional kinetic captions, and a vision-QA gate. Self-contained executable pipeline — runs headless. Source is either a HeyGen green-screen avatar render (default) or an uploaded talking-head clip.
when-to-use: Use to produce a longform 16:9 landscape VSL / sales video (5–20 min). The speaker is either a HeyGen avatar (default, rendered green-screen) or an uploaded real talking-head clip (`source=uploaded`). The pipeline alternates avatar-front, b-roll-fullscreen, and corner-PIP segments over a transcript-synced background. For 9:16 vertical reels use p-reels-pip / p-reels-spotlight / p-reels-faceless instead.
version: 1.0.0
disable-model-invocation: true
argument-hint: "[brand] [production-name] [script] [--source heygen|uploaded]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: deprecated
deprecated: true
supersededBy: p-longform
providers: heygen, elevenlabs
produces:
  dish: VSL
  format: 16:9 video
  duration: 5-20 min
inputs: [script, talking_head_video, broll, known_transcript, outro]
dependsOn: [c-script, c-heygen, c-broll-sync, c-reel-premium, c-typing-ui, c-ffmpeg, c-audio, c-broll, c-ai-media, wowx-focus, f-hyperframes, f-hyperframes-cli, f-gsap]
metadata:
  hermes:
    vendored:
      - { name: c-script, load: ".hub/c-script/SKILL.md" }
      - { name: c-heygen, load: ".hub/c-heygen/SKILL.md" }
      - { name: c-broll-sync, load: ".hub/c-broll-sync/SKILL.md" }
      - { name: c-reel-premium, load: ".hub/c-reel-premium/SKILL.md" }
      - { name: c-typing-ui, load: ".hub/c-typing-ui/SKILL.md" }
      - { name: c-ffmpeg, load: ".hub/c-ffmpeg/SKILL.md" }
      - { name: c-audio, load: ".hub/c-audio/SKILL.md" }
      - { name: c-broll, load: ".hub/c-broll/SKILL.md" }
      - { name: c-ai-media, load: ".hub/c-ai-media/SKILL.md" }
      - { name: wowx-focus, load: ".hub/wowx-focus/SKILL.md" }
      - { name: f-hyperframes, load: ".hub/f-hyperframes/SKILL.md" }
      - { name: f-hyperframes-cli, load: ".hub/f-hyperframes-cli/SKILL.md" }
      - { name: f-gsap, load: ".hub/f-gsap/SKILL.md" }
    progressive: true
---

> # ⛔ DEPRECATED (2026-06-17) — use **`p-longform format=vsl`**
> `p-longform` is the unified longform recipe (vsl / demo / tutorial). Its **`format=vsl` path**
> now carries the full p-vsl engine: varied per-beat avatar grammar (full / pip / hidden),
> transcript-synced b-roll + HyperFrames via `c-broll-sync`, the `c-reel-premium` grade+SFX pass,
> first-frame money-shot cover, vision-QA gate, and the `source=heygen|uploaded` branch. This
> standalone skill is superseded; kept for reference only. Do not use for new work — invoke
> `p-longform` with `format=vsl` instead. (Brand-level learnings previously filed under
> `projects/<brand>/productions/p-vsl` are still read by p-longform.)



> ## ⚡ Frame integrity + integrated CTA (MANDATORY — 2026-06-16)
> - **Frame 0 is NEVER black.** The first frame must be a bright money-shot — the cover-freeze of the strongest illustrative beat (Step 10 cover rule). Verify `ffmpeg ... signalstats` → `YAVG > 30`. No black / hook-blank / fade-in opener.
> - **The LAST frame is NEVER black.** The reel must end on content, not a fade-to-black or trailing blank. Verify the final frame `YAVG > 30`.
> - **CTA is integrated by DEFAULT, not optional.** Every reel/VSL ends on a branded **CTA beat baked into the timeline** (offer line + handle/URL), as the final illustrative HyperFrames card. Do not ship a reel whose last beat is filler or black. (In p-reels-split this is the Step 9 CTA takeover; other recipes must add an equivalent closing CTA card.)

> ## ⚡ HyperFrames = illustrative, NOT just titles (MANDATORY — 2026-06-16)
> Every HyperFrames graphics scene MUST pair its title with an **illustrative animation that depicts the point** — never a bare kinetic title card. Examples: a 45-post feed grid staggering in (`back.out`), a count-up stat with day-dots, an animated waveform for "voice", platform chips popping in. Match the premium reference in `cfw-marketing/creatives/productions/restaurants-vsl/hyperframes` (`DIAG-calendar` feed-grid, `HF-*` motion) **and** `cfw-marketing/creatives/productions/fnb-split-screen-short/gen-rich-cards.py`: grid + glow + vignette background, GSAP eased + staggered elements, brand palette, depth (shadows/shine). **Make it as rich and premium as possible — a title-only card is a defect.**

# p-vsl — VSL Longform Production (16:9, executable)

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step, read `LEARNINGS.md` in this same folder (GLOBAL — applies to every brand).
> 1b. **ALSO load the BRAND's production learnings from GBrain** — the brain's per-brand folder is the
>     discoverable home (agents recall it; a loose code-repo file is not auto-found). Fetch:
>     `mcp__brain-personal__get_page` slug **`projects/<brand>/productions/p-vsl`** (disk mirror:
>     `~/Code/Infra/brain-personal/projects/<brand>/productions/p-vsl.md`). It holds THIS brand's flavor of the
>     recipe + its hard-won fixes. Reading it is mandatory before producing.
> 2. Apply every item under **Active Feedback** (global) AND every brand learning as non-negotiable rules.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize feedback into 1–3 bullets and FILE IT BY SCOPE:
>    - **Brand-specific** (only this brand) → `put_page` to GBrain `projects/<brand>/productions/p-vsl` (append a dated entry; create the page if missing; dual-write the disk mirror).
>    - **Recipe-level** (every brand) → append to this folder's `LEARNINGS.md`.
> 6. If feedback is critical (affects correctness/quality), add it to the relevant **Active Feedback**/log so it applies on every future run.

Produces one **1920×1080** H.264 MP4 VSL: the speaker shown with a **varied avatar grammar** —
`avatar-front` (talking to camera on a branded background), `pip` (bottom-right corner over a
full-frame background), and `hidden` (b-roll/graphics fullscreen, voice continues). The background
is **transcript-synced**: uploaded b-roll where the words match, HyperFrames motion graphics
everywhere else (planned by `c-broll-sync`). Premium **SFX + color grade** always; kinetic
captions optional. The speaker's voice is the single continuous audio bed, loudnormed once.

**This is the merged best-of `p-reels-pip`, adapted to landscape longform:** the executable
pipeline shape, `c-broll-sync` beat planning, `c-reel-premium` polish pass, HyperFrames graphics
(no Remotion), FIT+blurred-fill backgrounds, face-safe PIP, brightness + vision-QA gates,
loudnorm-once discipline, parallel beat builds, and the R2-upload/URL-print contract — all kept.
The VSL identity (16:9, HeyGen avatar, varied grammar) is preserved.

## Layout — landscape, PIP bottom-right

```
┌────────────────────────────────────────────────┐ 1920×1080
│  full-frame background: b-roll (FIT+blurred-fill)│
│  or HyperFrames motion graphics. Content lives   │
│  in the upper/left band (above y≈680).           │
│                                                  │
│                          ┌───────────────┐       │  PIP zone (pip beats):
│                          │ TALKING-HEAD  │       │  384×330 @ x=1512, y=726
│                          │   PIP card    │       │  (bottom-right). Graphics +
│                          └───────────────┘       │  captions never enter here.
└────────────────────────────────────────────────┘
```

Per `c-ffmpeg/references/landscape-pip.md`. Graphics templates reserve the bottom band; captions
sit in the lower-left ~76% (caption-overlay-ls clears the PIP).

---

## Inputs

| Param | Required | Default | Notes |
|---|---|---|---|
| `brand` | YES | — | Brand slug (e.g. `mr-growth-guide`). Path from `~/.gsai/ecosystem.yaml`. |
| `production_name` | YES | — | Folder under `creatives/productions/`. |
| `script` | YES | — | Path to `.txt` TTS-clean script OR a draft `.md` (approved at Step 1). |
| `source` | No | `heygen` | `heygen` (render green-screen avatar) or `uploaded` (real talking-head clip). |
| `talking_head_video` | If `source=uploaded` | — | Uploaded clip (real face + real voice). PIP foreground + audio/duration master. |
| `source_video` | No | — | Existing green-screen render to reuse (HeyGen path; skips render+poll). |
| `known_transcript` | No | — | Pre-computed word-level transcript `[{text,start,end}]`. HeyGen passes the script → skips Whisper. |
| `broll[]` | No | `[]` | Uploaded b-roll clips. Placed by `c-broll-sync` where the transcript matches. Empty → 100% graphics background. |
| `captions` | No | `off` | `on` burns kinetic word-level captions (heavy for 20 min — default off for longform). |
| `sfx` | No | `on` | Premium SFX mix (always recommended). |
| `grade` | No | `on` | Color grade (`warm-amber`/`clean-bright`; planner picks). |
| `cover_frame` | No | `on` | Prepend a 0.4s money-shot freeze so frame 1 is not black. |
| `cta_text` / `cta_handle` | No | — | Tail CTA takeover card (does NOT extend the video). |
| `outro` | No | — | Optional outro mp4 appended via concat. |

### c-broll-sync coverage params (passthrough — longform defaults)

| Param | Default | Meaning |
|---|---|---|
| `broll_coverage_pct` | `35` | Target % of bed covered by b-roll (rest is graphics). `0` = 100% graphics. |
| `broll_clip_seconds` | `8` | Default on-screen seconds per b-roll window (longer than reels → fewer beats). |
| `broll_min_seconds` | `4` | Min window clamp. |
| `broll_max_seconds` | `12` | Max window clamp. |
| `broll_order` | `transcript-match` | `transcript-match` / `as-given` / `even`. |
| `broll_reuse` | `false` | Whether clips may be reused to hit the coverage target. |

---

## Setup

```bash
# Brand path from ecosystem registry (never `find`/`ls` to guess)
BRAND_PATH=$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$HOME/.gsai/ecosystem.yaml')); print(d['brands']['$brand']['path'])" 2>/dev/null)
[ -n "$BRAND_PATH" ] || { echo "[p-vsl] FATAL: brand '$brand' not in ~/.gsai/ecosystem.yaml"; exit 1; }

PROD="$BRAND_PATH/creatives/productions/$production_name"
W="$PROD/interim/vsl" ; mkdir -p "$W" "$W/src" "$W/bg_beats" "$W/seg" "$PROD/final"
OUT="$PROD/final/vsl.mp4"
FF="ffmpeg"

# Canvas — LANDSCAPE
CW=1920 ; CH=1080 ; FPS=30
# PIP card (bottom-right) per landscape-pip.md
PIP_W=384 ; PIP_H=330 ; PIP_X=1512 ; PIP_Y=726

# Locate this skill + component dirs (box deployments live under ~/.hermes/profiles/<slug>/skills/cfw/)
SEARCH=("$HOME/.claude/skills" "$HOME/.hermes/skills" "$HOME/.hermes/profiles" /Users/vasanth/Code/skills)
find_dir(){ find "${SEARCH[@]}" -maxdepth 5 -type d -name "$1" 2>/dev/null | head -1; }
SKILL_DIR=$(find_dir p-vsl)
BROLL_SYNC_DIR=$(find_dir c-broll-sync)
PREMIUM_DIR=$(find_dir c-reel-premium)
FFMPEG_DIR=$(find_dir c-ffmpeg)
# wowx-focus: prefer the vendored copy under this recipe's .hub, else discover
WOWX_DIR="$SKILL_DIR/.hub/wowx-focus"; [ -f "$WOWX_DIR/apply_focus.py" ] || WOWX_DIR=$(find_dir wowx-focus)

# Coverage / feature knobs
BROLL_COVERAGE_PCT="${broll_coverage_pct:-35}"
BROLL_CLIP_SECS="${broll_clip_seconds:-8}"
BROLL_MIN_SECS="${broll_min_seconds:-4}"
BROLL_MAX_SECS="${broll_max_seconds:-12}"
BROLL_ORDER="${broll_order:-transcript-match}"
BROLL_REUSE="${broll_reuse:-false}"
CAPTIONS="${captions:-off}"
SFX="${sfx:-on}"
GRADE="${grade:-on}"
COVER_FRAME="${cover_frame:-on}"
SOURCE="${source:-heygen}"

# Brand identity blob forwarded into graphics beats (accent/bg/fg). Override per brand DNA.
cat > "$W/brand.json" <<JSON
{ "accent": "${BRAND_ACCENT:-F97316}", "bg": "${BRAND_BG:-0F172A}", "fg": "${BRAND_FG:-F1F5F9}" }
JSON
```

---

## Step 1 — Resolve the avatar source ⛔ CHECKPOINT (heygen render)

Both branches converge to: **`AVATAR_SRC`** (full-length speaker clip, = audio/duration master)
and **`SOURCE_KIND`** (`heygen` = green-screen keyable, or `uploaded` = opaque).

**Script prep (both):** if `script` is a draft `.md`, present it for approval, then
→ Skill: `c-script` (duration calc, TTS preprocessing) → `$W/script-tts.txt`. A `.txt` already
TTS-clean skips approval (confirm word count + estimated duration).

**`--source heygen` (default):**
```bash
if [ -n "${source_video:-}" ]; then
  cp "$source_video" "$W/avatar-green.mp4"          # reuse a prior render
else
  # → Skill: c-heygen → browser render, background #00FF00 solid, full TTS-clean script.
  # Gate: user/operator triggers the HeyGen render and confirms the job ID.
  # → Skill: c-heygen → poll via Floe API (60s) → download green-screen render
  echo "[p-vsl] HeyGen render must be downloaded to $W/avatar-green.mp4 before continuing"
fi
AVATAR_SRC="$W/avatar-green.mp4" ; SOURCE_KIND="heygen"
# HeyGen path: the VSL script IS the transcript → pass as known_transcript when timings are known.
```

**`--source uploaded`:** run pip's localize + probe + silence + white-band crop on `talking_head_video`:
```bash
TH="$talking_head_video"   # download remote URLs to $W/src/th.mp4 first (cfw-download/curl)
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,codec_name \
  -of default=noprint_wrappers=1 "$TH"
$FF -hide_banner -i "$TH" -t 60 -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume"
# mean ~-20 dB = real speech; ~-90 dB = STOP (no narration) — ask for a different source.

# Crop flat-white side-bands (left/right only — NEVER the top; the head must not be clipped)
TH_W=$(ffprobe -v error -select_streams v -show_entries stream=width  -of csv=p=0 "$TH")
TH_H=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$TH")
BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TH")
col_luma(){ v=$($FF -hide_banner -loglevel error -ss $(echo "$BED_DUR/2"|bc) -i "$TH" -vframes 1 \
  -vf "crop=2:$TH_H:$1:0,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | xxd -p); echo $((16#$v)); }
BAND_LEFT=0;  for x in $(seq 0 5 $((TH_W/2))); do [ "$(col_luma $x)" -lt 245 ] && { BAND_LEFT=$x; break; }; done
BAND_RIGHT=$TH_W; for x in $(seq $((TH_W-2)) -5 $((TH_W/2))); do [ "$(col_luma $x)" -lt 245 ] && { BAND_RIGHT=$((x+2)); break; }; done
CLEAN_W=$(( (BAND_RIGHT-BAND_LEFT) - (BAND_RIGHT-BAND_LEFT)%2 ))
if [ "$BAND_LEFT" -gt 4 ] || [ "$BAND_RIGHT" -lt $((TH_W-4)) ]; then
  $FF -y -i "$TH" -vf "crop=$CLEAN_W:$TH_H:$BAND_LEFT:0,setsar=1" -c:v libx264 -pix_fmt yuv420p -c:a copy "$W/th-clean.mp4"
  AVATAR_SRC="$W/th-clean.mp4"
else AVATAR_SRC="$TH"; fi
SOURCE_KIND="uploaded"
```

---

## Step 2 — Loudnorm the audio master ONCE (never again downstream)

```bash
# Extract + loudnorm the speaker's voice to the single master track. This is the ONLY loudnorm.
$FF -y -i "$AVATAR_SRC" -vn \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000" \
  -c:a aac -ar 48000 -ac 2 -b:a 192k "$W/master.m4a"
BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AVATAR_SRC")
echo "[p-vsl] master audio set; BED_DUR=${BED_DUR}s"
```

---

## Step 3 — Transcribe with word timestamps (skip when known_transcript provided)

Mirror `p-reels-pip` Step 3 verbatim (cfw-transcribe → mlx_whisper → whisper fallback chain,
SRT→words JSON, ≥20%-garbage quality gate). HeyGen path: write `$W/transcript.json` from the
script `known_transcript` and skip Whisper. Output: `$W/transcript.json` (`[{text,start,end}]`).

**SRT/words JSON is ground truth for all b-roll + beat timecodes.**

---

## Step 4 — Build the b-roll cue index (for c-broll-sync)

Mirror `p-reels-pip` Step 4 verbatim: transcribe each `broll[]` clip's audio in parallel
(cores−1), silent clips get `cues: []`, no b-roll → `[]`. Output: `$W/broll_cues.json`
(`[{clip,duration,cues:[{start,end,text}]}]`).

---

## Step 5 — Plan the background beat list with c-broll-sync (OPUS brain)

```bash
node "$BROLL_SYNC_DIR/scripts/plan.js" \
  --transcript "$W/transcript.json" --broll "$W/broll_cues.json" \
  --coverage "$BROLL_COVERAGE_PCT" --clip-secs "$BROLL_CLIP_SECS" \
  --min-secs "$BROLL_MIN_SECS" --max-secs "$BROLL_MAX_SECS" \
  --order "$BROLL_ORDER" --reuse "$BROLL_REUSE" \
  --bed-dur "$BED_DUR" --brand "$W/brand.json" --out "$W/beat_list.json"

# Validate gapless coverage (same assert as pip) + extract cover_at (content beat past the hook)
python3 - "$W/beat_list.json" "$BED_DUR" <<'PY'
import json, sys
bl = json.load(open(sys.argv[1])); assert bl["beats"], "no beats"
prev = 0.0
for b in bl["beats"]:
    assert abs(b["start"] - prev) < 0.15, f"gap at beat {b.get('index')}: {prev} -> {b['start']}"
    prev = b["end"]
print(f"beat_list OK: {len(bl['beats'])} beats, broll {bl.get('achieved_broll_pct',0):.1f}%")
PY
COVER_AT=$(python3 -c "
import json; bl=json.load(open('$W/beat_list.json')); mid=float('$BED_DUR')*0.30
print(next((round(b['start']+(b['end']-b['start'])*0.5,2) for b in bl['beats'] if b['start']>=mid), round(float('$BED_DUR')*0.35,2)))")
echo "[p-vsl] cover_at: ${COVER_AT}s"
```

---

## Step 6 — Avatar-grammar pass (NEW — assign presence per beat)

Tag each beat `full` (avatar-front to camera), `pip` (bottom-right corner over the background),
or `hidden` (background fullscreen, voice continues). OPUS picks the VSL rhythm; deterministic
fallback guarantees a valid plan. **Reserve `full` for sales moments** (hook, key claims, CTA);
prefer `pip`/`hidden` on `broll`/`graphics` beats so planned content is actually shown.

```bash
GRAMMAR_PROMPT="You are directing a 16:9 VSL (sales video). Assign each beat an avatar presence.
Output STRICT JSON ONLY: {\"avatar\":[\"full|pip|hidden\", ...]} with one entry per beat, in order.
Beats (kind + window): $(python3 -c "import json;bl=json.load(open('$W/beat_list.json'));print(json.dumps([{'i':i,'kind':b['kind'],'start':b['start'],'end':b['end']} for i,b in enumerate(bl['beats'])]))")
Transcript: $(cat "$W/transcript.json")
RULES:
1. The FIRST beat and the LAST ~12% of beats = \"full\" (hook to camera + CTA to camera).
2. Beats stating a key claim/offer/proof = \"full\".
3. \"broll\" beats default \"hidden\" (let the footage breathe) or \"pip\" if the speaker is making a point over it.
4. \"graphics\" beats default \"pip\" (speaker present beside the card).
5. Keep it varied — avoid 4+ identical tags in a row."

AVATAR_PLAN=$(env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  timeout 180 claude --print "$GRAMMAR_PROMPT" --dangerously-skip-permissions 2>/dev/null \
  | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), re.S); print(m.group(0) if m else '')")

python3 - "$W/beat_list.json" "$W/avatar_plan.json" <<PY
import json
bl = json.load(open("$W/beat_list.json")); n = len(bl["beats"])
raw = '''$AVATAR_PLAN'''.strip()
plan = []
try:
    plan = json.loads(raw).get("avatar", [])
except Exception:
    plan = []
if len(plan) != n:                      # deterministic fallback
    plan = []
    for i, b in enumerate(bl["beats"]):
        if i == 0 or i >= n*0.88:        plan.append("full")
        elif b["kind"] == "broll":       plan.append("hidden")
        else:                            plan.append("pip")
json.dump({"avatar": plan}, open("$W/avatar_plan.json","w"))
print("avatar grammar:", plan)
PY
```

---

## Step 7 — Asset generation + build the background track (parallel) ⛔ CHECKPOINT (plan review)

Generate AI images / contextual background (`c-ai-media`, read `brand-ref.md` first), then build
every beat's background concurrently (cores−1). **graphics** beats render via the LOCAL landscape
HyperFrames templates (`templates/motion-card-ls.html`, `typing-scene-ls.html`, `hook-scene-ls.html`);
**broll** beats use FIT+blurred-fill at 1920×1080. Each → `$W/bg_beats/bg_beat<N>.mp4`
(1920×1080, 30fps, no audio).

**App / screen-recording b-roll → ALWAYS apply `wowx-focus` first (MANDATORY).** Screen captures,
app demos, dashboard walkthroughs and other flat/near-static screen footage look lifeless held
still — push them in with `wowx-focus` (cinematic Ken Burns) BEFORE the FIT+blurred-fill scale.
Detect a screen recording by metadata flag or filename (`*screen*`/`*recording*`/`*demo*`/`*app*`/
`*walkthrough*`), or when the clip has near-zero motion. Apply per trimmed b-roll window:

```bash
# $clip_in = trimmed b-roll window for this beat; produces a pushed-in clip, then FIT+blurred-fill it
python3 "$WOWX_DIR/apply_focus.py" "$clip_in" "$clip_focus" --amount 0.16 --drift-x 0.04
# short windows (<3s): --amount 0.12 ; opener/establishing screens: --direction out --amount 0.18
# then feed $clip_focus through the FIT+blurred-fill filter below.
```

Non-screen b-roll (real-world footage) may also use `wowx-focus` if static, but skip it for clips
that already carry strong camera motion (avoids motion-on-motion).

The build_beat python mirrors `p-reels-pip` Step 6 with two changes: (1) canvas 1920×1080;
(2) graphics templates are the p-vsl `*-ls.html` (which already bake `data-composition-id="root"`
and register `window.__timelines["root"]` — so only strip `<template>` + HTML comments, fill
placeholders, wrap in a full HTML doc, then `npx hyperframes@0.7.5 lint && render`).

> **⚠️ Vendor GSAP into EVERY graphics comp dir before rendering (MANDATORY).** The `-ls.html`
> templates load GSAP via `<script src="gsap.min.js"></script>` (vendored locally — NEVER a CDN).
> The HyperFrames file server serves only the comp dir, so that tag resolves ONLY if `gsap.min.js`
> exists in the comp dir. For each graphics beat, after writing `index.html` and BEFORE
> `npx hyperframes@0.7.5 lint && render`, copy the vendored file in:
> ```bash
> # GDIR = this graphics beat's comp dir (the one holding index.html, cwd of the render).
> # SKILL_DIR is set in Setup (find_dir p-vsl). f-gsap is vendored under .hub/ in the pack,
> # and a sibling dir in the source repo.
> GSAP=$(for p in "$SKILL_DIR/.hub/f-gsap/vendor" "$SKILL_DIR/../f-gsap/vendor"; do [ -f "$p/gsap.min.js" ] && echo "$p/gsap.min.js" && break; done)
> [ -n "$GSAP" ] || { echo "[p-vsl] FATAL: vendored gsap.min.js not found (expected under .hub/f-gsap/vendor/ or ../f-gsap/vendor/) — NEVER fall back to a CDN"; exit 1; }
> cp "$GSAP" "$GDIR/gsap.min.js"
> ```
> (Equivalent Python inside a `<<'PY'` heredoc — pass `SKILL_DIR` via `sys.argv`:
> ```python
> import shutil, os, sys
> def find_gsap(skill_dir):
>     for c in (f"{skill_dir}/.hub/f-gsap/vendor/gsap.min.js",
>               f"{skill_dir}/../f-gsap/vendor/gsap.min.js"):
>         if os.path.exists(c):
>             return c
>     raise SystemExit("[p-vsl] FATAL: vendored gsap.min.js not found "
>                      "(expected under .hub/f-gsap/vendor/ or ../f-gsap/vendor/) — NEVER fall back to a CDN")
> shutil.copy(find_gsap(SKILL_DIR), f"{GDIR}/gsap.min.js")  # before hyperframes render
> ```)

FIT+blurred-fill filter for broll beats:

```
[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=40:2,setsar=1[bg];
[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,setsar=1[fg];
[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p,fps=30[bv]
```

Also generate the **contextual background** for `full` beats once (HeyGen path only):
```bash
# → Skill: c-ai-media → contextual background matching brand/topic → $W/context-bg.png
```

After building, concat → `$W/bg-all.mp4`, then **brightness YAVG gate** (sample t=1, mid, end;
YAVG≈0 everywhere → background is black → FIX before compositing). Same as pip Step 6.

**Gate: operator reviews the beat plan + a background preview before the expensive composite.**

---

## Step 8 — Composite per avatar grammar (landscape)

Per beat, build a silent segment video, then concat and mux the single master audio once
(the speaker's voice is one continuous track — no per-segment audio juggling). Use **output-level
seeking** (`-i file -ss`) for accurate trims on 5+ min sources.

```bash
N_BEATS=$(python3 -c "import json;print(len(json.load(open('$W/beat_list.json'))['beats']))")
mapfile -t AV < <(python3 -c "import json;print('\n'.join(json.load(open('$W/avatar_plan.json'))['avatar']))")

# Rounded PIP mask at PIP_W×PIP_H (uploaded path; sharp corners acceptable if PIL missing)
python3 -c "
from PIL import Image, ImageDraw
img=Image.new('RGBA',($PIP_W,$PIP_H),(0,0,0,0)); d=ImageDraw.Draw(img)
d.rounded_rectangle([0,0,$PIP_W-1,$PIP_H-1],radius=32,fill=(255,255,255,255)); img.save('$W/pip-mask.png')" 2>/dev/null && MASK="$W/pip-mask.png" || MASK=""

KEY="colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01"

build_seg(){
  local i=$1; local kind avstart avend dur grammar bg seg
  read avstart avend <<<"$(python3 -c "import json;b=json.load(open('$W/beat_list.json'))['beats'][$i];print(b['start'],b['end'])")"
  dur=$(python3 -c "print(round($avend-$avstart,3))")
  grammar="${AV[$i]}"
  bg="$W/bg_beats/bg_beat$i.mp4"
  seg="$W/seg/seg$i.mp4"

  if [ "$grammar" = "hidden" ]; then
    cp "$bg" "$seg"; return
  fi

  if [ "$grammar" = "full" ]; then
    if [ "$SOURCE_KIND" = "heygen" ]; then
      # avatar keyed over contextual bg, full frame (zoom-then-crop avoids distortion)
      $FF -y -loop 1 -t "$dur" -i "$W/context-bg.png" -i "$AVATAR_SRC" -ss "$avstart" \
        -filter_complex "[0:v]scale=1920:1080,setsar=1[bg];[1:v]$KEY,scale=2208:1242,crop=1920:1080:144:0,setsar=1[av];[bg][av]overlay=0:0,format=yuv420p,fps=30[v]" \
        -map "[v]" -an -t "$dur" -c:v libx264 -preset medium -crf 19 "$seg"
    else
      # uploaded opaque clip shown FIT+blurred-fill full frame
      $FF -y -i "$AVATAR_SRC" -ss "$avstart" -t "$dur" \
        -filter_complex "[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=40:2,setsar=1[bg];[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,setsar=1[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p,fps=30[v]" \
        -map "[v]" -an -t "$dur" -c:v libx264 -preset medium -crf 19 "$seg"
    fi
    return
  fi

  # grammar = pip : background fullscreen + avatar bottom-right PIP
  if [ "$SOURCE_KIND" = "heygen" ]; then
    $FF -y -i "$bg" -i "$AVATAR_SRC" -ss "$avstart" \
      -filter_complex "[0:v]format=yuv420p[bg];[1:v]$KEY,crop=1258:1080:314:0,scale=$PIP_W:$PIP_H,setsar=1[pip];[bg][pip]overlay=$PIP_X:$PIP_Y:format=auto:shortest=1[v]" \
      -map "[v]" -an -t "$dur" -c:v libx264 -preset medium -crf 19 "$seg"
  elif [ -n "$MASK" ]; then
    $FF -y -i "$bg" -i "$AVATAR_SRC" -ss "$avstart" -i "$MASK" \
      -filter_complex "[1:v]scale=$PIP_W:$PIP_H:force_original_aspect_ratio=decrease,pad=$PIP_W:$PIP_H:(ow-iw)/2:0,setsar=1,format=yuva444p[thfit];[thfit][2:v]alphamerge[pip];[0:v]format=yuv420p[bg];[bg][pip]overlay=$PIP_X:$PIP_Y:format=auto:shortest=1[v]" \
      -map "[v]" -an -t "$dur" -c:v libx264 -preset medium -crf 19 "$seg"
  else
    $FF -y -i "$bg" -i "$AVATAR_SRC" -ss "$avstart" \
      -filter_complex "[1:v]scale=$PIP_W:$PIP_H:force_original_aspect_ratio=decrease,setsar=1[pip];[0:v]format=yuv420p[bg];[bg][pip]overlay=$PIP_X:$PIP_Y:format=auto:shortest=1[v]" \
      -map "[v]" -an -t "$dur" -c:v libx264 -preset medium -crf 19 "$seg"
  fi
}

NPROC=$(nproc 2>/dev/null || echo 4); MAXJOBS=$(( NPROC>1 ? NPROC-1 : 1 ))
for i in $(seq 0 $((N_BEATS-1))); do build_seg "$i" & while [ "$(jobs -r|wc -l)" -ge "$MAXJOBS" ]; do wait -n; done; done
wait
for i in $(seq 0 $((N_BEATS-1))); do [ -s "$W/seg/seg$i.mp4" ] || { echo "[p-vsl] FATAL: seg $i missing"; exit 1; }; done

# Concat segments (normalize) → silent composite video, then mux the master audio ONCE
for i in $(seq 0 $((N_BEATS-1))); do echo "file '$W/seg/seg$i.mp4'"; done > "$W/seg_concat.txt"
$FF -y -f concat -safe 0 -i "$W/seg_concat.txt" \
  -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,fps=30,format=yuv420p" \
  -c:v libx264 -preset medium -crf 19 -an "$W/composite-video.mp4"
$FF -y -i "$W/composite-video.mp4" -i "$W/master.m4a" -map 0:v -map 1:a -shortest \
  -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "$W/composed.mp4"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/composed.mp4"
```

---

## Step 9 — CTA end-card / outro (tail TAKEOVER — does NOT extend the video)

Mirror `p-reels-pip` Step 8: render a 2.5–3s landscape CTA card (HyperFrames, silent), overlay on
the FINAL seconds via a time-gated `enable=` window (the video ENDS when the speaker ends).
Optional `outro` appended via normalized concat. Output: `$W/pre-premium.mp4`. Verify the CTA did
NOT extend duration (±0.1s).

> **⚠️ Vendor GSAP into the CTA comp dir before rendering (MANDATORY).** The CTA card loads GSAP via
> `<script src="gsap.min.js"></script>` (vendored locally — NEVER a CDN). After writing the CTA
> `index.html` and BEFORE `npx hyperframes@0.7.5 lint && render`, copy the vendored file into the CTA comp
> dir (the render cwd):
> ```bash
> # $W/cta = the CTA comp dir holding index.html (cwd of the render). SKILL_DIR is set in Setup.
> GSAP=$(for p in "$SKILL_DIR/.hub/f-gsap/vendor" "$SKILL_DIR/../f-gsap/vendor"; do [ -f "$p/gsap.min.js" ] && echo "$p/gsap.min.js" && break; done)
> [ -n "$GSAP" ] || { echo "[p-vsl] FATAL: vendored gsap.min.js not found (expected under .hub/f-gsap/vendor/ or ../f-gsap/vendor/) — NEVER fall back to a CDN"; exit 1; }
> cp "$GSAP" "$W/cta/gsap.min.js"
> ```

---

## Step 10 — c-reel-premium pass (SFX + grade always; captions optional)

Follow `c-reel-premium` Steps P1–P4 (see `p-reels-pip` Step 8.5 for the exact bash), with these
landscape adaptations:
- **P1 (OPUS plan):** same prompt/schema; set `CAP_TOP=820` (landscape lower band) and tell the
  planner captions must stay left of x=1480 (the PIP zone is bottom-right).
- **P2 (caption render):** ONLY when `CAPTIONS=on`. Use the LOCAL landscape templates
  `templates/caption-overlay-ls.html` + `templates/root-shell-polish-ls.html` (1920×1080) instead
  of the portrait ones in `$PREMIUM_DIR/templates`. When `CAPTIONS=off`, `visuals.mp4 = pre-premium.mp4`.
  Both `-ls` caption templates load GSAP via `<script src="gsap.min.js"></script>` (vendored
  locally — NEVER a CDN). **Before `npx hyperframes@0.7.5 lint && render`, copy the vendored gsap into the
  caption comp dir** (the render cwd) so the local tag resolves:
  ```bash
  # $CAPDIR = the caption comp dir holding index.html (cwd of the render). SKILL_DIR is set in Setup.
  GSAP=$(for p in "$SKILL_DIR/.hub/f-gsap/vendor" "$SKILL_DIR/../f-gsap/vendor"; do [ -f "$p/gsap.min.js" ] && echo "$p/gsap.min.js" && break; done)
  [ -n "$GSAP" ] || { echo "[p-vsl] FATAL: vendored gsap.min.js not found (expected under .hub/f-gsap/vendor/ or ../f-gsap/vendor/) — NEVER fall back to a CDN"; exit 1; }
  cp "$GSAP" "$CAPDIR/gsap.min.js"
  ```
- **P3 (grade + SFX):** reuse `$PREMIUM_DIR` grade map + `$PREMIUM_DIR/assets/sfx/*.wav`, one pass,
  `amix=normalize=0` (NEVER re-loudnorm — the master was normed once in Step 2). SFX always on by default.
- **P4:** QA gate (frame spot-checks + clean decode).

Output: `$W/polished.mp4`.

---

## Step 11 — First-frame cover (optional, default on)

When `COVER_FRAME=on`, mirror `p-reels-pip` Step 9 at 1920×1080: extract the money-shot frame at
`$COVER_AT`, build a 0.4s silent freeze (anullsrc via `-f lavfi -i`, NEVER `-af`), prepend via
re-encoded concat. Keep `$W/cover.png` as the thumbnail Output. Result → `$OUT`.
When off, `cp "$W/polished.mp4" "$OUT"`.

---

## Step 12 — Verify (mandatory)

```bash
$FF -v error -i "$OUT" -f null -                 # clean decode = no output
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$OUT"          # confirm 1920×1080, v+a, ~30fps
# VO continuity (not silenced)
$FF -hide_banner -ss 2 -t 30 -i "$OUT" -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume"
# Vision QA — extract frames and READ each (non-negotiable)
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
for pct in 03 15 30 45 60 75 90; do t=$(python3 -c "print(round(float('$DUR')*0.$pct,1))"); $FF -y -ss "$t" -i "$OUT" -frames:v 1 "$W/qa_$pct.png"; done
```

**For each frame check:** (a) background not black; (b) on `full` beats the whole face shows
(not cropped/stretched); (c) on `pip` beats the PIP card is fully on-screen bottom-right with a
margin; (d) graphics/captions never cover the bottom-right PIP; (e) background fills full frame
(no pillarbox/letterbox/distortion); (f) captions legible with brand accent on emphasis (if on);
(g) frame 0 is the money-shot (if `cover_frame=on`), not black/hook. **Any fail → fix, re-render,
look again. Never ship a failing VSL.**

---

## Step 13 — Upload to R2 + print the URL (LAST LINE)

```bash
cfw-upload "$OUT" 2>/dev/null || bash _scripts/upload-to-recordings.sh "$OUT"
cfw-upload "$W/cover.png" 2>/dev/null || true     # thumbnail Output
# Print the R2 public URL as the FINAL line of output — the worker scrapes this.
# NEVER print an input URL (the upload, a b-roll source) as the result.
```

Optionally archive reusable b-roll: → Skill: `c-broll` → move clips from `$W` to
`$BRAND_PATH/creatives/brolls/` and update the library `.md` files. Clean up `$W` after the URL
is confirmed.

---

## Notes & gotchas (carried from p-reels-pip)

- **Audio mastered ONCE** (Step 2). Never re-normalize; the premium pass uses `amix=normalize=0`.
- **Output-level seeking** (`-i file -ss`) + the avatar source is the duration master — required
  for accurate trims on 5+ min VSLs.
- **FIT + blurred-fill** for backgrounds + uploaded `full` beats; never bare letterbox.
- **Zoom-then-crop** keyed avatar (`scale=2208:1242,crop=1920:1080:144:0`) — never crop+stretch.
- **PIP bottom-right, never covered** — graphics use the `-ls` templates (content above y≈680);
  captions use `caption-overlay-ls` (left ~76%, right:440px).
- **Black background = build failed — never ship it.** YAVG gate (Step 7) + vision QA (Step 12).
- **HyperFrames authoring:** root = FULL HTML doc; strip `<template>` + HTML comments before render;
  `data-composition-id="root"`; mapped font names (`'Oswald'`/`'JetBrains Mono'`/`'Inter'`, never
  `var(--font-*)`); bare `getComputedStyle`; no `Math.random`; run `lint` AND `validate` before `render`.
- **GSAP is vendored, never a CDN.** Every `-ls.html` template loads `<script src="gsap.min.js">`
  (relative). The HyperFrames file server serves only the comp dir, so before EVERY
  `hyperframes render` you MUST copy `f-gsap/vendor/gsap.min.js` into that comp dir (Steps 7, 9, 10·P2).
  Locate it under `$SKILL_DIR/.hub/f-gsap/vendor/` (pack) or `$SKILL_DIR/../f-gsap/vendor/` (source repo).
  A missing copy → 404 on gsap → blank/black graphics. The p-vsl templates need only `gsap.min.js`
  (no TextPlugin / MotionPathPlugin).
- **No `#` comments inside `filter_complex`** — keep long graphs in `.sh`.
- **Chroma-key only on the HeyGen path.** Uploaded opaque clips never go through `colorkey`.
- **Longform cost:** most beats are `full`/`hidden` (cheap); HyperFrames renders only on `graphics`
  beats. Longer `broll_clip_seconds` (default 8) caps beat count. Captions default off.

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

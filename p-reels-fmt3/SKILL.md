---
name: p-reels-fmt3
description: Turn an uploaded talking-head video (or a HeyGen avatar) into a PREMIUM full-frame reel — the speaker plays full-frame on one continuous never-cut voice bed, kinetic word-synced captions with accent-keyword pops ride over the whole reel, full-frame motion-graphics takeovers cover the picture at planned beats, sound design (whooshes/impacts/risers) hits the cuts, and a cinematic grade finishes it. Trigger on "premium talking-head edit", "viral caption edit of my video", "kinetic captions over my talking head", "make a full reel from this topic", "avatar + animation reel", "agency-style edit of my video", "talking head with animated captions and graphics".
when-to-use: Use when the user uploads a talking-head clip (or wants a HeyGen avatar from a script) and wants a complete agency-style reel - speaker full-frame the whole time, voice never interrupted, bold word-synced captions as the main visual device, graphics takeovers and SFX at key beats. NOT for PIP layouts (p-reels-fmt5 siblings) and NOT faceless (p-hf-reel, p-reels-fmt4).
version: 0.5.0
kind: pipeline
visibility: catalog
providers: heygen
produces:
  dish: Premium Talking-Head Reel
  format: 9:16 vertical video
  duration: 20-60s
inputs: [talking_head_video, script]
dependsOn: [c-script, c-heygen, f-hyperframes, f-hyperframes-cli, c-ffmpeg, c-broll, c-cloud-media]
---

# p-reels-fmt3 — Premium Talking-Head Reel (continuous-audio bed + kinetic captions)

A vertical 9:16 reel built on **one continuous voice bed**: the speaker's narration audio plays
unbroken for the entire reel and is **never cut or silenced**. Visually it is a premium edit —
the speaker plays full-frame, **word-synced kinetic captions** ride over the whole reel with the
key word of each line popping in the brand accent, full-frame **motion-graphics takeovers** cover
the picture at planned beats, **SFX** (whoosh/impact/riser) land on the cuts, and a **cinematic
grade** finishes the image.

```
audio:   ████████████████████████████████████████████████  ← speaker VO, ONE unbroken bed (+SFX under)
video:   [speaker][== GFX ==][speaker][== GFX ==][speaker]  +  [outro]
captions: ▁▂▃ kinetic word-synced captions over EVERYTHING ▃▂▁
```

**v0.5 (premium edit):** the picture is now assembled as **one HyperFrames composition** — the
speaker bed full-frame on track 0, opaque takeover sub-compositions on track 1, and a kinetic
caption overlay on track 2 — rendered silent, then the loudnormed bed audio + SFX are muxed in
ffmpeg. This is what lets typography sit ON TOP of the speaker (the old ffmpeg-overlay assembly
could only show opaque cards). An **Opus planner** writes the whole edit (takeover windows,
caption groups, emphasis words, SFX cues) from the transcript; the executor only fills templates.

## ⚠️ The one rule that defines fmt3

**The speaker's narration audio is the single, never-interrupted voice bed.** Graphics take over
the *picture*, never the *sound*. The bed audio is loudnormed ONCE (Step 2) and reaches the final
mux untouched — SFX are mixed UNDER it with `amix=normalize=0` so the VO level never moves. If at
any timestamp the VO is silent during a takeover, the reel is broken (continuity proof in Step 8).

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `talking_head_video` | Yes* | — | The user's uploaded talking-head MP4 (real face + real voice) OR a reused HeyGen render. **Its audio is the continuous voice bed for the whole reel.** Reused 16:9 studio renders often carry baked-in white side bands — Step 1.5 crops them (left/right only, never the top). *If absent, produce a fresh avatar via `c-script` → `c-heygen`. |
| `brand` | Yes | — | Palette + typography via the **Visual Identity Gate** (Brand Brief → DESIGN.md → named style → dark-premium default). The planner emits `{bg, accent, fg}` 6-digit hexes. Never hard-code. |
| `captions` | No | **on** | Kinetic word-synced caption overlay (the premium look). `off` only if the brief says no captions. |
| `sfx` | No | **on** | Sound design from the shipped pack (`assets/sfx/` — authored in-house, CC0). `off` to skip. |
| `grade` | No | planner picks | `warm-amber` or `clean-bright` final grade preset. |
| `takeover_windows[]` | No | planner picks | Manual override for takeover timing — normally Opus plans them. |
| `outro` | No | — | Brand outro MP4, appended after the bed ends (the only place different audio is allowed). |
| `avatar_layout` | No | `fill` | `fill` (band-clean → scale-to-cover) or `letterbox`. |
| `target_duration` | No | = bed length | The VO is the master; the edit covers exactly it. |
| `topic` / `script` | Conditional | — | Only when producing a fresh avatar via `c-heygen`. |

## Output

One 9:16 (1080×1920) H.264 + AAC MP4: speaker full-frame on a continuous voice bed, kinetic
captions over the whole reel, graphics takeovers at planned beats, SFX, cinematic grade, optional
outro. Uploaded to R2 — **the R2 public URL is the deliverable** (Step 9).

## Steps

Set up variables:

```bash
AVATAR="<path to talking-head mp4>"
OUTRO="<path to outro mp4 or empty>"
W="{production}/interim/fmt3" ; mkdir -p "$W"
OUT="{production}/final/premium-reel.mp4" ; mkdir -p "$(dirname "$OUT")"
SKILL_DIR=$(find "$HOME/.claude/skills" -maxdepth 3 -type d -name p-reels-fmt3 2>/dev/null | head -1)
```

### Step 1 — Source the speaker video (the voice bed)

Use the uploaded talking head (download to local disk first — never composite from remote URLs),
or reuse an existing avatar render, or produce one via `c-script` → `c-heygen` (9:16, one pass so
the narration is unbroken). Probe it — the duration is the master reel length:

```bash
ffprobe -v error -show_entries format=duration -of csv=p=0 "$AVATAR"
ffmpeg -hide_banner -i "$AVATAR" -af "silencedetect=noise=-35dB:d=0.5" -f null - 2>&1 \
  | grep -E "silence_(start|end)" || echo "narration continuous"
```

### Step 1.5 — Detect & crop white side bands (BEFORE anything else)

Reused 16:9 HeyGen / studio renders frequently carry baked-in **white/cream bands** down the left
and right. Measure thin edge columns vs the centre and, if bands exist, **crop LEFT/RIGHT only —
NEVER the top** (the head must not be cut):

```bash
W_SRC=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0 "$AVATAR")
H_SRC=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$AVATAR")
col_luma () {  # x → avg luma 0-255 of a 2px column at mid-frame
  v=$(ffmpeg -hide_banner -loglevel error -ss 13 -i "$AVATAR" -vframes 1 \
        -vf "crop=2:$H_SRC:$1:0,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | xxd -p)
  echo $((16#$v))
}
LEFT=0;  for x in $(seq 0 5 $((W_SRC/2)));    do [ "$(col_luma $x)" -lt 245 ] && { LEFT=$x;  break; }; done
RIGHT=$W_SRC; for x in $(seq $((W_SRC-2)) -5 $((W_SRC/2))); do [ "$(col_luma $x)" -lt 245 ] && { RIGHT=$((x+2)); break; }; done
CW=$(( RIGHT - LEFT )); CW=$(( CW - CW % 2 ))
if [ "$LEFT" -gt 4 ] || [ "$RIGHT" -lt $((W_SRC-4)) ]; then
  ffmpeg -y -i "$AVATAR" -vf "crop=$CW:$H_SRC:$LEFT:0,setsar=1" \
    -c:v libx264 -pix_fmt yuv420p -c:a copy "$W/avatar-clean.mp4"
  AVATAR_CLEAN="$W/avatar-clean.mp4"
else
  AVATAR_CLEAN="$AVATAR"
fi
```

`crop=W:H:X:0` — y-offset `0` guarantees the top edge (and head) is preserved. Verify the new
edges read content (not 255) and eyeball one frame for headroom.

### Step 2 — Build the speaker bed (full length, scale-to-cover, loudnormed ONCE)

```bash
ffmpeg -y -i "$AVATAR_CLEAN" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$W/base.mp4"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/base.mp4")
```

`letterbox` layout instead: `scale=1080:-2,pad=1080:1920:0:(1920-ih)/2:color=0x0F172A`.
**Do not slice the bed** — one unbroken audio track. Loudnorm happens here and NEVER again.

### Step 3 — Transcribe with WORD timestamps

```bash
cd "$W" && npx hyperframes transcribe base.mp4 --model small     # NO .en suffix unless the
# audio is confirmed English — .en models TRANSLATE non-English audio. Hinglish/multilingual →
# use --model medium (auto-detect). Output: word-level transcript JSON.
```

Run the **transcript quality check** (`f-hyperframes/references/transcript-guide.md`): if >20% of
entries are `♪`/garbage tokens, retry with `--model medium`; strip non-word entries. Save the
cleaned word array to `$W/words.json` (`[{text,start,end}]`).

### Step 4 — PLAN the edit with OPUS (the brain; kimi fallback)

Plan-on-Opus, execute-on-kimi (same pattern as `p-reels-hf-fmt5` Step 3). Opus reads the word
transcript + brand and writes ONE curated `plan.json` — the executor never invents anything:

```bash
PLAN_PROMPT="You are planning a PREMIUM 9:16 talking-head reel edit (speaker full-frame, never cut).
Output STRICT JSON ONLY (one object, no prose).
Word transcript: $(cat "$W/words.json")
Total duration: $DUR seconds.
Brand: <from brief via Visual Identity Gate; default bg #0F172A, accent #F97316, fg #F1F5F9>.
Schema:
{ \"duration\": $DUR, \"energy\": \"high|medium|low\", \"grade\": \"warm-amber|clean-bright\",
  \"brand\": {\"bg\":\"#hex6\",\"accent\":\"#hex6\",\"fg\":\"#hex6\"},
  \"takeovers\": [ {\"start\":s,\"end\":s,\"template\":\"tk-stat|tk-keyword|tk-list|tk-quote\",
                    \"fill\":{<per-template keys below>}} ],
  \"caption_groups\": [ {\"start\":s,\"end\":s,\"style\":0|1|2,
        \"words\":[{\"w\":\"TEXT\",\"s\":start,\"e\":end,\"em\":false}] } ],
  \"sfx\": [ {\"t\":s,\"name\":\"whoosh-deep|whoosh-air|impact-sub|impact-punch|riser|click|pop|swipe\",\"gain\":0.0-0.8} ] }
Template fill keys — tk-stat: EYEBROW, STAT (short, e.g. '3X' or '70%'), LABEL.
tk-keyword: WORD (one word), SUPPORT (short line). tk-list: TITLE, ITEM1, ITEM2, ITEM3.
tk-quote: QUOTE, ATTR. TITLE and QUOTE may wrap ONE key word in <span class=\"accent\">WORD</span>.
RULES:
1. caption_groups cover the FULL duration, 2-4 words each, non-overlapping, break on sentence
   boundaries or pauses >=150ms. Words VERBATIM from the transcript.
2. LATIN SCRIPT ONLY: if any transcript word is in Devanagari (or any non-Latin script),
   transliterate it to Latin characters phonetically. NEVER translate — Hinglish stays Hinglish.
3. At most ONE word per group gets \"em\":true — the word the speaker stresses (number, brand
   name, emotional keyword). Some groups have none.
4. \"style\" cycles 0/1/2 — never the same style on adjacent groups.
5. takeovers: 2-4 windows, 3-6s each, first no earlier than t=2, none in the final 2s, >=4s of
   speaker between windows, never the same template twice in a row. Takeover content must restate
   what is SAID in that window (numbers -> tk-stat, lists -> tk-list, one big concept ->
   tk-keyword, a quotable line -> tk-quote).
6. sfx: whoosh-deep at every takeover start, impact-sub 0.4s later on the slam, optional riser
   1.5s before the biggest takeover, click/pop on at most 3 emphasis words. Max 12 cues, gain <=0.6.
7. A visible change (takeover, emphasis pop, or caption style shift) every 2-4 seconds."

PLAN_JSON=$(env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  timeout 240 claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
  | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), re.S); print(m.group(0) if m else '')")

# FALLBACK: Opus unavailable → plan on kimi (degraded but the render completes).
if ! echo "$PLAN_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "[fmt3] Opus planning unavailable — falling back to kimi planning"
  PLAN_JSON=$(claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
    | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), __import__('re').S); print(m.group(0) if m else '')")
fi
echo "$PLAN_JSON" > "$W/plan.json"

# Mechanical guards: valid JSON, groups cover the bed, NO Devanagari anywhere in the plan.
python3 - "$W/plan.json" "$DUR" <<'PY'
import json,re,sys
p=json.load(open(sys.argv[1])); dur=float(sys.argv[2])
assert p["caption_groups"], "no caption groups"
assert abs(p["caption_groups"][-1]["end"]-dur) < 3.0, "captions do not cover the bed"
assert not re.search(r'[ऀ-ॿ]', json.dumps(p)), "Devanagari in plan — Latin script only"
for tk in p.get("takeovers",[]): assert 2.5 <= tk["end"]-tk["start"] <= 7, f"bad takeover window {tk}"
print(f"plan OK: {len(p['caption_groups'])} groups, {len(p.get('takeovers',[]))} takeovers, {len(p.get('sfx',[]))} sfx")
PY
```

### Step 5 — Assemble the composition (FILL templates — never author) and render

Every creative value is in `plan.json`; this step is mechanical. Fill the shipped templates into
a HyperFrames project, lint, render. The render is **silent** — audio comes back in Step 6:

```bash
python3 - "$W" "$SKILL_DIR" <<'PY'
import json, html, os, shutil, sys
W, SKILL = sys.argv[1], sys.argv[2]
plan = json.load(open(f"{W}/plan.json"))
dur, brand = round(float(plan["duration"]), 2), plan["brand"]
proj = f"{W}/comp"
os.makedirs(f"{proj}/compositions", exist_ok=True)
shutil.copy(f"{W}/base.mp4", f"{proj}/base.mp4")

def fill(t, m):
    for k, v in m.items(): t = t.replace("{{%s}}" % k, str(v))
    return t

RAW_KEYS = {"TITLE", "QUOTE"}   # may carry <span class="accent"> — everything else is escaped
tkdivs = []
for i, tk in enumerate(plan.get("takeovers", [])):
    d = round(float(tk["end"]) - float(tk["start"]), 2)
    m = {"ID": f"tk{i}", "DURATION": d, "BG": brand["bg"], "ACCENT": brand["accent"], "FG": brand["fg"]}
    for k, v in tk["fill"].items():
        m[k] = str(v) if k in RAW_KEYS else html.escape(str(v))
    tpl = open(f"{SKILL}/templates/{tk['template']}.html").read()
    open(f"{proj}/compositions/tk{i}.html", "w").write(fill(tpl, m))
    tkdivs.append(
        f'<div id="tk{i}-slot" class="takeover-slot" data-composition-id="tk{i}" '
        f'data-composition-src="compositions/tk{i}.html" data-start="{tk["start"]}" '
        f'data-duration="{d}" data-width="1080" data-height="1920" '
        f'data-track-index="{1 + i}"></div>')

cap = open(f"{SKILL}/templates/caption-overlay.html").read()
open(f"{proj}/compositions/caption-overlay.html", "w").write(fill(cap, {
    "DURATION": dur, "ACCENT": brand["accent"], "FG": brand["fg"],
    "GROUPS_JSON": json.dumps(plan["caption_groups"])}))

root = open(f"{SKILL}/templates/root-shell.html").read()
open(f"{proj}/index.html", "w").write(fill(root, {
    "DURATION": dur, "VIDEO_SRC": "base.mp4", "BG": brand["bg"],
    "TAKEOVER_DIVS": "\n  ".join(tkdivs)}))
print(f"assembled: {len(tkdivs)} takeovers + captions, {dur}s")
PY

cd "$W/comp" && npx hyperframes lint && npx hyperframes validate && \
  npx hyperframes render --output "$W/visuals.mp4" --fps 30 --quality high
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration -of csv=p=0 "$W/visuals.mp4"
```

If captions are `off`, drop the caption `<div>` from the root before rendering. If the brief set
manual `takeover_windows[]`, they override the planner's.

### Step 6 — Grade + audio mux (bed untouched, SFX under, ONE pass)

The graded picture and the audio mix happen in one ffmpeg pass. The bed audio (`base.mp4`, already
loudnormed once) is mapped at weight 1 through `amix=normalize=0` — its level never changes; SFX
are pre-attenuated by their planned `gain`:

```bash
python3 - "$W" "$SKILL_DIR" <<'PY' > "$W/mux.sh"
import json, sys
W, SKILL = sys.argv[1], sys.argv[2]
plan = json.load(open(f"{W}/plan.json"))
cues = plan.get("sfx", [])
GRADES = {
  "warm-amber":   "curves=r='0/0 0.5/0.55 1/1':b='0/0 0.5/0.46 1/0.95',eq=contrast=1.05:saturation=1.08,unsharp=5:5:0.5",
  "clean-bright": "eq=brightness=0.02:contrast=1.06:saturation=1.1,unsharp=5:5:0.5",
}
grade = GRADES.get(plan.get("grade", "clean-bright"), GRADES["clean-bright"])
inputs = " ".join(f"-i \"{SKILL}/assets/sfx/{c['name']}.wav\"" for c in cues)
parts, mix = [], "[1:a]"
for j, c in enumerate(cues):
    ms = int(float(c["t"]) * 1000)
    parts.append(f"[{j+2}:a]adelay={ms}|{ms},volume={min(float(c.get('gain', 0.5)), 0.8)}[s{j}]")
    mix += f"[s{j}]"
if cues:
    fc = ";".join(parts) + f";{mix}amix=inputs={len(cues)+1}:normalize=0:duration=first[aout]"
else:
    fc = "[1:a]anull[aout]"
print(f'''ffmpeg -y -i "{W}/visuals.mp4" -i "{W}/base.mp4" {inputs} \\
  -filter_complex "[0:v]{grade},format=yuv420p[vout];{fc}" \\
  -map "[vout]" -map "[aout]" \\
  -c:v libx264 -preset medium -crf 19 -r 30 \\
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "{W}/bed.mp4"''')
PY
bash "$W/mux.sh"
```

**Never loudnorm again here** — the bed was normalized once in Step 2; `normalize=0` keeps it at
exactly that level with SFX tucked under.

### Step 7 — Append the outro (optional)

```bash
ffmpeg -y -i "$OUTRO" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$W/outro.mp4"
ffmpeg -y -i "$W/bed.mp4" -i "$W/outro.mp4" \
  -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"
```

(No outro: `cp "$W/bed.mp4" "$OUT"`.)

### Step 8 — Verify (mandatory — continuity proof + Visual QA Gate)

Mechanical checks:

```bash
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -of json "$OUT"
ffmpeg -v error -i "$OUT" -f null -      # clean decode = no output

# CONTINUITY PROOF — VO present during every takeover window (from plan.json):
python3 -c "import json;[print(t['start'],t['end']-t['start']) for t in json.load(open('$W/plan.json')).get('takeovers',[])]" | \
while read s d; do echo "window $s +${d}s:"; \
  ffmpeg -hide_banner -ss "$s" -t "$d" -i "$OUT" -af volumedetect -f null - 2>&1 \
    | grep -E "mean_volume|max_volume"; done
# Every window must report a real (non -inf) mean_volume ≈ the speaker-visible level.
```

**Visual QA Gate — extract 6 frames and READ each with your vision** (a render never looked at is
not done):

```bash
for pct in 05 20 40 60 80 95; do
  t=$(python3 -c "print(round($DUR*0.$pct,1))")
  ffmpeg -y -ss "$t" -i "$OUT" -frames:v 1 "$W/qa_$pct.png"
done
```

Per frame, CHECK:
- [ ] **(a) Captions are visible and legible** in the lower-middle band, brand accent on the
      emphasis word, NOT covering the speaker's face, no overflow past the frame edges.
- [ ] **(b) Latin script only** — zero Devanagari (or other non-Latin) glyphs in any caption.
- [ ] **(c) Takeover frames show the graphics card** (opaque, full-frame, brand colors), speaker
      frames show the speaker — the alternation actually happened.
- [ ] **(d) The grade is subtle** — skin tones natural, no crushed blacks/clipped highlights.
- [ ] **(e) No black/empty frame anywhere.**

Also confirm **no static-only stretch > 3s** and that SFX are audible but clearly UNDER the voice
(spot-listen a takeover boundary). **If ANY check fails: fix, re-render, re-extract, look again.
Never ship a reel that fails the gate.**

### Step 9 — Upload to R2 and print the URL (LAST LINE)

The local file is NOT the deliverable — the worker scrapes the reply for the R2/CDN URL:

```bash
cfw-upload "$OUT" 2>/dev/null || bash _scripts/upload-to-recordings.sh "$OUT"
```

Clean up `$W` after the URL is confirmed. **Print the R2 public URL as the final line of output.**
Never print an input URL as the result.

## Fallback assembly (v0.4 ffmpeg overlay — no captions layer)

If the HyperFrames render fails after `hyperframes doctor` (chromium/memory), fall back to the
proven v0.4 ffmpeg assembly: render each takeover as a standalone composition, overlay on the bed
with `overlay=enable='between(t,a,b)'` + `setpts=PTS-STARTPTS+start/TB`, `-map 0:a` for the
unbroken audio, then burn plain SRT captions
(`subtitles=av.srt:force_style='Alignment=2,FontSize=42,MarginV=680'`). Degraded (no kinetic
captions) but complete — see git history of this file (v0.4) for the full commands, and the
verified v4 render note below for proof the technique works.

## Verified render (v0.4 technique — 2026-05-27)

The continuous-bed + white-band-crop pipeline was verified end-to-end on 2026-05-27
(`avatar-animation-reel-v4.mp4`, 36.59s, 1080×1920, zero decode errors): white bands measured at
luma 255 and cropped `crop=712:720:282:0` (top preserved), bed loudnormed once, three HyperFrames
takeovers overlaid at 8–13/17.5–22.5/27.5–30.7s, volumedetect proved the VO at full loudness under
every takeover (−17.5 to −20.6 dB, matching the speaker-visible level), silencedetect byte-identical
to the bare bed. v0.5 keeps Steps 1–2 and the continuity law verbatim from that run; only the
picture assembly moved into HyperFrames.

## Notes & gotchas

- **The speaker audio is the single voice bed — never cut it.** One continuous base layer;
  takeovers cover the picture only. SFX mix with `amix=normalize=0` so the VO level never moves.
- **Loudnorm the bed ONCE** (Step 2). Step 6 must NOT re-normalize.
- **Plan on Opus, execute on kimi.** The executor fills templates and cuts windows — it never
  authors HTML, never picks takeover content, never writes caption text.
- **Hinglish / non-English captions stay Latin-script.** The planner transliterates (rule 2) and
  the mechanical guard + QA gate (b) both reject Devanagari. Never translate — transcribe.
- **Fonts:** Oswald / Inter / JetBrains Mono only (compiler-embedded). **Barlow Condensed is NOT
  auto-resolved** by the HyperFrames compiler — don't use it. Never `var(--font-*)` in
  `font-family`.
- **Takeover cards keep content in the TOP ~55%** — the caption band sits at y≈1180-1440 and must
  never collide with card content.
- **{{ACCENT}} must be a 6-digit hex** — templates append alpha as hex pairs (`{{ACCENT}}33`).
- **Timing lives on the LOADER divs only.** Sub-composition files (templates) must NOT carry
  `data-start`/`data-duration` on their inner composition div — the root's loader div owns timing.
  Duplicating it reads as two clips on one track → `overlapping_clips_same_track` lint error.
- **The lint tag scanner does NOT skip HTML comments.** Never put literal tags or `{{TOKENS}}`
  inside template comments — a `{{TAKEOVER_DIVS}}` mention in a comment gets FILLED by the
  assembler and double-counts every clip.
- **The root index.html must be a FULL HTML document** (doctype + html/head/body, gsap in head) —
  a bare composition-div fragment makes the bundler fail with `Unexpected token '*'` at
  validate/render. Sub-composition files keep the `<template>` wrapper. The shipped `root-shell`
  already has the right shape; don't "simplify" it.
- **Inside sub-composition scripts, `window` is a sandbox Proxy that does not bind methods.**
  `window.getComputedStyle(el)` throws `Illegal invocation` — call bare globals
  (`getComputedStyle(el)`) instead. `window.__timelines` / `window.__hyperframes` are fine.
- **Run `npx hyperframes validate` after lint** — it executes the scripts in headless Chrome and
  catches runtime errors (like the above) that static lint cannot.
- **No `#` comments inside `filter_complex`** (c-ffmpeg rule) — Step 6 generates `mux.sh` for this
  reason; don't inline-edit it with comments.
- **HyperFrames render tips:** `lint` before render; `--quality draft` while iterating, `high` for
  delivery; failures → `npx hyperframes doctor`, then the v0.4 fallback above.
- **SFX pack is authored in-house** (`assets/sfx/`, ffmpeg-synthesized, CC0 by construction) —
  never download SFX from unlicensed packs (same legal rule as the music library: CC0/CC-BY only).
- **Reuse before you render.** Check prior avatar renders before calling HeyGen.
- **Relationship to siblings:** fmt5 siblings = PIP layouts (speaker in a card); p-hf-reel / fmt4 =
  faceless. fmt3 = speaker full-frame, premium caption edit. Neither subsumes the others.

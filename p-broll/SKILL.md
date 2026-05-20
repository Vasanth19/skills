---
name: p-broll
description: B-roll library management pipeline. Three actions in one — capture website scroll clips (Playwright), extract clips from existing video (c-ffmpeg trim), or upload pending library clips to Cloudflare R2. All actions register results in the brand's b-roll library.
disable-model-invocation: true
argument-hint: "[brand] capture [topic|urls...] | extract [source-video] [start] [end] [name] | upload [library?]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll — B-Roll Library Management


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Three actions: `capture` (website scroll) | `extract` (trim from video) | `upload` (batch to R2)

## Usage

```
/pipeline-broll cfw-social capture --topic "AI tools"
/pipeline-broll mr-growth-guide capture --urls "https://example.com https://example.com/pricing"
/pipeline-broll cfw-social extract --source source.mp4 --start 00:01:23 --end 00:01:35 --name wbst01-feature-demo --description "Feature demo walkthrough"
/pipeline-broll cfw-social upload
/pipeline-broll cfw-social upload --library recordings --dry-run
```

---

## Action: `capture` — Website Scroll B-Roll

**Required:** `brand`, `topic` OR `urls`

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| topic | No | — | Topic to discover 2–4 URLs for |
| urls | No | — | Explicit URLs (space-separated, skips discovery) |
| mode | No | `short-form` | `short-form` (1080×1080, 6s) or `long-form` (1920×1080, 12s) |
| prefix | No | `wbst` | Clip ID prefix |

### Steps

**1 — URL Discovery** (skip if `$urls` provided)
→ Skill: `c-web-capture` → discover 2–4 canonical URLs for `$topic`:
  - Announcement / blog post
  - Product page
  - Pricing or features page
  - GitHub repo (if technical)
Filter: publicly accessible, no login walls, visually interesting above fold.
→ Output: `interim/broll-plan/pages.json`

**2 — Capture**
→ Skill: `c-web-capture` → Playwright scroll capture
→ Mode: `$mode` preset (1.2x speed, 2s trim-start)
→ Output: `interim/broll/segments/{prefix}{NN}-{label}.mp4`

**3 — Visual Quality Check**
For each clip:
- No loading spinners in first 2 frames
- Content fully rendered (no skeleton/placeholder)
- Smooth scroll (no jumps or freeze)
- Correct aspect ratio for mode
If quality fails: recapture with longer `--wait` or trim-start.

**4 — Verify**
→ Skill: `c-ffmpeg` → ffprobe: dimensions, duration, codec

**5 — Library Update**
→ Copy clips to: `{brand_path}/creatives/brolls/recordings/`
→ Skill: `c-broll` → add each to `recordings-broll-library.md`:
  - ID: `{prefix}{NN}` (next available)
  - Zoom: `none`
  - Status: `Created`

---

## Action: `extract` — Clip from Existing Video

**Required:** `brand`, `source`, `start`, `end`, `name`, `description`

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| source | Yes | — | Path to source video |
| start | Yes | — | Start timecode (e.g., `00:01:23`) |
| end | Yes | — | End timecode (e.g., `00:01:35`) |
| name | Yes | — | Output filename slug (no extension) |
| description | Yes | — | What the clip shows |
| use_when | No | — | Script matching keywords |
| category | No | `recordings` | Library: `ai`, `app`, `recordings`, `gfx` |
| zoom | No | `none` | Zoom preset |

### Steps

**1 — Extract**
→ Skill: `c-ffmpeg` → frame-accurate trim:
```bash
ffmpeg -i "$SOURCE" -ss $START -to $END \
  -c:v libx264 -c:a aac -y "$BRAND_BROLLS/{category}/{name}.mp4"
```

**2 — Verify**
→ ffprobe → confirm duration = (end − start) ± 0.1s, codec, dimensions

**3 — Update Library**
→ Skill: `c-broll` → add row to `{category}-c-broll-library.md`:
  - Status: `Created`
  - File: `{category}/{name}.mp4`

**4 — Report**
Print: clip path, duration, library row added.

---

## Action: `upload` — Batch Upload to R2

**Required:** `brand`

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| library | No | `all` | `ai`, `app`, `recordings`, `gfx`, or `all` |
| dry_run | No | `false` | Preview pending uploads without uploading |

### Steps

**1 — Find Pending**
→ Skill: `c-broll` → read library, filter `Status == Created`
→ If `dry_run: true`: print list and stop
→ If zero pending: report "Nothing to upload." and stop

**2 — Upload**
→ Skill: `c-cloud-media` → R2 upload for each clip
Upload priority: `ai/` → `gfx/` → `recordings/` → `app/`
→ Log: ✓ uploaded | ✗ failed (with filename)

**3 — Update Library**
→ For each successful upload:
  - `Cloud`: `--` → CDN URL
  - `Status`: `Created` → `Uploaded`

**4 — CFW Registration** (optional — if CFW MCP available)
→ Skill: `c-cloud-media` → register each CDN URL as brand asset in CFW

**5 — Report**
- Total attempted / succeeded / failed
- Total CDN storage added (MB)

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.


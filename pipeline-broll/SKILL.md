---
name: pipeline-broll
description: B-roll library management pipeline. Three actions in one — capture website scroll clips (Playwright), extract clips from existing video (ffmpeg trim), or upload pending library clips to Cloudflare R2. All actions register results in the brand's b-roll library.
disable-model-invocation: true
argument-hint: "[brand] capture [topic|urls...] | extract [source-video] [start] [end] [name] | upload [library?]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll — B-Roll Library Management

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
→ Skill: `web-capture` → discover 2–4 canonical URLs for `$topic`:
  - Announcement / blog post
  - Product page
  - Pricing or features page
  - GitHub repo (if technical)
Filter: publicly accessible, no login walls, visually interesting above fold.
→ Output: `interim/broll-plan/pages.json`

**2 — Capture**
→ Skill: `web-capture` → Playwright scroll capture
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
→ Skill: `ffmpeg` → ffprobe: dimensions, duration, codec

**5 — Library Update**
→ Copy clips to: `{brand_path}/creatives/brolls/recordings/`
→ Skill: `broll` → add each to `recordings-broll-library.md`:
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
→ Skill: `ffmpeg` → frame-accurate trim:
```bash
ffmpeg -i "$SOURCE" -ss $START -to $END \
  -c:v libx264 -c:a aac -y "$BRAND_BROLLS/{category}/{name}.mp4"
```

**2 — Verify**
→ ffprobe → confirm duration = (end − start) ± 0.1s, codec, dimensions

**3 — Update Library**
→ Skill: `broll` → add row to `{category}-broll-library.md`:
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
→ Skill: `broll` → read library, filter `Status == Created`
→ If `dry_run: true`: print list and stop
→ If zero pending: report "Nothing to upload." and stop

**2 — Upload**
→ Skill: `cloud-media` → R2 upload for each clip
Upload priority: `ai/` → `gfx/` → `recordings/` → `app/`
→ Log: ✓ uploaded | ✗ failed (with filename)

**3 — Update Library**
→ For each successful upload:
  - `Cloud`: `--` → CDN URL
  - `Status`: `Created` → `Uploaded`

**4 — CFW Registration** (optional — if CFW MCP available)
→ Skill: `cloud-media` → register each CDN URL as brand asset in CFW

**5 — Report**
- Total attempted / succeeded / failed
- Total CDN storage added (MB)

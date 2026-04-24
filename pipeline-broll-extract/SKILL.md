---
name: pipeline-broll-extract
description: Extract b-roll clips from existing source video. Takes a source video, trims the specified range, writes timecards, and registers the clip in the brand b-roll library.
disable-model-invocation: true
argument-hint: "[brand] [source-video] [start] [end] [output-name]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll-extract — Extract Clips from Source Video

Trim clips from any source video → register in b-roll library.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| source_video | Yes | — | Path to source video |
| start_time | Yes | — | Start timecode (e.g., `00:01:23`) |
| end_time | Yes | — | End timecode (e.g., `00:01:35`) |
| output_name | Yes | — | Output filename (without extension) |
| category | No | `recordings` | Library category: `ai`, `app`, `recordings`, `gfx` |
| zoom | No | `none` | Zoom preset for playback |
| description | Yes | — | What the clip shows |
| use_when | Yes | — | Script matching keywords |

## Steps

### Step 1 — Extract Clip

→ Skill: `ffmpeg` → frame-accurate trim
```bash
ffmpeg -i "$SOURCE" -ss $START -to $END \
  -c:v libx264 -c:a aac -y "$OUTPUT_NAME.mp4"
```
→ Output: `{brand_path}/creatives/brolls/{category}/{output_name}.mp4`

### Step 2 — Verify

→ ffprobe → confirm duration = (end - start) ± 0.1s, codec, dimensions

### Step 3 — Write Timecards

→ `broll-plan/timecards.md` entry:
```
| {start} – {end} | {output_name}.mp4 | {duration}s | {description} |
```

### Step 4 — Update Library

→ Skill: `broll` → add row to `{category}-broll-library.md`:

| ID | File | Dur | Zoom | Description | Use When... | Cloud | Status | Source |
|----|------|-----|------|-------------|-------------|-------|--------|--------|
| {cat}{NN} | {category}/{output_name}.mp4 | {dur}s | {zoom} | {description} | {use_when} | -- | Created | {source} |

### Step 5 — Report

Print: clip path, duration, library entry added.

---
name: pipeline-broll-media
description: Embed b-roll into a CFW content variant. Fetches the content variant, rewrites the script to target duration, matches b-roll clips from the library, logs missing assets, and updates the variant in CFW.
disable-model-invocation: true
argument-hint: "[content-id-or-variant-id]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll-media — Embed B-Roll in CFW Content

Fetch CFW content → match b-roll → embed `[[duration,s,url]]` markers → update variant.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| content_id | No | — | CFW content ID (fetches default variant) |
| variant_id | No | — | CFW content variant ID (use directly) |
| rewrite | No | `auto` | `auto` (rewrite if needed) or `show-first` (show script before rewriting) |

One of `content_id` or `variant_id` required.

## Steps

### Step 1 — Fetch Content

→ CFW API → fetch content variant
→ Extract: script text, brand, target duration

If no target duration set: calculate from word count (2.5 wps).

### Step 2 — Duration Check ⛔ CHECKPOINT (if `rewrite: show-first`)

Show script + current estimated duration.
**Gate: User decides whether to rewrite or proceed.**

### Step 3 — Script Rewrite (if needed)

If script duration ≠ target:
→ Skill: `studio-script` → rewrite to duration (target: 40–60s)
→ Preserve hook, CTA, core message

**Gate: User approves rewritten script.**

### Step 4 — Match B-Roll

→ Skill: `broll` → read brand library (all 4 libraries)
→ Match clips to script segments using "Use When..." keywords
→ Format matches: `[[{duration},s,{cdn_url}]]` inline in script

B-roll embed format:
```
...script text here [[5,s,https://cdn.example.com/brolls/ai/aimg01.mp4]] more text...
```

### Step 5 — Log Missing

For script segments with no matching library clip:
→ `broll` skill → log missing: segment text + suggested clip type
→ Output: `missing-broll.md` (for future capture/generation)

### Step 6 — Present Plan ⛔ CHECKPOINT

Show:
- Script with embedded b-roll markers
- Coverage: X of Y segments covered
- Missing segments (if any)

**Gate: User approves placement.**

### Step 7 — Update CFW Variant

→ CFW API → update variant script with embedded b-roll markers
→ Confirm update success

### Step 8 — Report

- Total segments: N
- Covered: N (X%)
- Missing: N → `missing-broll.md`

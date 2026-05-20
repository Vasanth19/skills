---
name: p-broll-media
description: Embed b-roll into a CFW content variant. Fetches the content variant, rewrites the script to target duration, matches b-roll clips from the library, logs missing assets, and updates the variant in CFW.
disable-model-invocation: true
argument-hint: "[content-id-or-variant-id]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll-media — Embed B-Roll in CFW Content


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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
→ Skill: `c-studio-script` → rewrite to duration (target: 40–60s)
→ Preserve hook, CTA, core message

**Gate: User approves rewritten script.**

### Step 4 — Match B-Roll

→ Skill: `c-broll` → read brand library (all 4 libraries)
→ Match clips to script segments using "Use When..." keywords
→ Format matches: `[[{duration},s,{cdn_url}]]` inline in script

B-roll embed format:
```
...script text here [[5,s,https://cdn.example.com/brolls/ai/aimg01.mp4]] more text...
```

### Step 5 — Log Missing

For script segments with no matching library clip:
→ `c-broll` skill → log missing: segment text + suggested clip type
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

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.


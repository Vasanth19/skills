---
name: c-broll
description: B-roll library management, script matching, placement planning, and alignment verification for the creative studio. Use for reading/updating c-broll libraries, matching clips to script scenes, generating portrait/landscape placement plans, verifying SRT alignment, archiving clips from production, and previewing clip selections.
when_to_use: Trigger on b-roll, c-broll, b-roll library, clip match, placement plan, c-broll plan, SRT alignment, c-broll archive, c-broll preview, c-broll log, c-broll timecards, script to clips, b-roll coverage, c-broll library update, c-broll image rationale.
allowed-tools: Bash, Read, Write, Edit
---

# B-Roll — Library & Placement System


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## Caller Variables

| Variable | Required | Source | Description |
|----------|----------|--------|-------------|
| `{brand_local_path}` | Yes | Caller / ecosystem.yaml | Absolute path to brand folder |
| `{production}` | Yes | Caller | Absolute path to production folder |
| `$SRT_FILE` | Conditional | Caller | Transcription SRT for placement planning |
| `$LAYOUT` | Conditional | Caller | `portrait` or `landscape` |

## 4-Library Structure (Per Brand)

All reusable b-roll lives at `{brand_local_path}/creatives/brolls/`:

```
brolls/
├── ai-broll-library.md       # AI clips + Ken Burns (id prefix: aimg, ai)
├── app-broll-library.md      # App screen recordings (id prefix: app, disc, lnkd)
├── recordings-broll-library.md  # Screen/mobile/website (id prefix: wbst, scrn, mobi)
├── gfx-broll-library.md      # Graphics + overlays (id prefix: gfx, bnr)
├── ai/                       # AI-generated video clips
├── app/                      # App screen recordings
├── recordings/               # Screen, mobile, website clips
├── gfx/                      # Graphics, banners, overlays
└── images/                   # Source images (PNG/JPG) — input for AI clips
```

**Always check brolls/ before generating new assets.** After delivery, archive reusable clips with `broll-archive-from-production`.

### Library Table Schema (DB-ready)

`ID | File | Dur | Zoom | Description | Use When... | Cloud | Status | Source`

App/recordings libraries also include `POI` (points of interest) column.

| Status | Meaning |
|--------|---------|
| `Pending` | Clip exists locally, not uploaded |
| `Created` | Created this session, ready to use |
| `Uploaded` | In R2 CDN, has Cloud URL |
| `Deleted` | Removed, skip |

## Zoom Presets

| Asset type | Zoom |
|-----------|------|
| AI whiteboard | `1.1x` |
| AI cinematic/photo | `1.15x` |
| App / screen / mobile recordings | `none` |
| Static graphics | `1.15x` |
| Motion graphics | `none` |

## Script Matching

Match available clips to script scenes using:
1. **`[B-ROLL: keyword]` markers** in script — exact match attempt first
2. **Category prefix** — `app`, `wbst`, `aimg`, `gfx` match to scene context
3. **Description keyword match** — fuzzy match against "Use When..." column
4. **Fallback** — log as unmatched, flag for generation

### Coverage Targets
- VSL (landscape): 70% coverage default
- Shorts (portrait): 80% minimum coverage
- AI image allocation: 20% of b-roll slots

### use_case Parameter
- `local` — accept `Created` + `Uploaded` status, use local file path
- `cfw` — accept `Uploaded` only, use Cloud CDN URL

## Placement Plan Rules

**SRT-First Workflow (MANDATORY):**
1. Transcribe audio with MLX Whisper — get SRT file
2. Use SRT timecodes as ground truth (NEVER use script section estimates)
3. Every plan row must have "Speaker Says" column with exact SRT text
4. Run alignment verification after every plan

### Portrait Plan (9:16 Shorts)

Output: `{production}/interim/broll-plan/placement-plan-short-{NN}.md`

6-column table: `Seg | Timecode | Duration | Layout | Asset | Speaker Says`

Layout options: `bottom-avatar`, `split-equal`, `split-broll`, `pip-broll`, `popout`

Coverage ≥ 80%. Speed-factor-adjusted timestamps when atempo applied.

### Landscape Plan (16:9 VSL)

Output: `{production}/interim/broll-plan/placement-plan.md`

Coverage ≥ 70%. PIP overlay with full-screen b-roll transitions.

### Segment Gap Rules

- **Segment shorter than window** → let avatar show naturally (not a bug)
- **FULLSCREEN runs out** → switch to AVATAR FULL (not loop/freeze)
- **Static GFX** → freeze is natural for text cards
- **NEVER loop video** to fill gaps — prefer avatar transitions
- **Gap-free windows** → extend each segment's enable time to the START of the next segment

### B-Roll Plan Guards (MANDATORY)

- Min 4 unique assets per short
- No PIP segment > 6s
- Create 3-5 unique GFX cards per short from script content
- Screen recordings are supplementary, not primary
- Side-by-side image GFX must have symmetrical placement with sufficient padding

## Alignment Verification

Cross-check every b-roll segment's timecode against SRT transcript.

### Severity Levels

| Level | Definition | Action |
|-------|-----------|--------|
| OK | Timecode matches speech within ±0.5s | None |
| WARNING | Offset 0.5–2.0s or minor content mismatch | Flag, log |
| SEVERE | >2s offset or major content mismatch | Auto-fix timecodes from SRT |

**auto_fix=true (default):** When SEVERE issues found, rewrite plan with corrected timecodes + "Speaker Says" column. Backup original as `{plan}-backup.md`.

Output: `{production}/interim/broll-plan/alignment-audit.md`

## Archiving from Production

After delivery, run archive to copy reusable clips into brolls/:

```bash
# Archive AI clips
cp {production}/interim/broll/gfx/*.mp4 {brand_path}/creatives/brolls/gfx/
cp {production}/interim/broll/gfx/*.png {brand_path}/creatives/brolls/gfx/

# Update gfx-broll-library.md with new entries
# Status: Pending (not yet uploaded to R2)
```

Archive is MANDATORY on every delivery.

## Output Paths

- Placement plans: `{production}/interim/broll-plan/placement-plan*.md`
- Alignment audit: `{production}/interim/broll-plan/alignment-audit.md`
- B-roll clips: `{production}/interim/broll/segments/{id}-{desc}.mp4`
- GFX clips: `{production}/interim/broll/gfx/{id}-{desc}.mp4`
- Archived to library: `{brand_path}/creatives/brolls/{type}/{id}-{desc}.mp4`

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.


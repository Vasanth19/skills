---
name: broll
description: B-roll library management, script matching, placement planning, and alignment verification for the creative studio. Use for reading/updating broll libraries, matching clips to script scenes, generating portrait/landscape placement plans, verifying SRT alignment, archiving clips from production, and previewing clip selections.
when_to_use: Trigger on b-roll, broll, b-roll library, clip match, placement plan, broll plan, SRT alignment, broll archive, broll preview, broll log, broll timecards, script to clips, b-roll coverage, broll library update, broll image rationale.
allowed-tools: Bash, Read, Write, Edit
---

# B-Roll — Library & Placement System

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

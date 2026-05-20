---
name: r-brand-content-pipeline
description: >
  Brand-aware content pipeline. Given a brand + topic + asset, drafts
  per-platform copy, creates a LearnLoop CTA URL via c-learnloop, schedules
  the post across configured platforms via r-social-post-postforme, and files
  a single canonical post page in the brand's brain project. Reads
  `.config/posting-pipeline.yaml` from the brand repo for cadence, CTA
  provider, approval gate, voice source. Stateless — caller passes brand +
  inputs; skill composes existing c-/r- skills, never duplicates them.
when_to_use: >
  Trigger on: post for <brand>, schedule <brand> content, new mgg post, new
  cfw post, brand content pipeline, brand-aware post, mr growth guide post,
  mgg, cfw social post, gsai content, pragmatic ai lab post, draft brand
  post, ship a post.
allowed-tools: Bash, Read, Write, Skill
---

# r-brand-content-pipeline

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## What This Is

A brand-aware orchestrator that turns **(brand, topic, asset)** into a fully-scheduled, fully-documented post across the brand's configured platforms — with a unique CTA URL (LearnLoop or other provider) wired in.

This skill **composes existing skills** — it never duplicates them:

| Step | Calls | Purpose |
|------|-------|---------|
| Create CTA URL | `c-learnloop` (or other provider per config) | Generate short URL pointing to community resource |
| Upload asset | `c-cloud-media` / direct R2 | Mirror binary to brand-specific R2 bucket |
| Schedule posts | `r-social-post-postforme` | Multi-platform scheduler |
| File post page | (direct markdown write) | Canonical record in brain |

## Inputs

Required arguments:

| Arg | Type | Example |
|-----|------|---------|
| `--brand` | brand slug | `mgg`, `cfw`, `gsai`, `pal` |
| `--topic` | short string (becomes slug) | `content-flywheel` |
| `--target-date` | ISO date | `2026-05-14` |
| `--asset` | path or URL | `assets/2026-05-14-content-flywheel.mp4` |

Optional:

| Arg | Default | Example |
|-----|---------|---------|
| `--approval-gate` | from config | `none` (auto-publish) |
| `--cta-resource-id` | (auto-create) | existing LearnLoop resource_id to reuse |
| `--skip-asset-upload` | false | true if asset already mirrored |

## Config (read from brand repo)

The skill expects `.config/posting-pipeline.yaml` to exist in the brand's repo.
See `docs/posting-pipeline.yaml.example` for the canonical schema.

The skill resolves the brand repo path from `~/.gsai/ecosystem.yaml` by `brand_id`. If the entry is missing, abort with a clear error.

Two configs are read per brand:

1. `.config/posting-pipeline.yaml` — pipeline-level settings (CTA provider, approval gate, voice source, asset storage)
2. `.config/r-social-post-postforme.yaml` — existing per-brand social account IDs (do not modify; r-social-post-postforme owns it)

## Setup

```bash
# Resolve brand repo from ecosystem registry
BRAND_REPO=$(yq ".brands.${BRAND_ID}.path" ~/.gsai/ecosystem.yaml)
[ -z "$BRAND_REPO" ] && { echo "Brand $BRAND_ID not in ecosystem.yaml"; exit 1; }

# Load configs
PIPELINE_CFG="$BRAND_REPO/.config/posting-pipeline.yaml"
PFM_CFG="$BRAND_REPO/.config/r-social-post-postforme.yaml"
[ -f "$PIPELINE_CFG" ] || { echo "Missing $PIPELINE_CFG"; exit 1; }
[ -f "$PFM_CFG" ]      || { echo "Missing $PFM_CFG (run r-social-post-postforme setup first)"; exit 1; }

# Secrets per brand
source ~/.gsai/secrets.env
```

## Workflow

### Step 1 — Resolve brand context

Read these into local vars:
- Brand display name + voice file from `posting-pipeline.yaml`
- Target platforms from `posting-pipeline.yaml.platforms`
- CTA provider (`learnloop`, `ghl`, `cal_com`, `none`) from config
- Approval gate (`draft_only` | `none`) from config
- Voice source (markdown file path — usually `brand.md` in the brain)

### Step 2 — Draft per-platform copy

For each platform in `posting-pipeline.yaml.platforms`:
1. Read the brand's `brand.md` (from brain) for voice/hook formulas
2. Read last 3 posts from `projects/<brand>/posts/` for tone continuity
3. Generate hook + body + CTA placeholder for that platform
4. Respect per-platform constraints (char limits, format) from `platforms/<platform>.md`

CTA placeholder is literal `{{cta_url}}` — replaced after Step 3.

### Step 3 — Create CTA URL (if `cta.provider != none`)

Branch on provider:

**`learnloop`** — call `c-learnloop` skill:
```bash
bash $HOME/Code/skills/c-learnloop/docs/scripts/create-short-url.sh \
  --slug "${BRAND_ID}-${TOPIC_SLUG}-$(date +%Y)" \
  --resource-id "$CTA_RESOURCE_ID" \
  --community "$LL_COMMUNITY_ID"
# captures: cta_url, cta_resource_id
```

**`ghl`** — call GHL API directly (no skill yet; document inline).

**`cal_com`** — pull static link from `posting-pipeline.yaml.cta.link`.

**`none`** — skip step.

Replace `{{cta_url}}` in all drafted copy.

### Step 4 — Upload asset

If `--skip-asset-upload` is NOT set:
- If `asset_storage` is `r2://<bucket>/`: use `c-cloud-media` or `aws s3 cp` to mirror
- Get back the public/signed URL
- Otherwise: assume the asset path is already a URL or local-only

### Step 5 — Schedule via r-social-post-postforme

Build the per-platform schedule payload and invoke:
```bash
bash $HOME/Code/skills/r-social-post-postforme/docs/scripts/schedule-post.sh \
  --brand "$BRAND_ID" \
  --platforms "$PLATFORMS_CSV" \
  --copy "$COPY_JSON" \
  --media-url "$ASSET_URL" \
  --publish-at "$TARGET_DATE"
# captures: per-platform scheduled_id
```

If `approval_gate == draft_only`: skip this step. Mark status as `draft` and notify user.

### Step 6 — File post page in brain

Write `projects/<brand>/posts/<date>-<slug>.md` to the brain-personal GBrain repo at `/Users/vasanth/Code/Infra/brain-personal/`:

```yaml
---
type: post
brand: <brand>
post_id: <brand>-<date>-<seq>
date: <target-date>
status: scheduled | draft
platforms: [<list>]
learnloop_slug: <slug>
learnloop_url: <url>
cta_url: <url>
cta_provider: <provider>
asset: <asset_url>
copy:
  <platform>:
    hook: ...
    body: ...
    scheduled_id: <id>
related: [[<wikilinks>]]
tags: [<brand>, <topic-tags>]
---

# <Title>

<full markdown body documenting the post>
```

Commit + sync the brain repo:
```bash
cd /Users/vasanth/Code/Infra/brain-personal
git add -A
git -c user.email=vasanth@hyphenlabs.com -c user.name="Vas S" \
  commit -qm "post: <brand> <slug> ($TARGET_DATE)"
brain-personal sync
```

### Step 7 — Log to hive_mind (optional, if ClaudeClaw active)

Skip if ClaudeClaw not running.

## Outputs

On success, return JSON to stdout:
```json
{
  "brain_page": "projects/mgg/posts/2026-05-14-content-flywheel.md",
  "cta_url": "https://learnloop.cc/r/mgg-content-flywheel-2026",
  "platforms": {
    "facebook":  { "scheduled_id": "pfm_fb_xyz",  "publish_at": "..." },
    "instagram": { "scheduled_id": "pfm_ig_xyz",  "publish_at": "..." }
  },
  "status": "scheduled"
}
```

## Approval gate behavior

When `approval_gate == draft_only` (default for new brands):
- Steps 1–4 run as normal
- Step 5 is **skipped**
- Step 6 writes the page with `status: draft`
- Output includes `"status": "draft_pending_approval"` and the post page path
- User reviews the page, edits if needed, then re-runs with `--approval-gate none` to publish

## docs/ Folder Contents

| File | What it is |
|---|---|
| `posting-pipeline.yaml.example` | Canonical schema for the brand config file |
| `SAMPLE_POST.md` | Example output post page (filled-in) |
| `scripts/run.sh` | Top-level CLI entry — parses args, dispatches to steps |

## Brain integration

Every successful run writes ONE page to brain-personal. That page is the canonical record across all platforms — performance backfills happen by editing the same page later. Use `brain-personal query "<topic>"` to find any post by topic. Use `brain-personal list --type post --tag <brand>` to enumerate.

## Notes

- Brand-specific complexities (e.g., PAL's book-club rotation, MGG's LearnLoop community-specific tagging) live in `posting-pipeline.yaml` so this skill stays brand-agnostic.
- New brand → create `projects/<brand>/` in brain + `.config/posting-pipeline.yaml` in brand repo + entry in `~/.gsai/ecosystem.yaml`. Pipeline works immediately.
- This skill does NOT generate the asset. Compose with `p-*` project pipelines (e.g., `p-avatar-short`, `p-gfx-short`) to produce the asset first, then feed the path into this skill.

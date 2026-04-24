---
name: pipeline-broll-upload
description: B-roll upload pipeline. Finds all Created (not yet uploaded) clips in a brand's b-roll library, uploads them to Cloudflare R2, registers the CDN URLs back in the library, and optionally registers assets in the CFW database.
disable-model-invocation: true
argument-hint: "[brand] [library?]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll-upload — B-Roll Upload to R2

Batch upload all pending b-roll clips to Cloudflare R2 CDN.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| library | No | `all` | Which library: `ai`, `app`, `recordings`, `gfx`, or `all` |
| dry_run | No | `false` | Preview what would be uploaded without uploading |

## Steps

### Step 1 — Read Library

→ Skill: `broll` → read the relevant library files
→ Filter: `Status == Created` (not yet uploaded)
→ If `dry_run: true`: show list and stop

If zero clips with `Status: Created`: stop and report "Nothing to upload."

### Step 2 — Upload to R2

→ Skill: `cloud-media` → R2 upload
→ For each clip:
  ```
  aws s3 cp {local_path} s3://{R2_BUCKET}/brolls/{brand}/{subfolder}/{filename} \
    --endpoint-url {R2_ENDPOINT}
  ```
→ Construct CDN URL: `https://{R2_PUBLIC_DOMAIN}/brolls/{brand}/{subfolder}/{filename}`
→ Log: ✓ uploaded | ✗ failed

Upload priority: `ai/` first → `gfx/` → `recordings/` → `app/`

### Step 3 — Update Library

→ Skill: `broll` / `cloud-media` → for each successfully uploaded clip:
  - `Cloud`: `--` → CDN URL
  - `Status`: `Created` → `Uploaded`
→ Save updated library `.md`

### Step 4 — Report

Print summary:
- Total attempted
- Successfully uploaded
- Failed (with filenames)
- Total CDN storage added (MB)

### Step 5 — CFW Registration (optional)

If brand has a CFW account:
→ For each uploaded clip: call CFW `create_brand_asset` with CDN URL and metadata
→ Only if CFW MCP is available

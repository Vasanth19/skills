---
name: c-cloud-media
description: Cloudflare R2 upload, CDN management, and CFW Social API operations. Use for uploading b-roll clips to R2, getting CDN URLs, registering assets in CFW, fetching content/variants, updating variant scripts with b-roll tags, and finding stuck CFW workflow executions.
when_to_use: Trigger on R2 upload, CDN upload, Cloudflare R2, cloud upload, CFW Social, register asset, fetch content, variant update, b-roll embed, CFW variant, CFW content, stuck execution, workflow execution, c-broll upload CDN, cloud media.
allowed-tools: Bash
---

# Cloud Media — R2 Upload & CFW Social API

## R2 Upload

### Method A: Upload Script (Recommended)

```bash
# Single file
bash _scripts/upload-to-recordings.sh "$LOCAL_FILE"

# Returns CDN URL: https://media.cfw.social/brand-assets/{brandId}/{folderId}/{timestamp}-{uuid}.{ext}
```

### Method B: rclone Direct

```bash
TIMESTAMP=$(date +%s)
UUID=$(python3 -c "import uuid; print(uuid.uuid4().hex[:12])")
R2_KEY="brand-assets/$BRAND_ACCOUNT_ID/$FOLDER_ID/${TIMESTAMP}-${UUID}.$(echo $LOCAL_FILE | rev | cut -d. -f1 | rev)"

rclone copy "$LOCAL_FILE" "r2:$R2_BUCKET/$R2_KEY" \
  --s3-endpoint="$R2_ENDPOINT" \
  --s3-access-key-id="$AWS_ACCESS_KEY_ID" \
  --s3-secret-access-key="$AWS_SECRET_ACCESS_KEY"

CDN_URL="https://$R2_PUBLIC_DOMAIN/$R2_KEY"
echo "$CDN_URL"
```

### Default IDs

| Variable | Default | Notes |
|----------|---------|-------|
| `BRAND_ACCOUNT_ID` | `cmitgsnrm0001l204zmi8ulo3` | CFW Social brand |
| `FOLDER_ID` | `cmkothjl20001lb04x0rpqzxh` | Recordings folder |

## Register Asset in CFW Social

After uploading to R2, register so it appears in Brand Assets UI:

```bash
curl -s -X POST "https://api.cfw.social/api/brand-assets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CFW_API_KEY" \
  -d "{
    \"cdn_url\": \"$CDN_URL\",
    \"folder_id\": \"$FOLDER_ID\",
    \"file_name\": \"$FILE_NAME\",
    \"brand_account_id\": \"$BRAND_ACCOUNT_ID\"
  }"
```

Returns `asset_id`. Update c-broll library with `Cloud: $CDN_URL` and `Status: Uploaded`.

## CFW Social Content API

### Fetch Content (get script)

```bash
# By content ID
curl -s "https://api.cfw.social/api/content/$CONTENT_ID" \
  -H "Authorization: Bearer $CFW_API_KEY"
# Returns: sourceText, title, platform, status

# By variant ID
curl -s "https://api.cfw.social/api/variants/$VARIANT_ID" \
  -H "Authorization: Bearer $CFW_API_KEY"
# Returns: script, status, platform, contentId
```

### Update Variant Script (embed b-roll tags)

```bash
curl -s -X PATCH "https://api.cfw.social/api/variants/$VARIANT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CFW_API_KEY" \
  -d "{\"script\": \"$UPDATED_SCRIPT_WITH_BROLL_TAGS\"}"
```

B-roll tag format embedded in script: `[B-ROLL: wbst01 | 0:15-0:21]`

### Submit Video ID (link final render to CFW)

```bash
curl -s -X POST "https://api.cfw.social/api/variants/$VARIANT_ID/video" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CFW_API_KEY" \
  -d "{\"video_url\": \"$CDN_URL\", \"duration\": $DURATION}"
```

## Floe API — Workflow Execution

Base URL: `https://floe-production.up.railway.app`
Auth: `X-API-Key: $FLOE_API_KEY`

All requests require a unique `execution_id` — use `$(date +%s)` suffix to ensure uniqueness.

### Find Stuck Executions

```bash
curl -s "https://floe-production.up.railway.app/api/v1/executions?status=stuck" \
  -H "X-API-Key: $FLOE_API_KEY" | python3 -m json.tool
```

### Retry Stuck Execution

```bash
curl -s -X POST "https://floe-production.up.railway.app/api/v1/executions/$EXECUTION_ID/retry" \
  -H "X-API-Key: $FLOE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"execution_id\": \"retry-$(date +%s)\"}"
```

## Bulk Upload Workflow (Pending B-Roll)

1. Read c-broll library — find all rows with `Status: Pending`
2. For each: upload to R2, get CDN URL
3. Register in CFW Social — get asset_id
4. Update library row: `Status: Uploaded`, `Cloud: $CDN_URL`
5. Log completion summary

```bash
# Find pending clips in library
grep "Pending" {brand_path}/creatives/brolls/recordings-broll-library.md

# Upload each
for FILE in {brand_path}/creatives/brolls/recordings/wbst*.mp4; do
  CDN_URL=$(bash _scripts/upload-to-recordings.sh "$FILE")
  echo "$FILE → $CDN_URL"
done
```

## Output Notes

- After upload: update library `Cloud` column with CDN URL, `Status` → `Uploaded`
- CDN URL format: `https://media.cfw.social/brand-assets/{brandId}/{folderId}/{timestamp}-{uuid}.{ext}`
- Never hardcode brand/folder IDs — read from environment or ecosystem.yaml

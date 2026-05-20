---
name: c-photo-enhance
description: Free photo enhancement using ffmpeg filters. Applies named presets (cinematic, vibrant, warm, cool, bw, matte, sharp) to still images. Downloads source photo from any HTTP URL or R2, processes locally with ffmpeg, uploads result to R2. Zero API cost.
when_to_use: Trigger on photo filter, enhance photo, image filter, color grade photo, cinematic photo, warm filter, cool filter, black and white photo, matte photo, sharpen image, photo enhancement, photo preset, filter photo, grade image.
allowed-tools: Bash
---

# c-photo-enhance — Photo Filter Pipeline

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Zero API cost. ffmpeg runs locally in the container — no Replicate, no fal.ai, no external model charges.

## Caller Variables

| Variable | Required | Source | Description |
|----------|----------|--------|-------------|
| `{source_url}` | Yes | Prompt | HTTP/S URL of the source photo |
| `{preset}` | Yes | Prompt | Filter preset name (see table below) |
| `{brand_id}` | Yes | Prompt | Brand ID — used for R2 path scoping |
| `{output_format}` | No | Prompt | `jpg` (default) or `png` |

## Presets

| Preset | Effect | Best for |
|--------|--------|----------|
| `cinematic` | Contrast boost, slight desaturation, warm grade, lifted shadows | Hero shots, story content |
| `vibrant` | Punchy saturation + contrast, slight gamma lift | Product, lifestyle |
| `warm` | Red/amber toning, pulled blues | Sunset, food, cozy content |
| `cool` | Blue/teal toning, pulled reds | Tech, corporate, clean aesthetic |
| `bw` | Black & white with contrast pop | Quotes, editorial |
| `matte` | Lifted blacks, faded look, soft contrast | Vintage, editorial |
| `sharp` | Sharpening pass — no color change | Any photo that needs crispness |

## Non-Negotiable Rules

1. **Always clean up `/tmp/photo-enhance-*` after uploading.** Never leave temp files behind.
2. **Preserve original file extension in the output key** unless `{output_format}` is explicitly set.
3. **Always brand-scope the R2 key** — must start with `brands/{brand_id}/`.
4. **Fail fast** — if ffmpeg exits non-zero, print the error and stop. Do not silently upload a blank/corrupt file.
5. **JPEG quality: `-q:v 2`** (scale 1–31; 2 = near-lossless). Never use default quality.

## Steps

### Step 1 — Set up temp workspace

```bash
WORK_DIR=$(mktemp -d /tmp/photo-enhance-XXXXXX)
echo "Work dir: $WORK_DIR"
```

### Step 2 — Download source photo

```bash
SOURCE_URL="{source_url}"
FILENAME=$(basename "${SOURCE_URL%%\?*}")          # strip query params
EXT="${FILENAME##*.}"
INPUT="$WORK_DIR/input.$EXT"

curl -fsSL "$SOURCE_URL" -o "$INPUT"
echo "Downloaded $(du -sh "$INPUT" | cut -f1) — $INPUT"
```

If curl fails, stop and report the error. Do not proceed.

### Step 3 — Apply preset

Determine `{output_format}` (default `jpg` unless caller specified `png`). Set OUTPUT path and run ffmpeg.

**cinematic**
```bash
ffmpeg -i "$INPUT" \
  -vf "curves=master='0/0.05 0.5/0.5 1/0.95':red='0/0 0.5/0.53 1/1.0':blue='0/0 0.5/0.47 1/0.88',eq=contrast=1.1:saturation=0.85" \
  -q:v 2 -y "$OUTPUT"
```

**vibrant**
```bash
ffmpeg -i "$INPUT" \
  -vf "eq=contrast=1.2:saturation=1.5:brightness=0.02:gamma=0.95" \
  -q:v 2 -y "$OUTPUT"
```

**warm**
```bash
ffmpeg -i "$INPUT" \
  -vf "colorbalance=rs=0.1:gs=0.02:bs=-0.12:rm=0.06:gm=0.01:bm=-0.08:rh=0.04:gh=0:bh=-0.05,eq=saturation=1.1" \
  -q:v 2 -y "$OUTPUT"
```

**cool**
```bash
ffmpeg -i "$INPUT" \
  -vf "colorbalance=rs=-0.1:gs=0:bs=0.15:rm=-0.06:gm=0.01:bm=0.1:rh=-0.04:gh=0.01:bh=0.08,eq=saturation=0.95" \
  -q:v 2 -y "$OUTPUT"
```

**bw**
```bash
ffmpeg -i "$INPUT" \
  -vf "hue=s=0,eq=contrast=1.25:brightness=-0.02" \
  -q:v 2 -y "$OUTPUT"
```

**matte**
```bash
ffmpeg -i "$INPUT" \
  -vf "curves=master='0/0.08 0.5/0.5 1/0.90',eq=saturation=0.7:contrast=0.9" \
  -q:v 2 -y "$OUTPUT"
```

**sharp**
```bash
ffmpeg -i "$INPUT" \
  -vf "unsharp=luma_msize_x=5:luma_msize_y=5:luma_amount=1.2:chroma_msize_x=3:chroma_msize_y=3:chroma_amount=0.5" \
  -q:v 2 -y "$OUTPUT"
```

After running ffmpeg, verify the output exists and is non-empty:
```bash
[ -s "$OUTPUT" ] || { echo "ERROR: ffmpeg produced empty output"; exit 1; }
echo "Output: $(du -sh "$OUTPUT" | cut -f1)"
```

### Step 4 — Upload to R2

Use the `r2-upload` helper (installed at `/usr/local/bin/r2-upload` in Docker; on dev it's in `scripts/container/` which skill-runner prepends to PATH). It reads `R2_*` env vars automatically.

```bash
TIMESTAMP=$(date +%s)
PRESET="{preset}"
BRAND_ID="{brand_id}"
OUT_FILENAME="${TIMESTAMP}-${PRESET}-${FILENAME%.*}.${OUT_EXT}"
R2_KEY="brands/${BRAND_ID}/enhanced/${OUT_FILENAME}"

PUBLIC_URL=$(r2-upload "$OUTPUT" "$R2_KEY" "image/jpeg")
echo "Uploaded: $PUBLIC_URL"
```

If `r2-upload` exits non-zero, print the error and stop. Do not proceed.

### Step 5 — Clean up

```bash
rm -rf "$WORK_DIR"
echo "Cleaned up temp files."
```

### Step 6 — Return result

Output this exact JSON block so the cfw-agent loop can parse it as a structured result:

```
RESULT:
{
  "url": "<PUBLIC_URL>",
  "r2Key": "<R2_KEY>",
  "preset": "<PRESET>",
  "brandId": "<BRAND_ID>",
  "sourceUrl": "<SOURCE_URL>"
}
```

## Example invocations (natural language → agent picks this skill)

- "Apply a cinematic filter to this photo `https://media.cfw.social/brands/abc/raw/photo.jpg` for brand `abc`."
- "Make this photo warm-toned for brand `xyz`: `<url>`"
- "Run a b&w filter on `<url>` for brand `abc` and return the R2 URL."
- "Sharpen this product photo `<url>` for brand `abc`."
- "Enhance all 4 photos with the vibrant preset for brand `abc`: `<url1>` `<url2>` `<url3>` `<url4>`" — run one ffmpeg pass per photo, upload all, return all URLs.

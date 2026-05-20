#!/bin/bash
# r-brand-content-pipeline — entry point
# Usage:
#   bash run.sh --brand mgg --topic content-flywheel \
#               --target-date 2026-05-14 --asset assets/foo.mp4

set -euo pipefail

# -------- Parse args --------
BRAND=""
TOPIC=""
TARGET_DATE=""
ASSET=""
APPROVAL_GATE=""
CTA_RESOURCE_ID=""
SKIP_ASSET_UPLOAD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brand)            BRAND="$2"; shift 2 ;;
    --topic)            TOPIC="$2"; shift 2 ;;
    --target-date)      TARGET_DATE="$2"; shift 2 ;;
    --asset)            ASSET="$2"; shift 2 ;;
    --approval-gate)    APPROVAL_GATE="$2"; shift 2 ;;
    --cta-resource-id)  CTA_RESOURCE_ID="$2"; shift 2 ;;
    --skip-asset-upload) SKIP_ASSET_UPLOAD=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# -------- Validate inputs --------
for var in BRAND TOPIC TARGET_DATE ASSET; do
  [ -z "${!var}" ] && { echo "Missing --${var,,}" >&2; exit 1; }
done

# -------- Resolve brand repo via ecosystem.yaml --------
ECOSYSTEM=~/.gsai/ecosystem.yaml
[ ! -f "$ECOSYSTEM" ] && { echo "ecosystem.yaml not found at $ECOSYSTEM" >&2; exit 1; }

BRAND_REPO=$(yq -r ".brands.${BRAND}.path // \"\"" "$ECOSYSTEM")
[ -z "$BRAND_REPO" ] || [ ! -d "$BRAND_REPO" ] && {
  echo "Brand '$BRAND' not found in ecosystem.yaml (or path doesn't exist)" >&2
  exit 1
}

# -------- Load configs --------
PIPELINE_CFG="$BRAND_REPO/.config/posting-pipeline.yaml"
PFM_CFG="$BRAND_REPO/.config/r-social-post-postforme.yaml"

[ ! -f "$PIPELINE_CFG" ] && { echo "Missing $PIPELINE_CFG — copy from docs/posting-pipeline.yaml.example" >&2; exit 1; }
[ ! -f "$PFM_CFG" ]      && { echo "Missing $PFM_CFG — run r-social-post-postforme setup first" >&2; exit 1; }

# Source secrets
[ -f ~/.gsai/secrets.env ] && source ~/.gsai/secrets.env

# -------- Read key config values --------
PLATFORMS=$(yq -r '.platforms | join(",")' "$PIPELINE_CFG")
CTA_PROVIDER=$(yq -r '.cta.provider' "$PIPELINE_CFG")
APPROVAL_GATE="${APPROVAL_GATE:-$(yq -r '.approval_gate' "$PIPELINE_CFG")}"
VOICE_SOURCE=$(yq -r '.voice_source' "$PIPELINE_CFG")
ASSET_STORAGE=$(yq -r '.asset_storage' "$PIPELINE_CFG")
BRAIN_DEST=$(yq -r '.brain_destination' "$PIPELINE_CFG")

echo "=== r-brand-content-pipeline ==="
echo "  brand:         $BRAND"
echo "  topic:         $TOPIC"
echo "  target date:   $TARGET_DATE"
echo "  asset:         $ASSET"
echo "  platforms:     $PLATFORMS"
echo "  CTA provider:  $CTA_PROVIDER"
echo "  approval gate: $APPROVAL_GATE"

# -------- Steps --------
# (Full implementation lives in the SKILL.md workflow. Below is the
# stub structure — the agent invoking this skill fills in each step
# with real provider calls based on the config values above.)

echo "TODO: invoke each step per SKILL.md workflow"
echo "  1. Draft copy per platform (using voice from $VOICE_SOURCE)"
echo "  2. Create CTA URL via $CTA_PROVIDER"
echo "  3. Upload asset to $ASSET_STORAGE (skip=$SKIP_ASSET_UPLOAD)"
echo "  4. Schedule via r-social-post-postforme"
echo "  5. Write brain page to $BRAIN_DEST"
echo "  6. Commit + sync brain-personal"

#!/bin/bash
# Sync fal.ai model list from Floe registry
# Called automatically by SKILL.md — refreshes if cache is > 4 days old

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_FILE="$SKILL_DIR/models.jsonl"
FLOE_REGISTRY="/Users/vasanth/Code/video-apps/floe/src/integrations/ai/fal/media-gen/models.ts"

# Check freshness — skip if < 4 days old
if [ -f "$MODELS_FILE" ]; then
  AGE=$(python3 -c "
import json, datetime
with open('$MODELS_FILE') as f:
    header = json.loads(f.readline())
synced = header.get('synced_at', '')
if synced:
    delta = (datetime.datetime.utcnow() - datetime.datetime.fromisoformat(synced)).days
    print(delta)
else:
    print(999)
" 2>/dev/null || echo "999")
  if [ "$AGE" -lt 4 ]; then
    exit 0
  fi
fi

echo "[fal-ai] Syncing model list from Floe registry..." >&2

python3 - <<'PYEOF'
import json, re, datetime, sys

registry_path = "/Users/vasanth/Code/video-apps/floe/src/integrations/ai/fal/media-gen/models.ts"
try:
    with open(registry_path) as f:
        content = f.read()
except FileNotFoundError:
    print(f"ERROR: Floe registry not found at {registry_path}", file=sys.stderr)
    sys.exit(1)

# Match: 'provider:operation': { endpointId: '...', ..., outputType: '...' }
pattern = r"'([^']+)':\s*\{([^}]+)\}"
models = []
for match in re.finditer(pattern, content, re.DOTALL):
    key, body = match.groups()
    if ':' not in key:
        continue
    provider, operation = key.split(':', 1)

    endpoint_m = re.search(r"endpointId:\s*'([^']+)'", body)
    output_m   = re.search(r"outputType:\s*'([^']+)'", body)
    if not endpoint_m:
        continue

    models.append({
        "key":        key,
        "provider":   provider,
        "operation":  operation,
        "endpoint_id": endpoint_m.group(1),
        "output_type": output_m.group(1) if output_m else "unknown",
    })

out_file = "/Users/vasanth/Code/skills/fal-ai/models.jsonl"
with open(out_file, 'w') as f:
    f.write(json.dumps({
        "synced_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "count":     len(models),
        "source":    "floe-registry",
        "registry":  registry_path,
    }) + '\n')
    for m in models:
        f.write(json.dumps(m) + '\n')

print(f"[fal-ai] Synced {len(models)} models → models.jsonl")
PYEOF

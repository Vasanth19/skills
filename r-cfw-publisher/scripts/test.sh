#!/usr/bin/env bash
# Shape-check — validates all scripts parse + --help flow + decrypt round-trip.
# No network calls. Run this in CI or after editing the skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ok  — $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL — $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "== r-cfw-publisher tests =="

# 1. Bash syntax check
for s in run.sh publish-one.sh list-due.sh test.sh; do
  check "bash -n $s" bash -n "$SCRIPT_DIR/$s"
done

# 2. Node syntax check (decrypt-token.mjs)
check "node --check decrypt-token.mjs" node --check "$SCRIPT_DIR/decrypt-token.mjs"

# 3. --help on every entrypoint should exit 0
check "run.sh --help"        bash "$SCRIPT_DIR/run.sh" --help
check "publish-one.sh --help" bash "$SCRIPT_DIR/publish-one.sh" --help

# 4. Missing args produce non-zero
check "run.sh (no args) fails"        bash -c "! bash '$SCRIPT_DIR/run.sh' 2>/dev/null"
check "publish-one.sh (no args) fails" bash -c "! bash '$SCRIPT_DIR/publish-one.sh' 2>/dev/null"

# 5. Decrypt round-trip — encrypt with node, decrypt with our script
KEY_HEX="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
ENVELOPE="$(ENCRYPTION_KEY="$KEY_HEX" node -e '
  const c = require("crypto");
  const key = Buffer.from(process.env.ENCRYPTION_KEY, "hex");
  const iv = c.randomBytes(12);
  const cipher = c.createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([cipher.update("hello-secret", "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  console.log(`v1:${iv.toString("base64")}:${ct.toString("base64")}:${tag.toString("base64")}`);
')"
PT="$(ENCRYPTION_KEY="$KEY_HEX" node "$SCRIPT_DIR/decrypt-token.mjs" "$ENVELOPE")"
if [[ "$PT" == "hello-secret" ]]; then
  echo "  ok  — decrypt round-trip"
  PASS=$((PASS + 1))
else
  echo "  FAIL — decrypt round-trip (got: '$PT')"
  FAIL=$((FAIL + 1))
fi

echo
echo "passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1

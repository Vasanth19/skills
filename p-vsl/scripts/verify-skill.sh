#!/usr/bin/env bash
# p-vsl/scripts/verify-skill.sh
# Static checks on the skill's own files (no real cook needed).
# Usage: bash scripts/verify-skill.sh
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
pass(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check(){ local label="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }

echo "=== p-vsl static checks ==="

# Frontmatter
check "SKILL.md exists"                    test -f "$SKILL_DIR/SKILL.md"
check "name: p-vsl"                        grep -q "^name: p-vsl" "$SKILL_DIR/SKILL.md"
check "kind: pipeline"                     grep -q "^kind: pipeline" "$SKILL_DIR/SKILL.md"
check "visibility: catalog"               grep -q "^visibility: catalog" "$SKILL_DIR/SKILL.md"
check "lists c-broll-sync dep"            grep -q "c-broll-sync" "$SKILL_DIR/SKILL.md"
check "lists c-reel-premium dep"          grep -q "c-reel-premium" "$SKILL_DIR/SKILL.md"
check "lists c-typing-ui dep"             grep -q "c-typing-ui" "$SKILL_DIR/SKILL.md"
check "lists c-heygen dep"                grep -q "c-heygen" "$SKILL_DIR/SKILL.md"
check "lists wowx-focus dep"              grep -q "wowx-focus" "$SKILL_DIR/SKILL.md"
check "has hermes.vendored"               grep -q "vendored:" "$SKILL_DIR/SKILL.md"
check "no c-html-gfx dep (replaced)"      bash -c "! grep -q 'c-html-gfx' '$SKILL_DIR/SKILL.md'"

# Landscape templates
for t in motion-card-ls typing-scene-ls hook-scene-ls caption-overlay-ls root-shell-polish-ls; do
  check "templates/$t.html exists"        test -f "$SKILL_DIR/templates/$t.html"
done
check "motion-card-ls is 1920x1080"       grep -q "width: 1920px" "$SKILL_DIR/templates/motion-card-ls.html"
check "motion-card-ls reserves pip-band"  grep -q "pip-band" "$SKILL_DIR/templates/motion-card-ls.html"
check "hook-scene-ls is 1920x1080"        grep -q 'data-width="1920"' "$SKILL_DIR/templates/hook-scene-ls.html"
check "caption-overlay-ls clears PIP"     grep -q "right: 440px" "$SKILL_DIR/templates/caption-overlay-ls.html"
check "root-shell-polish-ls is full doc"  grep -qi "<!doctype html>" "$SKILL_DIR/templates/root-shell-polish-ls.html"

# Graphics templates: no window.getComputedStyle / Math.random in <script>
for t in motion-card-ls typing-scene-ls hook-scene-ls caption-overlay-ls; do
  SS=$(sed -n '/<script>/,/<\/script>/p' "$SKILL_DIR/templates/$t.html" 2>/dev/null)
  if echo "$SS" | grep -q "window.getComputedStyle"; then fail "$t uses window.getComputedStyle"; else pass "$t bare getComputedStyle"; fi
  if echo "$SS" | grep -q "Math.random()"; then fail "$t uses Math.random()"; else pass "$t no Math.random()"; fi
done

# SKILL.md guard rails
check "landscape canvas 1920x1080"        grep -q "CW=1920" "$SKILL_DIR/SKILL.md"
check "framed-inset PIP default (304x380)" grep -q "PIP_W=304 ; PIP_H=380" "$SKILL_DIR/SKILL.md"
check "framed-inset PIP alternation L/R"   grep -q "PIP_X_RIGHT" "$SKILL_DIR/SKILL.md"
check "framed-inset PIP gold frame"        grep -q "pip-frame.png" "$SKILL_DIR/SKILL.md"
check "loudnorm present"                  grep -q "loudnorm" "$SKILL_DIR/SKILL.md"
check "amix normalize=0"                  grep -q "normalize=0" "$SKILL_DIR/SKILL.md"
check "COVER_AT extraction"              grep -q "COVER_AT" "$SKILL_DIR/SKILL.md"
check "avatar-grammar pass present"       grep -q "avatar_plan.json" "$SKILL_DIR/SKILL.md"
check "wowx-focus for screen recordings"  grep -q "apply_focus.py" "$SKILL_DIR/SKILL.md"
check "FIT+blurred-fill background"       grep -q "boxblur=40:2" "$SKILL_DIR/SKILL.md"
check "zoom-then-crop keyed avatar"       grep -q "scale=2208:1242,crop=1920:1080:144:0" "$SKILL_DIR/SKILL.md"
check "R2 upload + URL print"            grep -q "cfw-upload" "$SKILL_DIR/SKILL.md"
check "CAP_TOP landscape (820)"          grep -q "CAP_TOP=820" "$SKILL_DIR/SKILL.md"

# Component skills on disk
_find(){ find "$HOME/.claude/skills" "$HOME/.hermes/skills" /Users/vasanth/Code/skills -maxdepth 4 -type d -name "$1" 2>/dev/null | head -1; }
BS=$(_find c-broll-sync); PR=$(_find c-reel-premium); TU=$(_find c-typing-ui); WX=$(_find wowx-focus)
check "c-broll-sync/scripts/plan.js"     test -f "${BS:-/dev/null}/scripts/plan.js"
check "c-reel-premium templates/"        test -d "${PR:-/dev/null}/templates"
check "c-typing-ui found"                test -n "$TU"
check "wowx-focus/apply_focus.py"        test -f "${WX:-/dev/null}/apply_focus.py"

echo ""
echo "Results: ${PASS} pass, ${FAIL} fail"
[ "$FAIL" -eq 0 ] && echo "All checks passed." || { echo "Some checks failed — fix before bake-off."; exit 1; }

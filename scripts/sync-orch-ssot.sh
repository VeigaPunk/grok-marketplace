#!/usr/bin/env bash
# Sync orch SSoT + godspeed/wwkd skills from Projects sources into xbgst-stack.
# Default sources: ~/Projects/xbgst/{myskills,godspeed-core} (override MYSKILLS=/ GODSPEED_CORE=).
# Does not touch livepatch/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/plugins/xbgst-stack"
MYSKILLS="${MYSKILLS:-$HOME/Projects/xbgst/myskills}"
GODSPEED_CORE="${GODSPEED_CORE:-$HOME/Projects/xbgst/godspeed-core}"
SSOT_DST="$STACK/ssot/godspeed-core"
GODSPEED_DST="$STACK/skills/godspeed"
WWKD_DST="$STACK/skills/wwkd"

usage() {
  cat <<'EOF'
Usage: sync-orch-ssot.sh [--help|-h] [--check]

  (default)  copy godspeed-core + godspeed/wwkd skill sources into
             plugins/xbgst-stack/{ssot,skills}; copy godspeed/directive.md
             as a real file from ssot/godspeed-core/directive.md (plugin
             install skips symlinks).
  --check    exit 0 if already in sync (no writes); exit 1 if drift.
  MYSKILLS=/path  GODSPEED_CORE=/path  override sources.

Does not touch: livepatch/, plugin.json, install-host.sh, heuer-planning,
the-kimiraikkonen / the-kimiraikkoner.
EOF
}

CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --check) CHECK_ONLY=1 ;;
    --*) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
    "") ;;
    *) echo "Unexpected positional arg: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -d "$MYSKILLS/godspeed" || ! -d "$MYSKILLS/wwkd" || ! -d "$GODSPEED_CORE" ]]; then
  echo "FAIL: orch sources not found (need $MYSKILLS/{godspeed,wwkd} and $GODSPEED_CORE)" >&2
  exit 1
fi

# Rendered godspeed SKILL.md: Projects-only SSoT path → host ~/.grok/ssot path.
render_godspeed_skill() {
  local src=$1
  local dest=$2
  # Prefer updating the known Projects line; fall back to verbatim copy if absent.
  if grep -q 'Projects/xbgst/godspeed-core/directive.md' "$src" 2>/dev/null; then
    sed -E 's|That file is a symlink to the SSoT \(`~/Projects/xbgst/godspeed-core/directive\.md` → `~/\.grok/ssot/godspeed-core/directive\.md`\)\.|That file mirrors the SSoT (`~/.grok/ssot/godspeed-core/directive.md`).|; s|That file is a symlink to the SSoT \(`~/\.grok/ssot/godspeed-core/directive\.md`\)\.|That file mirrors the SSoT (`~/.grok/ssot/godspeed-core/directive.md`).|' \
      "$src" >"$dest"
  else
    cp -a "$src" "$dest"
  fi
}

check_drift() {
  local drift=0
  local f tmp
  mkdir -p "$SSOT_DST" "$GODSPEED_DST" "$WWKD_DST"
  for f in directive.md filter.md velocity.md README.md; do
    if [[ ! -f "$GODSPEED_CORE/$f" ]]; then
      echo "MISSING source $GODSPEED_CORE/$f"
      drift=1
      continue
    fi
    if [[ ! -f "$SSOT_DST/$f" ]] || ! diff -q "$GODSPEED_CORE/$f" "$SSOT_DST/$f" >/dev/null 2>&1; then
      echo "DRIFT $SSOT_DST/$f"
      drift=1
    fi
  done

  tmp=$(mktemp)
  render_godspeed_skill "$MYSKILLS/godspeed/SKILL.md" "$tmp"
  if [[ ! -f "$GODSPEED_DST/SKILL.md" ]] || ! diff -q "$tmp" "$GODSPEED_DST/SKILL.md" >/dev/null 2>&1; then
    echo "DRIFT $GODSPEED_DST/SKILL.md"
    drift=1
  fi
  rm -f "$tmp"

  if [[ -L "$GODSPEED_DST/directive.md" ]]; then
    echo "DRIFT $GODSPEED_DST/directive.md (want real file, not symlink)"
    drift=1
  elif [[ ! -f "$GODSPEED_DST/directive.md" ]] || ! diff -q "$SSOT_DST/directive.md" "$GODSPEED_DST/directive.md" >/dev/null 2>&1; then
    echo "DRIFT $GODSPEED_DST/directive.md (want copy of ssot/godspeed-core/directive.md)"
    drift=1
  fi

  if [[ ! -f "$WWKD_DST/SKILL.md" ]] || ! diff -q "$MYSKILLS/wwkd/SKILL.md" "$WWKD_DST/SKILL.md" >/dev/null 2>&1; then
    echo "DRIFT $WWKD_DST/SKILL.md"
    drift=1
  fi

  return "$drift"
}

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if check_drift; then
    echo "OK  orch ssot/skills in sync with $MYSKILLS + $GODSPEED_CORE"
    exit 0
  fi
  echo "FAIL: orch ssot/skills drift from sources"
  exit 1
fi

echo "→ sync orch from $MYSKILLS + $GODSPEED_CORE"
mkdir -p "$SSOT_DST" "$GODSPEED_DST" "$WWKD_DST"
for f in directive.md filter.md velocity.md README.md; do
  cp -a "$GODSPEED_CORE/$f" "$SSOT_DST/$f"
done
render_godspeed_skill "$MYSKILLS/godspeed/SKILL.md" "$GODSPEED_DST/SKILL.md"
# Real file: grok plugin install skips symlinks.
rm -f "$GODSPEED_DST/directive.md"
cp -a "$SSOT_DST/directive.md" "$GODSPEED_DST/directive.md"
cp -a "$MYSKILLS/wwkd/SKILL.md" "$WWKD_DST/SKILL.md"
echo "✓ synced → $SSOT_DST"
echo "✓ synced → $GODSPEED_DST (directive.md real-file copy)"
echo "✓ synced → $WWKD_DST"
echo "→ next: bash plugins/xbgst-stack/scripts/install-host.sh && ./scripts/smoke-gates.sh"

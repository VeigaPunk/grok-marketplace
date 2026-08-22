#!/usr/bin/env bash
# Install the grok-bot xbgst-surface layer:
#   - ~/.agents/skills/xbgst-surface -> this integration
#   - ~/.grokbot/workflows/xbgst-surface/{SKILL.md,helpers}
#   - ~/.config/grok-bot-flags.conf CDP block
# Does not rewrite Electron. Does not write settings.json.
# Exit 0 on success or skip.
set -euo pipefail

INTEGRATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XBGST_SURFACE_DEST:-$HOME/.agents/skills/xbgst-surface}"
WF="${XBGST_SURFACE_WORKFLOW:-$HOME/.grokbot/workflows/xbgst-surface}"
FLAGS="${XBGST_SURFACE_FLAGS:-$HOME/.config/grok-bot-flags.conf}"
PORT="${XBGST_SURFACE_CDP:-9333}"
SRC="$INTEGRATION"

is_ours() {
  local cur=$1
  [[ -n "$cur" ]] || return 1
  if [[ "$cur" == "$INTEGRATION" || "$cur" == "$INTEGRATION"/* ]]; then
    return 0
  fi
  return 1
}

link_one() {
  local dest=$1
  local src=$2
  local cur want
  want=$(readlink -f "$src" 2>/dev/null || true)
  if [[ -L "$dest" ]]; then
    cur=$(readlink -f "$dest" 2>/dev/null || true)
    if [[ -n "$cur" && -n "$want" && "$cur" == "$want" ]]; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    if is_ours "$cur"; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  if [[ -e "$dest" ]]; then
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
}

install_flags() {
  local begin="# xbgst-surface begin"
  local end="# xbgst-surface end"
  local block
  block=$(printf '%s\n--remote-debugging-port=%s\n--remote-allow-origins=*\n%s\n' "$begin" "$PORT" "$end")
  mkdir -p "$(dirname "$FLAGS")"
  if [[ ! -f "$FLAGS" ]]; then
    printf '%s' "$block" >"$FLAGS"
    echo "wrote $FLAGS"
    return 0
  fi
  if grep -F -q -- "$begin" "$FLAGS"; then
    local tmp
    tmp=$(mktemp)
    awk -v b="$begin" -v e="$end" -v blk="$block" '
      $0==b {print blk; skip=1; next}
      skip && $0==e {skip=0; next}
      skip {next}
      {print}
    ' "$FLAGS" >"$tmp"
    if ! grep -F -q -- "$begin" "$tmp"; then
      printf '%s\n' "$block" >>"$tmp"
    fi
    mv "$tmp" "$FLAGS"
    echo "refreshed $FLAGS"
    return 0
  fi
  printf '\n%s' "$block" >>"$FLAGS"
  echo "appended $FLAGS"
}

mkdir -p "$(dirname "$DEST")"
set +e
link_one "$DEST" "$SRC"
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  echo "linked $DEST -> $SRC"
fi

mkdir -p "$WF"
set +e
link_one "$WF/SKILL.md" "$INTEGRATION/SKILL.md"
link_one "$WF/xbgst-surface-ping.sh" "$INTEGRATION/bin/xbgst-surface-ping.sh"
link_one "$WF/xbgst-surface-run.sh" "$INTEGRATION/bin/xbgst-surface-run.sh"
link_one "$WF/xbgst-surface-inject.sh" "$INTEGRATION/bin/xbgst-surface-inject.sh"
set -e
echo "workflow $WF"

install_flags
exit 0

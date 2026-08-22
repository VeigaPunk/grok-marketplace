#!/usr/bin/env bash
# Symlink this integration dir to $HOME/.agents/skills/xbgst-surface.
# link_one semantics from scripts/install-host.sh. Does not write settings.json
# or touch ~/.cursor. Exit 0 on success or skip.
set -euo pipefail

INTEGRATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XBGST_SURFACE_DEST:-$HOME/.agents/skills/xbgst-surface}"
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

mkdir -p "$(dirname "$DEST")"
set +e
link_one "$DEST" "$SRC"
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  echo "linked $DEST -> $SRC"
fi
exit 0

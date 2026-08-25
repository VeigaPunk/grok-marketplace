#!/usr/bin/env bash
# PATH wrap: prepend canonical godspeed directive + one `| godspeed` on prompt
# flags. Never wrap kimi-code. Real binary is GODSPEED_WRAP_REAL.
set -euo pipefail

REAL="${GODSPEED_WRAP_REAL:-}"
[[ -n "$REAL" && -x "$REAL" ]] || {
  echo "godspeed-cli-wrap: GODSPEED_WRAP_REAL missing or not executable" >&2
  exit 2
}

self_base="${0##*/}"
real_base="${REAL##*/}"
case "$self_base" in
  kimi|kimi-code) exec "$REAL" "$@" ;;
esac
case "$real_base" in
  kimi|kimi-code) exec "$REAL" "$@" ;;
esac

GT_SH="${GODSPEED_GX_TEAMS_SH:-}"
if [[ -z "$GT_SH" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$here/../gx-teams.sh" ]]; then
      GT_SH="$here/../gx-teams.sh"
    fi
  fi
fi
if [[ -z "$GT_SH" && -n "${HOME:-}" ]]; then
  shopt -s nullglob
  for cand in \
    "$HOME"/.grok/installed-plugins/xbgst-stack-*/integrations/gx-teams/gx-teams.sh \
    "$HOME/Projects/xbgst/gx-teams/gx-teams.sh"
  do
    if [[ -f "$cand" ]]; then
      GT_SH="$cand"
      break
    fi
  done
  shopt -u nullglob
fi
[[ -f "$GT_SH" ]] || {
  echo "godspeed-cli-wrap: gx-teams.sh not found" >&2
  exit 2
}

GX_TEAMS_SOURCE_ONLY=1
# shellcheck source=../gx-teams.sh
source "$GT_SH"

# Caller argv does not include the CLI name. Inject needs it to pick the
# flag table (grok -p VALUE vs cursor-agent -p boolean).
argv=("$real_base" "$@")
inject_godspeed_into_grok_prompt argv
exec "$REAL" "${argv[@]:1}"

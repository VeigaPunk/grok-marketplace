#!/usr/bin/env bash
# gx-teams M01 — detached tmux team session, titled panes, hardcap 16, nuke.
set -euo pipefail

HARDCAP=16
STATE_ROOT="${GX_TEAMS_STATE:-$HOME/.gx-teams}"
ID_RE='^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$'
SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GODSPEED_SHA256='db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb'
GODSPEED_SUFFIX='| godspeed'

usage() {
  cat <<'EOF'
Usage:
  gx-teams.sh spawn --team <team> --name <name> -- cmd <argv...>
  gx-teams.sh nuke  --team <team>
  gx-teams.sh dm    --team <team> --to <name> --text <text>
EOF
}

die() { printf 'gx-teams: %s\n' "$*" >&2; exit 1; }

resolve_godspeed_directive() {
  local candidate digest had_nullglob=0
  local -a candidates=()

  [[ -n "${GX_TEAMS_GODSPEED_DIRECTIVE:-}" ]] \
    && candidates+=("$GX_TEAMS_GODSPEED_DIRECTIVE")
  candidates+=(
    "$SCRIPT_ROOT/../../ssot/godspeed-core/directive.md"
    "$SCRIPT_ROOT/../grok-marketplace/plugins/xbgst-stack/ssot/godspeed-core/directive.md"
  )
  if [[ -n "${HOME:-}" ]]; then
    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob
    candidates+=(
      "$HOME"/.grok/installed-plugins/xbgst-stack-*/ssot/godspeed-core/directive.md
      "$HOME"/.grok/marketplace-cache/*/plugins/xbgst-stack/ssot/godspeed-core/directive.md
      "$HOME/.grok/ssot/godspeed-core/directive.md"
    )
    (( had_nullglob )) || shopt -u nullglob
  fi

  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" && -r "$candidate" ]] || continue
    digest=$(sha256sum -- "$candidate" | awk '{print $1}')
    if [[ "$digest" == "$GODSPEED_SHA256" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  die "canonical Godspeed directive unavailable (want sha256 $GODSPEED_SHA256)"
}

trim_trailing_whitespace() {
  local value="$1"
  while [[ "$value" == *[$' \t\r\n'] ]]; do
    value="${value%?}"
  done
  printf '%s' "$value"
}

compose_godspeed_prompt() {
  local body="$1" directive_path directive
  directive_path=$(resolve_godspeed_directive)
  # read -d '' preserves the canonical file's final newline at EOF.
  IFS= read -r -d '' directive <"$directive_path" || true
  # Callers may already have composed a prompt. Remove canonical prefixes so
  # this boundary remains idempotent while still sourcing the packaged bytes.
  while [[ "$body" == "$directive"* ]]; do
    body="${body#"$directive"}"
    while [[ "$body" == $'\n'* || "$body" == $'\r'* ]]; do
      body="${body#?}"
    done
  done
  body=$(trim_trailing_whitespace "$body")
  while [[ "$body" == *"$GODSPEED_SUFFIX" ]]; do
    body="${body%"$GODSPEED_SUFFIX"}"
    body=$(trim_trailing_whitespace "$body")
  done
  printf '%s\n%s\n%s' "$directive" "$body" "$GODSPEED_SUFFIX"
}

inject_godspeed_into_grok_prompt() {
  local -n argv_ref="$1"
  local i token grok_seen=0
  for ((i = 0; i < ${#argv_ref[@]}; i++)); do
    token="${argv_ref[$i]}"
    if [[ "${token##*/}" == grok ]]; then
      grok_seen=1
      continue
    fi
    (( grok_seen )) || continue
    case "$token" in
      -p|--prompt)
        (( i + 1 < ${#argv_ref[@]} )) || die "$token requires a prompt"
        argv_ref[$((i + 1))]=$(compose_godspeed_prompt "${argv_ref[$((i + 1))]}")
        ((i++))
        ;;
      --prompt=*)
        argv_ref[$i]="--prompt=$(compose_godspeed_prompt "${token#--prompt=}")"
        ;;
    esac
  done
}

# Allowlist: no :, ., /, space, .. — tmux grammar + path safety.
validate_id() {
  local kind="$1" val="$2"
  [[ -n "$val" ]] || die "$kind required"
  [[ "$val" =~ $ID_RE ]] || die "invalid $kind: $val (want $ID_RE)"
}

refuse_operator_team() {
  local team="$1"
  case "$team" in
    0|1) die "refusing operator team name: $team" ;;
  esac
}

# Spark/sekhmet namespaces only when argv asks. Other CLIs (grok/kimi/qwen/xask stock) do not get XBRD_SPARK_ROOT.
argv_wants_spark() {
  local i=0
  local -a a=("$@")
  for ((i = 0; i < ${#a[@]}; i++)); do
    case "${a[$i]}" in
      --spark|--spk|sekhmet) return 0 ;;
      --substrate)
        (( i + 1 < ${#a[@]} )) || continue
        [[ "${a[$((i + 1))]}" == sekhmet ]] && return 0
        ;;
    esac
  done
  return 1
}

session_name() { printf 'gx-teams-%s' "$1"; }

# Exact session target (tmux prefix-matches without =).
starget() { printf '=%s' "$1"; }

pane_count() {
  local s="$1"
  tmux list-panes -s -t "$(starget "$s")" 2>/dev/null | wc -l | tr -d ' '
}

ensure_state_under_root() {
  local team="$1"
  mkdir -p "$STATE_ROOT"
  [[ ! -L "$STATE_ROOT" ]] || die "refusing symlink STATE_ROOT"
  local root dest
  root=$(realpath "$STATE_ROOT")
  mkdir -p "$STATE_ROOT/$team"
  [[ ! -L "$STATE_ROOT/$team" ]] || die "refusing symlink team state"
  dest=$(realpath "$STATE_ROOT/$team")
  case "$dest" in
    "$root"|"$root"/*) ;;
    *) die "state path escapes STATE_ROOT: $dest" ;;
  esac
  # refuse if dest is STATE_ROOT itself (team empty/..)
  [[ "$dest" != "$root" ]] || die "state path must be under STATE_ROOT"
  mkdir -p "$STATE_ROOT/$team/inboxes"
  mkdir -p "$STATE_ROOT/$team/godspeed"
}

write_godspeed() {
  local team="$1" name="$2"
  ensure_state_under_root "$team"
  local directive_path
  directive_path=$(resolve_godspeed_directive)
  install -m 0600 -- "$directive_path" "$STATE_ROOT/$team/godspeed/${name}.txt"
}

record_pane() {
  local team="$1" name="$2" pane="$3" pid="$4"
  ensure_state_under_root "$team"
  local dir="$STATE_ROOT/$team"
  local cfg="$dir/config.json"
  local tmpdir="${5:-}"
  local lock="$dir/config.lock"
  write_cfg() {
    local tmp src
    tmp=$(mktemp -- "$dir/config.json.XXXXXX") || die "mktemp config failed"
    if [[ -f "$cfg" ]]; then
      src="$cfg"
    else
      printf '{"team":"%s","panes":{}}\n' "$team" >"$tmp.empty"
      src="$tmp.empty"
    fi
    if command -v jq >/dev/null 2>&1; then
      if [[ -n "$tmpdir" ]]; then
        jq --arg n "$name" --arg p "$pane" --arg pid "$pid" --arg td "$tmpdir" \
          '.panes[$n]={pane_id:$p,pane_pid:$pid,tmpdir:$td}' "$src" >"$tmp"
      else
        jq --arg n "$name" --arg p "$pane" --arg pid "$pid" \
          '.panes[$n]={pane_id:$p,pane_pid:$pid}' "$src" >"$tmp"
      fi
    else
      if [[ -n "$tmpdir" ]]; then
        printf '{"team":"%s","panes":{"%s":{"pane_id":"%s","pane_pid":"%s","tmpdir":"%s"}}}\n' \
          "$team" "$name" "$pane" "$pid" "$tmpdir" >"$tmp"
      else
        printf '{"team":"%s","panes":{"%s":{"pane_id":"%s","pane_pid":"%s"}}}\n' \
          "$team" "$name" "$pane" "$pid" >"$tmp"
      fi
    fi
    mv -f -- "$tmp" "$cfg"
    rm -f -- "$tmp.empty"
  }
  if command -v flock >/dev/null 2>&1; then
    (
      flock 9
      write_cfg
    ) 9>"$lock"
  else
    write_cfg
  fi
}

cmd_spawn() {
  local team="" name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --team) team="${2:-}"; shift 2 ;;
      --name) name="${2:-}"; shift 2 ;;
      --) shift; break ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown spawn arg: $1" ;;
    esac
  done
  validate_id team "$team"
  validate_id name "$name"
  refuse_operator_team "$team"
  [[ $# -gt 0 ]] || die "spawn requires -- <mode> <argv...>"

  local mode="$1"; shift
  case "$mode" in
    cmd) ;;
    claude|TeamCreate)
      die "denied mode: $mode (no wrap / no TeamCreate)" ;;
    *) die "unknown mode: $mode (want: cmd)" ;;
  esac
  [[ $# -gt 0 ]] || die "cmd requires a command"
  command -v fnm >/dev/null 2>&1 || die "BLOCKED: fnm missing"

  # Keep pane alive so capture-pane finds output (scout pattern A).
  local user_cmd inner
  local -a command_argv=("$@")
  inject_godspeed_into_grok_prompt command_argv
  user_cmd=$(printf '%q ' "${command_argv[@]}")
  user_cmd=${user_cmd% }

  local S T
  S=$(session_name "$team")
  T=$(starget "$S")
  if tmux has-session -t "$T" 2>/dev/null; then
    local n
    n=$(pane_count "$S")
    if (( n >= HARDCAP )); then
      die "hardcap $HARDCAP: session $S already has $n panes"
    fi
  fi

  local tmpdir spark_root mail_root
  tmpdir=$(mktemp -d -- "/tmp/xbgst-gx-${team}-${name}-XXXXXX") || die "mktemp TMPDIR failed"
  trap 'rm -rf -- "$tmpdir"' EXIT RETURN
  mail_root="${tmpdir}/mail"
  mkdir -m 0700 -- "$mail_root" || die "mkdir pane mail failed"
  spark_root=""
  if argv_wants_spark "${command_argv[@]}"; then
    spark_root="${tmpdir}/spark"
    mkdir -m 0700 -- "$spark_root" || die "mkdir pane spark failed"
  fi
  local qtd qmr qhomebin
  qtd=$(printf '%q' "$tmpdir")
  qmr=$(printf '%q' "$mail_root")
  qhomebin=$(printf '%q' "${HOME}/.local/bin")
  # fnm multishells ALWAYS. Never env -i. Never GC fnm_multishells.
  # Keep fnm env PATH (shim/bin first). Only prepend ~/.local/bin so xask
  # survives. Do not inject /usr/bin ahead of the shim.
  inner="eval \"\$(fnm env --shell bash)\" || { echo 'gx-teams: BLOCKED: fnm env failed' >&2; exit 1; }"
  inner+="; export PATH=${qhomebin}:\"\$PATH\""
  inner+="; export TMPDIR=${qtd} XBGST_MAIL_ROOT=${qmr}"
  if [[ -n "$spark_root" ]]; then
    inner+=" XBRD_SPARK_ROOT=$(printf '%q' "$spark_root")"
  else
    inner+="; unset XBRD_SPARK_ROOT"
  fi
  inner+="; trap 'rm -rf -- ${qtd}' EXIT; ${user_cmd}; exec sleep infinity"

  local parent=""
  if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    parent=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}' 2>/dev/null || true)
  fi
  local id_env=(
    -e "GX_TEAM=$team"
    -e "GX_TEAMMATE_NAME=$name"
    -e "GX_TEAMMATE_ID=${name}@${team}"
    -e "GX_PARENT_SESSION=${parent}"
    -e "TMPDIR=${tmpdir}"
    -e "XBGST_MAIL_ROOT=${mail_root}"
  )
  if [[ -n "$spark_root" ]]; then
    id_env+=(-e "XBRD_SPARK_ROOT=${spark_root}")
  fi

  local meta pane pid
  if tmux has-session -t "$T" 2>/dev/null; then
    meta=$(tmux new-window -t "$T" -d -P \
      -F '#{window_id} #{pane_id} #{pane_pid}' \
      -n "$name" \
      "${id_env[@]}" \
      -- bash -c "$inner")
    pane=$(awk '{print $2}' <<<"$meta")
    pid=$(awk '{print $3}' <<<"$meta")
  else
    # NEVER omit -d. NEVER use new-session -t (session group).
    meta=$(tmux new-session -d -P \
      -F '#{session_name} #{session_id} #{window_id} #{pane_id} #{pane_pid}' \
      -s "$S" -n "$name" -x 80 -y 24 \
      "${id_env[@]}" \
      -- bash -c "$inner")
    pane=$(awk '{print $4}' <<<"$meta")
    pid=$(awk '{print $5}' <<<"$meta")
  fi

  tmux select-pane -t "$pane" -T "$name"
  tmux set-option -t "$pane" remain-on-exit on
  # tmux -e can lag /proc/$pid/environ by a tick; gates read it immediately.
  local _i
  for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if tr '\0' '\n' < /proc/"$pid"/environ 2>/dev/null | grep -qx "GX_TEAM=${team}"; then
      break
    fi
    sleep 0.05
  done
  record_pane "$team" "$name" "$pane" "$pid" "$tmpdir"
  trap - EXIT RETURN
  write_godspeed "$team" "$name"
  printf '%s %s %s\n' "$S" "$pane" "$pid"
}

cmd_nuke() {
  local team=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --team) team="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown nuke arg: $1" ;;
    esac
  done
  validate_id team "$team"
  refuse_operator_team "$team"
  local S T cfg
  S=$(session_name "$team")
  T=$(starget "$S")
  cfg="$STATE_ROOT/$team/config.json"
  # Snapshot pane tmpdirs before kill-session so a concurrent spawn after
  # kill is not in the allowlist.
  local -a snapshot=()
  if [[ -f "$cfg" ]] && command -v jq >/dev/null 2>&1; then
    local td
    while IFS= read -r td; do
      snapshot+=("$td")
    done < <(jq -r '.panes[]? | .tmpdir // empty' "$cfg")
  fi
  # Never kill-server. Never touch operator sessions 0/1.
  if tmux has-session -t "$T" 2>/dev/null; then
    tmux kill-session -t "$T"
  fi
  local prefix="/tmp/xbgst-gx-${team}-"
  local td
  for td in "${snapshot[@]}"; do
    [[ -n "$td" && "$td" != "null" ]] || continue
    case "$td" in
      */) die "refusing trailing slash tmpdir" ;;
    esac
    [[ "$td" == "$prefix"* ]] || continue
    case "$td" in
      *..*) die "refusing tmpdir with .." ;;
    esac
    [[ -L "$td" ]] && continue
    [[ -d "$td" ]] || continue
    local resolved
    resolved=$(realpath -- "$td") || die "tmpdir realpath failed: $td"
    [[ "$resolved" == "$prefix"* ]] || die "tmpdir escapes prefix: $td -> $resolved"
    case "$resolved" in
      *fnm_multishells*) die "refusing fnm_multishells tmpdir" ;;
    esac
    if [[ -n "${FNM_DIR:-}" ]]; then
      local fnm
      fnm=$(realpath -- "$FNM_DIR" 2>/dev/null || true)
      if [[ -n "$fnm" && ( "$resolved" == "$fnm" || "$resolved" == "$fnm"/* ) ]]; then
        die "refusing FNM_DIR tmpdir"
      fi
    fi
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
      local xdg
      xdg=$(realpath -- "$XDG_RUNTIME_DIR" 2>/dev/null || true)
      if [[ -n "$xdg" && ( "$resolved" == "$xdg" || "$resolved" == "$xdg"/* ) ]]; then
        die "refusing XDG_RUNTIME_DIR tmpdir"
      fi
    fi
    rm -rf -- "$resolved"
  done
  if [[ -e "$STATE_ROOT/$team" ]]; then
    mkdir -p "$STATE_ROOT"
    local root dest
    root=$(realpath "$STATE_ROOT")
    dest=$(realpath "$STATE_ROOT/$team")
    case "$dest" in
      "$root"/*)
        [[ "$dest" != "$root" ]] || die "refusing rm of STATE_ROOT"
        [[ ! -L "$STATE_ROOT" && ! -L "$STATE_ROOT/$team" ]] || die "refusing symlink state path"
        rm -rf -- "$dest"
        ;;
      *) die "state path escapes STATE_ROOT: $dest" ;;
    esac
  fi
  printf 'nuked %s\n' "$S"
}

cmd_dm() {
  local team="" to="" text=""
  local have_text=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --team) team="${2:-}"; shift 2 ;;
      --to) to="${2:-}"; shift 2 ;;
      --text) text="${2:-}"; have_text=1; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown dm arg: $1" ;;
    esac
  done
  validate_id team "$team"
  validate_id name "$to"
  refuse_operator_team "$team"
  (( have_text )) || die "dm requires --text"
  local inbox_dir="$STATE_ROOT/$team/inboxes"
  # No mkdir here — missing dir must fail (never silent no-op).
  [[ -d "$inbox_dir" ]] || die "missing inboxes dir for team $team"
  local inbox="$inbox_dir/${to}.jsonl"
  [[ ! -L "$inbox_dir" && ! -L "$inbox" ]] || die "refusing symlink inbox"
  local ts id line
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    id=$(< /proc/sys/kernel/random/uuid)
  else
    id="$(date -u +%s)-$$-$RANDOM"
  fi
  local mailbox=""
  mailbox=$(command -v xbgst-mailbox 2>/dev/null || true)
  if [[ -z "$mailbox" && -x "$SCRIPT_ROOT/mailbox/target/release/xbgst-mailbox" ]]; then
    mailbox="$SCRIPT_ROOT/mailbox/target/release/xbgst-mailbox"
  elif [[ -z "$mailbox" && -x "$SCRIPT_ROOT/mailbox/target/debug/xbgst-mailbox" ]]; then
    mailbox="$SCRIPT_ROOT/mailbox/target/debug/xbgst-mailbox"
  fi
  # JSONL is the log. Crate is required. jq only if XBGST_MAILBOX_ALLOW_JQ=1.
  if [[ -n "$mailbox" ]]; then
    "$mailbox" append "$inbox" --ts "$ts" --id "$id" --from lead --to "$to" --type dm --text "$text" \
      || die "dm write failed: $inbox"
  elif [[ "${XBGST_MAILBOX_ALLOW_JQ:-0}" == "1" ]] && command -v jq >/dev/null 2>&1; then
    line=$(jq -nc --arg ts "$ts" --arg id "$id" --arg to "$to" --arg text "$text" \
      '{ts:$ts,id:$id,from:"lead",to:$to,type:"dm",text:$text}')
    printf '%s\n' "$line" >>"$inbox" || die "dm write failed: $inbox"
  else
    die "xbgst-mailbox required for dm (XBGST_MAILBOX_ALLOW_JQ=1 for jq log fallback)"
  fi
  # Optional ACP fire: fail-fast send if a live fifo exists. Missing fifo ≠ fail.
  local fifo="$STATE_ROOT/$team/live-dm/${to}.fifo"
  if [[ -p "$fifo" ]]; then
    local here
    here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    python3 "$here/scripts/acp-live-dm.py" send --fifo "$fifo" --text "$text" >/dev/null 2>&1 || true
  fi
  printf 'sent\n'
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 2; }
  local op="$1"; shift
  case "$op" in
    spawn) cmd_spawn "$@" ;;
    nuke)  cmd_nuke "$@" ;;
    dm)    cmd_dm "$@" ;;
    -h|--help) usage ;;
    *) die "unknown op: $op" ;;
  esac
}

if [[ "${GX_TEAMS_SOURCE_ONLY:-0}" != 1 ]]; then
  main "$@"
fi

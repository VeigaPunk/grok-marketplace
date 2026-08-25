#!/usr/bin/env bash
# grok-build-livepatch — check for a new Grok Build CLI release and re-apply
# the ban-generic-subagents patch on the fly.
#
# Exit codes:
#   0  up to date / patched OK / no action needed
#   1  failure
#   2  new release detected but patch did not apply cleanly (needs human)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-and-patch.sh [--help|-h]

Check for a new Grok Build CLI release and re-apply the ban-generic-subagents
livepatch (clone/fetch, cargo build — network-heavy).

  --help, -h   Print this help and exit 0 (no network, no clone).

Zero-arg path runs the full check (may network). There is no dry-run flag;
only --help skips network without other flags.

Exit codes:
  0  ok / noop / already-applied / ok-reassert
  1  failure
  2  needs human rebase (patch does not apply)

last-result tokens (under GROK_LIVEPATCH_STATE):
  ok | ok-reassert | noop | already-applied | needs-rebase | fail

Env:
  GROK_LIVEPATCH_STATE, GROK_BUILD_SRC, GROK_LIVEPATCH_INSTALL,
  GROK_LIVEPATCH_FORCE=1, GROK_LIVEPATCH_REPLACE_BIN=1

  Timer unit defaults REPLACE_BIN=1 (active CLI = livepatch). Set
  Environment=GROK_LIVEPATCH_REPLACE_BIN=0 on the unit to keep stock CLI.

When upstream version matches last-patched and FORCE is unset: reverse-check
noop, or clean re-apply + unit smoke; skip release rebuild if install binary
exists (still re-links CLI when REPLACE_BIN=1). Full cargo rebuild on version
advance or missing install binary.
EOF
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${GROK_LIVEPATCH_STATE:-$HOME/.local/state/grok-build-livepatch}"
SRC_DIR="${GROK_BUILD_SRC:-$HOME/Projects/grok-build}"
PATCH="$ROOT/patches/0001-ban-generic-subagents.patch"
# Recap kill: stack ships 0006-kill-session-recap.patch; standalone livepatch
# already used 0006 for mailbox, so that tree ships 0007-kill-session-recap.patch.
PATCH_RECAP="$ROOT/patches/0006-kill-session-recap.patch"
if [[ ! -f "$PATCH_RECAP" ]]; then
  PATCH_RECAP="$ROOT/patches/0007-kill-session-recap.patch"
fi
LOG="$STATE_DIR/watch.log"
VERSION_FILE="$HOME/.grok/version.json"
BIN_LINK="$HOME/.grok/bin/grok"
INSTALL_DIR="${GROK_LIVEPATCH_INSTALL:-$HOME/.local/opt/grok-build-livepatch}"

mkdir -p "$STATE_DIR" "$INSTALL_DIR"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

# Read version.json without requiring python3 (jq preferred; python3 fallback).
read_version_json() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.stable_version // .version // empty' "$f" 2>/dev/null || true
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("stable_version") or d.get("version") or "")' "$f" 2>/dev/null || true
  fi
}

current_installed() {
  if [[ -x "$BIN_LINK" ]]; then
    "$BIN_LINK" --version 2>/dev/null | head -1 | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true
  fi
  read_version_json "$VERSION_FILE"
}

# Latest public release tag on xai-org/grok-build (or VERSION from install channel)
fetch_upstream_version() {
  # Prefer GitHub tags on the open-source tree
  local tag
  tag=$(git ls-remote --tags --refs https://github.com/xai-org/grok-build.git 2>/dev/null \
    | awk -F/ '{print $NF}' | grep -E '^[0-9]' | sort -V | tail -1 || true)
  tag=$(printf '%s' "${tag:-}" | tr -d '[:space:]')
  if [[ -n "${tag:-}" ]]; then
    echo "$tag"
    return
  fi
  # Fallback: grok update check leaves version.json
  local v
  v=$(read_version_json "$VERSION_FILE" | head -1 | tr -d '[:space:]')
  if [[ -n "${v:-}" ]]; then
    echo "$v"
    return
  fi
  echo ""
}

last_patched() {
  # Trim whitespace/newlines so version-match compares cleanly against tags.
  tr -d '\r\n' <"$STATE_DIR/last-patched-version" 2>/dev/null | head -c 128 || true
}

ensure_source() {
  if [[ ! -d "$SRC_DIR/.git" ]]; then
    log "cloning xai-org/grok-build → $SRC_DIR"
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone --depth 1 https://github.com/xai-org/grok-build.git "$SRC_DIR"
  fi
  log "fetching upstream in $SRC_DIR"
  # Shallow-safe: advance origin/main (or master) explicitly, then tags.
  # Bare `fetch --tags` alone can leave origin/main stale on depth-1 clones.
  if ! git -C "$SRC_DIR" fetch --depth 1 --force origin main:refs/remotes/origin/main 2>&1 | tee -a "$LOG"; then
    git -C "$SRC_DIR" fetch --depth 1 --force origin master:refs/remotes/origin/master 2>&1 | tee -a "$LOG" \
      || git -C "$SRC_DIR" fetch --force origin 2>&1 | tee -a "$LOG" \
      || log "WARN: fetch origin failed"
  fi
  git -C "$SRC_DIR" fetch --tags --force origin 2>&1 | tee -a "$LOG" || true
  # Prefer main/synced tip
  git -C "$SRC_DIR" checkout -f main 2>/dev/null || git -C "$SRC_DIR" checkout -f master 2>/dev/null || true
  if ! git -C "$SRC_DIR" reset --hard origin/main 2>/dev/null \
    && ! git -C "$SRC_DIR" reset --hard origin/master 2>/dev/null; then
    log "WARN: reset --hard origin/main|master failed; trying pull --ff-only"
    git -C "$SRC_DIR" pull --ff-only 2>&1 | tee -a "$LOG" || log "WARN: source reset/pull failed — working tree may be stale"
  fi
}

# Sets APPLY_ONE_STATUS: applied | already-applied | three-way | missing
# Returns 0, or 2 on fail. Missing patch file is a no-op (status=missing).
apply_one_patch() {
  local patch=$1
  local label=$2
  APPLY_ONE_STATUS=missing
  [[ -f "$patch" ]] || return 0
  if git apply --check "$patch" 2>"$STATE_DIR/apply-check-${label}.err"; then
    git apply "$patch"
    log "$label applied cleanly"
    APPLY_ONE_STATUS=applied
    return 0
  fi
  if git apply --reverse --check "$patch" 2>"$STATE_DIR/apply-reverse-check-${label}.err"; then
    log "$label already present (reverse-check OK)"
    APPLY_ONE_STATUS=already-applied
    return 0
  fi
  if git apply --3way "$patch" 2>"$STATE_DIR/apply-3way-${label}.err"; then
    log "$label applied with 3-way merge"
    APPLY_ONE_STATUS=three-way
    return 0
  fi
  log "$label FAILED — needs human rebase"
  APPLY_ONE_STATUS=fail
  return 2
}

# Sets APPLY_STATUS: applied | already-applied | three-way | needs-rebase | fail
# Sets RECAP_STATUS via apply_one_patch when the recap patch exists.
apply_patch() {
  APPLY_STATUS=fail
  RECAP_STATUS=missing
  cd "$SRC_DIR"
  # clean any previous livepatch branch
  git checkout -B livepatch/ban-generic-subagents
  # 1) clean apply
  if git apply --check "$PATCH" 2>"$STATE_DIR/apply-check.err"; then
    git apply "$PATCH"
    log "patch applied cleanly"
    APPLY_STATUS=applied
    apply_one_patch "$PATCH_RECAP" recap || return 2
    RECAP_STATUS="$APPLY_ONE_STATUS"
    return 0
  fi
  # 2) already applied only if reverse --check succeeds (do not OR-grep symbols alone)
  if git apply --reverse --check "$PATCH" 2>"$STATE_DIR/apply-reverse-check.err"; then
    log "patch already present (reverse-check OK) — already-applied"
    APPLY_STATUS=already-applied
    apply_one_patch "$PATCH_RECAP" recap || return 2
    RECAP_STATUS="$APPLY_ONE_STATUS"
    return 0
  fi
  if git grep -q 'is_banned_subagent_type' -- '*.rs' 2>/dev/null; then
    log "WARN: ban symbols present but reverse --check failed — trying 3-way"
  fi
  # 3) try 3-way
  if git apply --3way "$PATCH" 2>"$STATE_DIR/apply-3way.err"; then
    log "patch applied with 3-way merge"
    APPLY_STATUS=three-way
    apply_one_patch "$PATCH_RECAP" recap || return 2
    RECAP_STATUS="$APPLY_ONE_STATUS"
    return 0
  fi
  # 4) needs human
  log "PATCH FAILED — needs human rebase"
  APPLY_STATUS=needs-rebase
  cat "$STATE_DIR/apply-check.err" >>"$LOG" || true
  cat "$STATE_DIR/apply-reverse-check.err" >>"$LOG" 2>/dev/null || true
  cat "$STATE_DIR/apply-3way.err" >>"$LOG" || true
  return 2
}

# Point ~/.grok/bin/grok at install binary when REPLACE_BIN is enabled.
ensure_cli_link() {
  if [[ "${GROK_LIVEPATCH_REPLACE_BIN:-0}" != "1" ]]; then
    return 0
  fi
  if [[ ! -x "$INSTALL_DIR/grok" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$BIN_LINK")"
  ln -sfn "$INSTALL_DIR/grok" "$BIN_LINK"
  log "ensured CLI link $BIN_LINK → $INSTALL_DIR/grok"
  # Grok Titanium host name (Codex Titanium twin): same banned binary.
  local titanium_dir titanium_path
  titanium_dir="${GROK_TITANIUM_INSTALL:-$HOME/.local/opt/grok-titanium}"
  titanium_path="${GROK_TITANIUM_PATH_LINK:-$HOME/.local/bin/grok-titanium}"
  mkdir -p "$titanium_dir" "$(dirname "$titanium_path")"
  ln -sfn "$INSTALL_DIR/grok" "$titanium_dir/grok"
  ln -sfn "$titanium_dir/grok" "$titanium_path"
  log "ensured grok-titanium $titanium_path → $titanium_dir/grok → $INSTALL_DIR/grok"
}

build_and_install() {
  cd "$SRC_DIR"
  log "cargo build --release (xai-tool-types + grok binary if present)"
  # No python/jq probe: always build the typed crate, then best-effort binary packages.
  cargo build --release -p xai-tool-types 2>&1 | tee -a "$LOG"
  if ! cargo build --release -p xai-grok-pager-bin 2>&1 | tee -a "$LOG"; then
    cargo build --release 2>&1 | tee -a "$LOG" || true
  fi

  # Find built grok binary
  local bin
  bin=$(find "$SRC_DIR/target/release" -maxdepth 1 -type f -executable \( -name 'grok' -o -name 'xai-grok*' -o -name 'grok-build*' \) 2>/dev/null | head -1 || true)
  if [[ -n "${bin:-}" ]]; then
    install -m 755 "$bin" "$INSTALL_DIR/grok"
    if [[ "${GROK_LIVEPATCH_REPLACE_BIN:-0}" == "1" ]]; then
      ensure_cli_link
    else
      log "built binary at $INSTALL_DIR/grok (timer unit defaults REPLACE_BIN=1; set 0 to keep stock CLI)"
    fi
  else
    log "no release binary found; library patch validated via cargo build -p xai-tool-types only"
  fi
}

run_unit_smoke() {
  cd "$SRC_DIR"
  cargo test -p xai-tool-types banned_subagent -- --nocapture 2>&1 | tee -a "$LOG" || {
    log "unit smoke failed"
    return 1
  }
}

main() {
  log "=== livepatch check start ==="
  log "ROOT=$ROOT SRC_DIR=$SRC_DIR INSTALL_DIR=$INSTALL_DIR"
  log "PATCH=$PATCH"
  local installed upstream last
  installed=$(current_installed | head -1)
  upstream=$(fetch_upstream_version)
  last=$(last_patched)
  log "installed=${installed:-?} upstream=${upstream:-?} last_patched=${last:-none}"

  if [[ ! -f "$PATCH" ]]; then
    log "FAIL: patch missing at $PATCH"
    echo "fail" >"$STATE_DIR/last-result"
    exit 1
  fi

  ensure_source

  # Version-match fast path (!FORCE): cheap re-assert without full release rebuild.
  # 1) reverse-check OK → already-applied tree (e.g. failed reset) → pure noop
  #    (still refresh CLI link if REPLACE_BIN=1 and install binary exists)
  # 2) forward --check OK → clean tip after reset → apply + unit smoke; skip cargo
  #    rebuild if install binary exists; still ensure CLI link when REPLACE_BIN=1
  # Else fall through to full apply/rebuild (true drift / conflict).
  if [[ "${GROK_LIVEPATCH_FORCE:-0}" != "1" && -n "$upstream" && "$upstream" == "$last" ]]; then
    if git -C "$SRC_DIR" apply --reverse --check "$PATCH" 2>"$STATE_DIR/apply-reverse-check.err"; then
      # 0001 is in the tree. Recap is a later series member: if it is not
      # reverse-clean, apply it and rebuild. Do not noop past a new patch.
      if [[ -f "$PATCH_RECAP" ]] \
        && ! git -C "$SRC_DIR" apply --reverse --check "$PATCH_RECAP" 2>"$STATE_DIR/apply-reverse-check-recap.err"; then
        log "0001 already present; recap not in tree — apply recap + rebuild"
        git -C "$SRC_DIR" checkout -B livepatch/ban-generic-subagents
        cd "$SRC_DIR"
        apply_one_patch "$PATCH_RECAP" recap || {
          echo "needs-rebase" >"$STATE_DIR/last-result"
          log "=== livepatch needs human rebase (recap) ==="
          exit 2
        }
        run_unit_smoke
        build_and_install
        echo "${upstream}" >"$STATE_DIR/last-patched-version"
        echo "ok-recap $(ts)" >"$STATE_DIR/last-result"
        log "=== livepatch OK (recap applied onto existing 0001) ==="
        exit 0
      fi
      log "already patched for $upstream (reverse-check OK) — noop"
      ensure_cli_link
      echo "noop" >"$STATE_DIR/last-result"
      exit 0
    fi
    if git -C "$SRC_DIR" apply --check "$PATCH" 2>"$STATE_DIR/apply-check.err"; then
      log "version match: clean tip — re-assert patch + unit smoke (light path)"
      git -C "$SRC_DIR" checkout -B livepatch/ban-generic-subagents
      git -C "$SRC_DIR" apply "$PATCH"
      recap_new=0
      if [[ -f "$PATCH_RECAP" ]]; then
        if git -C "$SRC_DIR" apply --check "$PATCH_RECAP" 2>"$STATE_DIR/apply-check-recap.err"; then
          git -C "$SRC_DIR" apply "$PATCH_RECAP"
          recap_new=1
          log "recap applied cleanly (light path)"
        elif git -C "$SRC_DIR" apply --reverse --check "$PATCH_RECAP" >/dev/null 2>&1; then
          log "recap already present (light path)"
        else
          log "recap patch FAILED on light path — needs human rebase"
          echo "needs-rebase" >"$STATE_DIR/last-result"
          exit 2
        fi
      fi
      run_unit_smoke
      if [[ "$recap_new" -eq 1 || ! -x "$INSTALL_DIR/grok" ]]; then
        log "building (recap newly applied or install binary missing)"
        build_and_install
      else
        ensure_cli_link
      fi
      echo "${upstream}" >"$STATE_DIR/last-patched-version"
      echo "ok-reassert $(ts)" >"$STATE_DIR/last-result"
      log "=== livepatch OK (reassert) ==="
      exit 0
    fi
    if git -C "$SRC_DIR" grep -q 'is_banned_subagent_type' -- '*.rs' 2>/dev/null; then
      log "WARN: version match + ban symbols but neither reverse nor forward clean — full re-apply"
    else
      log "version match but tree not apply-clean — full re-apply"
    fi
  fi

  APPLY_STATUS=fail
  set +e
  apply_patch
  rc=$?
  set -e
  if [[ $rc -eq 2 ]]; then
    echo "needs-rebase" >"$STATE_DIR/last-result"
    log "=== livepatch needs human rebase ==="
    exit 2
  fi
  if [[ $rc -ne 0 ]]; then
    echo "fail" >"$STATE_DIR/last-result"
    exit 1
  fi

  # Full reverse-clean already-applied: skip rebuild only when recap is also
  # already in the tree. A newly applied recap must cargo-install.
  if [[ "${APPLY_STATUS:-}" == "already-applied" ]]; then
    case "${RECAP_STATUS:-missing}" in
      applied|three-way)
        log "0001 already-applied; recap newly applied — rebuild"
        ;;
      *)
        ensure_cli_link
        echo "${upstream:-$(ts)}" >"$STATE_DIR/last-patched-version"
        echo "already-applied $(ts)" >"$STATE_DIR/last-result"
        log "=== livepatch already-applied (noop rebuild) ==="
        exit 0
        ;;
    esac
  fi

  run_unit_smoke
  build_and_install

  echo "${upstream:-$(ts)}" >"$STATE_DIR/last-patched-version"
  echo "ok $(ts)" >"$STATE_DIR/last-result"
  log "=== livepatch OK ==="
}

main "$@"

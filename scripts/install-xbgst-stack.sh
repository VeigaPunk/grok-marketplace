#!/usr/bin/env bash
# One-shot grok-orch overlay: marketplace → plugin install --trust → install-host.
# Fail-closed. No config.toml curl/overwrite. No livepatch apply. No plazirhangar shape.
set -euo pipefail

MARKETPLACE_SPEC="VeigaPunk/grok-marketplace"
PLUGIN_SPEC="xbgst-stack@veigapunk/grok-marketplace"
PLUGIN_NAME="xbgst-stack"

usage() {
  cat <<'EOF'
Usage: install-xbgst-stack.sh [--from-tree <marketplace-root>] [--install-timer] [--help|-h]

  Primary (network): marketplace add + plugin install --trust + that plugin's install-host.
  --from-tree PATH   skip network; run PATH/plugins/xbgst-stack/scripts/install-host.sh
                     after validating plugin.json name is xbgst-stack
  --install-timer    pass through to install-host.sh (opt-in)

Honor GROK_HOME (default ~/.grok). Does not apply livepatch or FORCE=1.
Conservative raw pin: .../grok-stable/scripts/install-xbgst-stack.sh (git tag, not marketplace @tag).
EOF
}

die() { echo "FAIL: $*" >&2; exit 1; }

resolve_plugin_dir() {
  local grok_home=$1
  local details path reg_path
  local -a matches=()
  local d name

  if command -v grok >/dev/null 2>&1; then
    if details=$(GROK_HOME="$grok_home" grok plugin details "$PLUGIN_NAME" 2>/dev/null); then
      path=""
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
          path=${BASH_REMATCH[1]}
          path=${path%"${path##*[![:space:]]}"}
          break
        fi
      done <<<"$details"
      if [[ -n "$path" && -d "$path" && -f "$path/plugin.json" ]]; then
        name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$path/plugin.json")
        if [[ "$name" == "$PLUGIN_NAME" ]]; then
          printf '%s\n' "$path"
          return 0
        fi
      fi
    fi
  fi

  if [[ -f "$grok_home/installed-plugins/registry.json" ]]; then
    set +e
    reg_path=$(GROK_HOME="$grok_home" PLUGIN_NAME="$PLUGIN_NAME" python3 - <<'PY'
import json, os, sys
home = os.environ["GROK_HOME"]
want = os.environ["PLUGIN_NAME"]
reg = json.load(open(os.path.join(home, "installed-plugins", "registry.json")))
hits = []
for _k, repo in (reg.get("repos") or {}).items():
    plugins = repo.get("plugins") or {}
    if want in plugins:
        p = repo.get("path") or ""
        if p and os.path.isdir(p):
            hits.append(p)
if len(hits) == 1:
    print(hits[0])
    sys.exit(0)
if len(hits) > 1:
    sys.exit(2)
sys.exit(1)
PY
)
    local reg_ec=$?
    set -e
    if [[ "$reg_ec" -eq 2 ]]; then
      die "multiple registry entries for $PLUGIN_NAME; refuse planted/ambiguous plugin"
    fi
    if [[ "$reg_ec" -eq 0 && -n "${reg_path:-}" ]]; then
      printf '%s\n' "$reg_path"
      return 0
    fi
  fi

  shopt -s nullglob
  for d in "$grok_home"/installed-plugins/xbgst-stack-*; do
    [[ -d "$d" && -f "$d/plugin.json" ]] || continue
    name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$d/plugin.json")
    if [[ "$name" == "$PLUGIN_NAME" ]]; then
      matches+=("$d")
    fi
  done
  shopt -u nullglob

  if [[ "${#matches[@]}" -eq 1 ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi
  if [[ "${#matches[@]}" -eq 0 ]]; then
    die "no installed plugin dir with plugin.json name=$PLUGIN_NAME under $grok_home/installed-plugins"
  fi
  die "multiple plugin dirs named $PLUGIN_NAME under installed-plugins; refuse planted/ambiguous plugin"
}

merge_enable_plugin() {
  local cfg=$1
  if [[ ! -f "$cfg" ]]; then
    echo "→ no $cfg — not writing a recommended toml"
    echo "  hint: enable plugins.enabled to include \"$PLUGIN_NAME\" (see plugins/xbgst-stack/livepatch/docs/cli-config.toml)"
    return 0
  fi
  GROK_CFG="$cfg" PLUGIN_NAME="$PLUGIN_NAME" python3 - <<'PY'
import os, re, sys
path = os.environ["GROK_CFG"]
want = os.environ["PLUGIN_NAME"]
text = open(path, encoding="utf-8").read()
# Already enabled as a quoted string in an enabled list?
if re.search(r'(?m)^\s*"' + re.escape(want) + r'"\s*,?\s*$', text):
    print(f"✓ config already enables {want}")
    sys.exit(0)
# Find [plugins] ... enabled = [ ... ]
m = re.search(r'(?ms)^(\[plugins\][^\[]*?enabled\s*=\s*\[)(.*?)(\])', text)
if not m:
    print(f"FAIL: {path} has no [plugins] enabled = [...] to merge", file=sys.stderr)
    sys.exit(1)
body = m.group(2)
# Insert before closing bracket, preserving indentation style.
indent = "    "
for line in body.splitlines():
    if line.strip():
        indent = re.match(r'^(\s*)', line).group(1) or indent
        break
insertion = f'{indent}"{want}",\n'
if body.strip() and not body.endswith("\n"):
    body = body + "\n"
new_text = text[:m.start()] + m.group(1) + body + insertion + m.group(3) + text[m.end():]
open(path, "w", encoding="utf-8").write(new_text)
print(f"✓ merge-enabled {want} in {path}")
PY
}

main() {
  local from_tree="" install_timer=0
  local grok_home stack host_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage; exit 0 ;;
      --from-tree)
        [[ $# -ge 2 ]] || die "--from-tree requires a path"
        from_tree=$2
        shift 2
        ;;
      --install-timer|--rebind-timer) install_timer=1; shift ;;
      --*) die "unknown option: $1" ;;
      *) die "unexpected positional arg: $1" ;;
    esac
  done

  grok_home="${GROK_HOME:-$HOME/.grok}"
  export GROK_HOME="$grok_home"

  if [[ "$install_timer" -eq 1 ]]; then
    host_args+=(--install-timer)
  fi

  if [[ -n "$from_tree" ]]; then
    [[ -d "$from_tree" ]] || die "--from-tree not a directory: $from_tree"
    stack="$from_tree/plugins/xbgst-stack"
    [[ -f "$stack/plugin.json" ]] || die "missing $stack/plugin.json"
    local name
    name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$stack/plugin.json")
    [[ "$name" == "$PLUGIN_NAME" ]] || die "plugin.json name is '$name' (want $PLUGIN_NAME)"
    [[ -f "$stack/scripts/install-host.sh" ]] || die "missing $stack/scripts/install-host.sh"
    echo "→ --from-tree: $stack"
    bash "$stack/scripts/install-host.sh" "${host_args[@]+"${host_args[@]}"}"
  else
    command -v grok >/dev/null 2>&1 || die "grok not on PATH (need grok ≥1.0.5)"
    echo "→ marketplace add $MARKETPLACE_SPEC"
    grok plugin marketplace add "$MARKETPLACE_SPEC"
    echo "→ plugin install $PLUGIN_SPEC --trust"
    grok plugin install "$PLUGIN_SPEC" --trust
    stack=$(resolve_plugin_dir "$grok_home")
    [[ -f "$stack/scripts/install-host.sh" ]] || die "install-host.sh missing under $stack"
    echo "→ install-host from $stack"
    bash "$stack/scripts/install-host.sh" "${host_args[@]+"${host_args[@]}"}"
  fi

  merge_enable_plugin "$grok_home/config.toml"

  echo "✓ xbgst-stack orch install complete (GROK_HOME=$grok_home)"
  echo "  livepatch (optional, not applied): GROK_LIVEPATCH_FORCE=1 bash \"$stack/livepatch/scripts/check-and-patch.sh\""
  echo "  timer (optional): bash \"$stack/scripts/install-host.sh\" --install-timer"
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

XBGST_MARKETPLACE_NAME="veigapunk-xbgst"
XBGST_CORE_PLUGIN="xbgst-codex"
XBGST_MCP_PLUGIN="xbgst-delegation-ui"
XBGST_REMOTE_SOURCE="${XBGST_CODEX_SOURCE:-VeigaPunk/grok-marketplace}"
XBGST_REMOTE_REF="${XBGST_CODEX_REF:-main}"
XBGST_DS4CC_SOURCE="${XBGST_XASK_SOURCE:-https://github.com/VeigaPunk/ds4cc-marketplace.git}"
XBGST_DS4CC_REF="${XBGST_XASK_REF:-main}"
XBGST_LOCAL_TREE=""
XBGST_XASK_TREE=""
XBGST_INSTALL_XASK=true
XBGST_INSTALL_MCP=false
XBGST_DRY_RUN=false
XBGST_WORK_DIR=""
XBGST_BACKUP_TAG="$(date -u +%Y%m%dT%H%M%SZ)-$$"
XBGST_GODSPEED_SHA256="db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb"

usage() {
  cat <<'USAGE'
Usage: install-xbgst-codex.sh [OPTIONS]

Default (raw-local first):
  1. Install the skills-first xbgst-codex universal plugin.
  2. Build xbreed and install xbreed, xask, xask-models, the normalized model
     catalog, and dispatch templates into ~/.local.

No MCP server is installed by default. The installer never directly edits
~/.codex/config.toml, auth, profiles, model selection, reasoning effort, or
host concurrency.

Options:
  --from-tree PATH       Use a local grok-marketplace checkout.
  --xask-tree PATH       Use a local ds4cc-marketplace checkout or the
                         xbrd-gdsp-fknpft plugin directory itself.
  --ref GIT_REF          Grok marketplace ref (default: main).
  --xask-ref GIT_REF     DS4CC/xask ref (default: main).
  --plugin-only          Install only xbgst-codex; skip xask/xbreed.
  --without-xask         Alias for --plugin-only.
  --with-mcp             Also install the optional xbgst-delegation-ui
                         companion. This is the only flag that installs MCP.
  --dry-run              Validate local inputs and print the mutation plan.
  -h, --help             Show this help.

Environment overrides:
  XBGST_CODEX_SOURCE     Git marketplace source (default: VeigaPunk/grok-marketplace)
  XBGST_CODEX_REF        Git marketplace ref
  XBGST_XASK_SOURCE      DS4CC Git URL
  XBGST_XASK_REF         DS4CC/xask Git ref
USAGE
}

die() {
  printf 'xbgst-codex install: %s\n' "$*" >&2
  exit 1
}

note() {
  printf 'xbgst-codex install: %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

absolute_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "directory does not exist: $path"
  (cd "$path" && pwd -P)
}

cleanup() {
  if [[ -n "$XBGST_WORK_DIR" && -d "$XBGST_WORK_DIR" ]]; then
    rm -rf -- "$XBGST_WORK_DIR"
  fi
}
trap cleanup EXIT

while (($#)); do
  case "$1" in
    --from-tree)
      (($# >= 2)) || die "--from-tree requires a path"
      XBGST_LOCAL_TREE="$2"
      shift 2
      ;;
    --xask-tree)
      (($# >= 2)) || die "--xask-tree requires a path"
      XBGST_XASK_TREE="$2"
      shift 2
      ;;
    --ref)
      (($# >= 2)) || die "--ref requires a Git ref"
      XBGST_REMOTE_REF="$2"
      shift 2
      ;;
    --xask-ref)
      (($# >= 2)) || die "--xask-ref requires a Git ref"
      XBGST_DS4CC_REF="$2"
      shift 2
      ;;
    --plugin-only|--without-xask)
      XBGST_INSTALL_XASK=false
      shift
      ;;
    --with-mcp)
      XBGST_INSTALL_MCP=true
      shift
      ;;
    --dry-run)
      XBGST_DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${HOME:-}" && "$HOME" == /* ]] || die "HOME must be an absolute path"
[[ -z "$XBGST_XASK_TREE" || "$XBGST_INSTALL_XASK" == true ]] \
  || die "--xask-tree cannot be combined with --plugin-only/--without-xask"

require_command codex
require_command jq
if [[ "$XBGST_INSTALL_XASK" == true ]]; then
  require_command cargo
  require_command install
  require_command cmp
  require_command mktemp
  require_command sha256sum
  [[ -n "$XBGST_XASK_TREE" ]] || require_command git
fi
if [[ "$XBGST_INSTALL_MCP" == true ]]; then
  require_command node
  XBGST_NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
  [[ "$XBGST_NODE_MAJOR" =~ ^[0-9]+$ && "$XBGST_NODE_MAJOR" -ge 22 ]] \
    || die "--with-mcp requires Node.js 22 or newer"
fi

codex plugin marketplace list --json \
  | jq -e '.marketplaces | type == "array"' >/dev/null \
  || die "this Codex CLI does not expose a usable plugin marketplace"

if [[ -n "$XBGST_LOCAL_TREE" ]]; then
  XBGST_LOCAL_TREE="$(absolute_dir "$XBGST_LOCAL_TREE")"
  [[ -f "$XBGST_LOCAL_TREE/.agents/plugins/marketplace.json" ]] \
    || die "missing .agents/plugins/marketplace.json in $XBGST_LOCAL_TREE"
  jq -e --arg name "$XBGST_MARKETPLACE_NAME" '.name == $name and (.plugins | type == "array")' \
    "$XBGST_LOCAL_TREE/.agents/plugins/marketplace.json" >/dev/null \
    || die "local marketplace manifest is not $XBGST_MARKETPLACE_NAME"
  [[ -f "$XBGST_LOCAL_TREE/plugins/$XBGST_CORE_PLUGIN/.codex-plugin/plugin.json" ]] \
    || die "missing $XBGST_CORE_PLUGIN manifest in $XBGST_LOCAL_TREE"
  if [[ "$XBGST_INSTALL_MCP" == true ]]; then
    [[ -f "$XBGST_LOCAL_TREE/plugins/$XBGST_MCP_PLUGIN/.codex-plugin/plugin.json" ]] \
      || die "--with-mcp requested, but $XBGST_MCP_PLUGIN is absent from $XBGST_LOCAL_TREE"
  fi
fi

resolve_xask_plugin() {
  local tree="$1"
  if [[ -f "$tree/Cargo.toml" && -f "$tree/scripts/xask" ]]; then
    printf '%s\n' "$tree"
    return 0
  fi
  tree="$tree/marketplace/plugins/xbrd-gdsp-fknpft"
  if [[ -f "$tree/Cargo.toml" && -f "$tree/scripts/xask" ]]; then
    printf '%s\n' "$tree"
    return 0
  fi
  return 1
}

validate_xask_plugin() {
  local plugin_dir="$1"
  local required templates
  for required in \
    Cargo.toml \
    Cargo.lock \
    scripts/xask \
    scripts/xask-models \
    config/xask-models.json \
    skills/godspeed/SKILL.md \
    skills/godspeed/directive.md; do
    [[ -f "$plugin_dir/$required" ]] || die "xask source is missing $required: $plugin_dir"
  done
  bash -n "$plugin_dir/scripts/xask"
  bash -n "$plugin_dir/scripts/xask-models"
  jq -e '
    .schema_version == 1
    and (.providers | type == "array" and length > 0)
    and (.models | type == "array" and length > 0)
  ' "$plugin_dir/config/xask-models.json" >/dev/null \
    || die "xask model catalog failed structural validation"
  local directive_hash
  directive_hash="$(sha256sum -- "$plugin_dir/skills/godspeed/directive.md" | awk '{print $1}')"
  [[ "$directive_hash" == "$XBGST_GODSPEED_SHA256" ]] \
    || die "xask source carries a noncanonical Godspeed directive (sha256 $directive_hash)"
  shopt -s nullglob
  templates=("$plugin_dir"/templates/dispatch/*.md)
  shopt -u nullglob
  ((${#templates[@]} > 0)) || die "xask source has no dispatch templates"
}

XBGST_XASK_PLUGIN=""
if [[ "$XBGST_INSTALL_XASK" == true && -n "$XBGST_XASK_TREE" ]]; then
  XBGST_XASK_TREE="$(absolute_dir "$XBGST_XASK_TREE")"
  XBGST_XASK_PLUGIN="$(resolve_xask_plugin "$XBGST_XASK_TREE")" \
    || die "could not find marketplace/plugins/xbrd-gdsp-fknpft under $XBGST_XASK_TREE"
  validate_xask_plugin "$XBGST_XASK_PLUGIN"
fi

XBGST_MARKETPLACES_JSON="$(codex plugin marketplace list --json)"
marketplace_exists() {
  jq -e --arg name "$XBGST_MARKETPLACE_NAME" \
    '.marketplaces | any(.name == $name)' <<<"$XBGST_MARKETPLACES_JSON" >/dev/null
}

marketplace_value() {
  local expression="$1"
  jq -r --arg name "$XBGST_MARKETPLACE_NAME" \
    ".marketplaces[] | select(.name == \$name) | $expression // \"\"" \
    <<<"$XBGST_MARKETPLACES_JSON"
}

remote_marketplace_source_matches() {
  local source="$1"
  case "$source" in
    "$XBGST_REMOTE_SOURCE"|\
    "https://github.com/$XBGST_REMOTE_SOURCE"|\
    "https://github.com/$XBGST_REMOTE_SOURCE.git"|\
    "git@github.com:$XBGST_REMOTE_SOURCE.git") return 0 ;;
    *) return 1 ;;
  esac
}

XBGST_CURRENT_TYPE=""
XBGST_CURRENT_SOURCE=""
XBGST_CURRENT_ROOT=""
if marketplace_exists; then
  XBGST_CURRENT_TYPE="$(marketplace_value '.marketplaceSource.sourceType')"
  XBGST_CURRENT_SOURCE="$(marketplace_value '.marketplaceSource.source')"
  XBGST_CURRENT_ROOT="$(marketplace_value '.root')"
  if [[ -n "$XBGST_LOCAL_TREE" ]]; then
    [[ "$XBGST_CURRENT_TYPE" == "local" && "$XBGST_CURRENT_ROOT" == "$XBGST_LOCAL_TREE" ]] \
      || die "marketplace '$XBGST_MARKETPLACE_NAME' already points at '$XBGST_CURRENT_SOURCE'; remove it explicitly before switching sources"
  else
    [[ "$XBGST_CURRENT_TYPE" == "git" ]] \
      || die "marketplace '$XBGST_MARKETPLACE_NAME' is unexpectedly local at '$XBGST_CURRENT_ROOT'; use --from-tree for that exact tree or remove it explicitly"
    remote_marketplace_source_matches "$XBGST_CURRENT_SOURCE" \
      || die "marketplace '$XBGST_MARKETPLACE_NAME' points at unexpected Git source '$XBGST_CURRENT_SOURCE'; remove it explicitly before installing"
  fi
fi

if [[ "$XBGST_DRY_RUN" == true ]]; then
  note "dry run; no files, marketplaces, plugins, or settings will be changed"
  if marketplace_exists && [[ "$XBGST_CURRENT_TYPE" == "local" ]]; then
    note "would use configured local marketplace: $XBGST_CURRENT_ROOT"
  elif marketplace_exists; then
    note "would refresh configured marketplace: $XBGST_CURRENT_SOURCE"
  elif [[ -n "$XBGST_LOCAL_TREE" ]]; then
    note "would use local marketplace: $XBGST_LOCAL_TREE"
  else
    note "would add or refresh marketplace: $XBGST_REMOTE_SOURCE (ref $XBGST_REMOTE_REF)"
  fi
  note "would install skills-first plugin: $XBGST_CORE_PLUGIN@$XBGST_MARKETPLACE_NAME"
  if [[ "$XBGST_INSTALL_XASK" == true ]]; then
    if [[ -n "$XBGST_XASK_PLUGIN" ]]; then
      note "would build xask/xbreed from: $XBGST_XASK_PLUGIN"
    else
      note "would clone $XBGST_DS4CC_SOURCE (ref $XBGST_DS4CC_REF) into a temporary directory"
    fi
    note "would run: cargo build --locked --release"
    note "would atomically install runtime files under: $HOME/.local"
    note "would install the canonical Godspeed loadout under: $HOME/.config/xbreed/skills/godspeed"
  else
    note "would skip xask/xbreed (--plugin-only)"
  fi
  if [[ "$XBGST_INSTALL_MCP" == true ]]; then
    note "would opt in to MCP companion: $XBGST_MCP_PLUGIN@$XBGST_MARKETPLACE_NAME"
  else
    note "would not install an MCP server (default anti-bloat path)"
  fi
  exit 0
fi

XBGST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xbgst-codex-install.XXXXXX")"

if [[ "$XBGST_INSTALL_XASK" == true && -z "$XBGST_XASK_PLUGIN" ]]; then
  note "cloning DS4CC xask source at $XBGST_DS4CC_REF into a temporary directory"
  git clone --quiet --depth 1 --branch "$XBGST_DS4CC_REF" -- \
    "$XBGST_DS4CC_SOURCE" "$XBGST_WORK_DIR/ds4cc-marketplace" \
    || die "failed to clone DS4CC source/ref"
  XBGST_XASK_PLUGIN="$(resolve_xask_plugin "$XBGST_WORK_DIR/ds4cc-marketplace")" \
    || die "cloned DS4CC tree does not contain xbrd-gdsp-fknpft"
  validate_xask_plugin "$XBGST_XASK_PLUGIN"
fi

XBGST_STAGE_DIR="$XBGST_WORK_DIR/stage"
XBGST_TARGET_DIR="$XBGST_WORK_DIR/cargo-target"
if [[ "$XBGST_INSTALL_XASK" == true ]]; then
  mkdir -p \
    "$XBGST_STAGE_DIR/bin" \
    "$XBGST_STAGE_DIR/share/xbreed" \
    "$XBGST_STAGE_DIR/templates/dispatch" \
    "$XBGST_STAGE_DIR/config/xbreed/skills/godspeed"
  note "building xbreed with the locked dependency graph"
  (
    cd "$XBGST_XASK_PLUGIN"
    CARGO_TARGET_DIR="$XBGST_TARGET_DIR" cargo build --locked --release
  )
  [[ -x "$XBGST_TARGET_DIR/release/xbreed" ]] || die "cargo did not produce target/release/xbreed"
  install -m 0755 "$XBGST_TARGET_DIR/release/xbreed" "$XBGST_STAGE_DIR/bin/xbreed"
  install -m 0755 "$XBGST_XASK_PLUGIN/scripts/xask" "$XBGST_STAGE_DIR/bin/xask"
  install -m 0755 "$XBGST_XASK_PLUGIN/scripts/xask-models" "$XBGST_STAGE_DIR/bin/xask-models"
  install -m 0644 "$XBGST_XASK_PLUGIN/config/xask-models.json" \
    "$XBGST_STAGE_DIR/share/xbreed/xask-models.json"
  install -m 0644 "$XBGST_XASK_PLUGIN/skills/godspeed/SKILL.md" \
    "$XBGST_STAGE_DIR/config/xbreed/skills/godspeed/SKILL.md"
  install -m 0644 "$XBGST_XASK_PLUGIN/skills/godspeed/directive.md" \
    "$XBGST_STAGE_DIR/config/xbreed/skills/godspeed/directive.md"
  shopt -s nullglob
  XBGST_TEMPLATES=("$XBGST_XASK_PLUGIN"/templates/dispatch/*.md)
  shopt -u nullglob
  for template in "${XBGST_TEMPLATES[@]}"; do
    install -m 0644 "$template" "$XBGST_STAGE_DIR/templates/dispatch/$(basename "$template")"
  done
fi

if marketplace_exists; then
  if [[ -n "$XBGST_LOCAL_TREE" ]]; then
    note "using configured local marketplace: $XBGST_CURRENT_ROOT"
  else
    note "refreshing marketplace $XBGST_MARKETPLACE_NAME"
    codex plugin marketplace upgrade "$XBGST_MARKETPLACE_NAME" --json >/dev/null
  fi
else
  if [[ -n "$XBGST_LOCAL_TREE" ]]; then
    note "adding local marketplace: $XBGST_LOCAL_TREE"
    codex plugin marketplace add "$XBGST_LOCAL_TREE" --json >/dev/null
  else
    note "adding Git marketplace $XBGST_REMOTE_SOURCE at $XBGST_REMOTE_REF"
    codex plugin marketplace add "$XBGST_REMOTE_SOURCE" --ref "$XBGST_REMOTE_REF" --json >/dev/null
  fi
fi

install_and_verify_plugin() {
  local plugin="$1"
  note "installing $plugin@$XBGST_MARKETPLACE_NAME"
  codex plugin add "$plugin@$XBGST_MARKETPLACE_NAME" --json >/dev/null
  codex plugin list --json | jq -e \
    --arg plugin "$plugin" \
    --arg marketplace "$XBGST_MARKETPLACE_NAME" '
      .installed | any(
        .name == $plugin
        and .marketplaceName == $marketplace
        and .installed == true
        and .enabled == true
      )
    ' >/dev/null || die "Codex did not report $plugin as installed and enabled"
}

install_and_verify_plugin "$XBGST_CORE_PLUGIN"
if [[ "$XBGST_INSTALL_MCP" == true ]]; then
  install_and_verify_plugin "$XBGST_MCP_PLUGIN"
fi

XBGST_BACKUPS=()
atomic_install() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  local parent temporary backup
  parent="$(dirname "$destination")"
  mkdir -p "$parent"
  [[ ! -d "$destination" ]] || die "refusing to replace directory: $destination"

  if [[ -f "$destination" && ! -L "$destination" ]] && cmp -s "$source" "$destination"; then
    chmod "$mode" "$destination"
    note "unchanged: $destination"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup="$destination.xbgst-backup-$XBGST_BACKUP_TAG"
    [[ ! -e "$backup" && ! -L "$backup" ]] || die "backup already exists: $backup"
    cp -a -- "$destination" "$backup"
    XBGST_BACKUPS+=("$backup")
    note "backed up: $destination -> $backup"
  fi

  temporary="$(mktemp "$parent/.xbgst-install.XXXXXX")"
  if ! install -m "$mode" "$source" "$temporary"; then
    rm -f -- "$temporary"
    die "failed to stage $destination"
  fi
  if ! mv -f -- "$temporary" "$destination"; then
    rm -f -- "$temporary"
    die "failed to replace $destination"
  fi
  cmp -s "$source" "$destination" || die "post-install verification failed: $destination"
  note "installed: $destination"
}

if [[ "$XBGST_INSTALL_XASK" == true ]]; then
  XBGST_BIN_DIR="$HOME/.local/bin"
  XBGST_SHARE_DIR="$HOME/.local/share/xbreed"
  XBGST_TEMPLATE_DIR="$HOME/.local/templates/dispatch"
  XBGST_GODSPEED_DIR="$HOME/.config/xbreed/skills/godspeed"
  atomic_install "$XBGST_STAGE_DIR/bin/xbreed" "$XBGST_BIN_DIR/xbreed" 0755
  atomic_install "$XBGST_STAGE_DIR/bin/xask" "$XBGST_BIN_DIR/xask" 0755
  atomic_install "$XBGST_STAGE_DIR/bin/xask-models" "$XBGST_BIN_DIR/xask-models" 0755
  atomic_install "$XBGST_STAGE_DIR/share/xbreed/xask-models.json" \
    "$XBGST_SHARE_DIR/xask-models.json" 0644
  atomic_install "$XBGST_STAGE_DIR/config/xbreed/skills/godspeed/SKILL.md" \
    "$XBGST_GODSPEED_DIR/SKILL.md" 0644
  atomic_install "$XBGST_STAGE_DIR/config/xbreed/skills/godspeed/directive.md" \
    "$XBGST_GODSPEED_DIR/directive.md" 0644
  for template in "$XBGST_STAGE_DIR"/templates/dispatch/*.md; do
    atomic_install "$template" "$XBGST_TEMPLATE_DIR/$(basename "$template")" 0644
  done

  PATH="$XBGST_BIN_DIR:$PATH" \
    XASK_CATALOG_FILE="$XBGST_SHARE_DIR/xask-models.json" \
    "$XBGST_BIN_DIR/xask" catalog --json \
    | jq -e '.schema_version == 1 and .model_count > 0' >/dev/null \
    || die "installed xask catalog smoke test failed"
  XBGST_GODSPEED_SMOKE="$({
    PATH="$XBGST_BIN_DIR:$PATH" \
      XASK_CATALOG_FILE="$XBGST_SHARE_DIR/xask-models.json" \
      "$XBGST_BIN_DIR/xask" -d \
        --provider chatgpt \
        --model-id gpt-5.6-sol \
        --effort low \
        --service-tier default \
        --gs \
        -- "installer smoke | godspeed"
  })"
  [[ "$XBGST_GODSPEED_SMOKE" == *"You are a Godspeed-enabled subagent."* \
    && "$XBGST_GODSPEED_SMOKE" == *"installer smoke"* \
    && "$XBGST_GODSPEED_SMOKE" == *"| godspeed"* ]] \
    || die "installed xask Godspeed transport smoke test failed"
  [[ "$(grep -oF '| godspeed' <<<"$XBGST_GODSPEED_SMOKE" | wc -l)" -eq 1 ]] \
    || die "installed xask Godspeed transport did not end with exactly one marker"
  [[ "$(sha256sum -- "$XBGST_GODSPEED_DIR/directive.md" | awk '{print $1}')" \
    == "$XBGST_GODSPEED_SHA256" ]] \
    || die "installed Godspeed directive hash mismatch"
  "$XBGST_BIN_DIR/xbreed" ask --help >/dev/null \
    || die "installed xbreed smoke test failed"
fi

printf '\nInstalled and verified:\n'
printf '  - %s@%s (skills-first; no MCP)\n' "$XBGST_CORE_PLUGIN" "$XBGST_MARKETPLACE_NAME"
if [[ "$XBGST_INSTALL_XASK" == true ]]; then
  printf '  - xbreed + xask + model catalog + dispatch templates under %s/.local\n' "$HOME"
  printf '  - canonical Godspeed loadout under %s/.config/xbreed/skills/godspeed\n' "$HOME"
fi
if [[ "$XBGST_INSTALL_MCP" == true ]]; then
  printf '  - %s@%s (explicit MCP opt-in)\n' "$XBGST_MCP_PLUGIN" "$XBGST_MARKETPLACE_NAME"
else
  printf '  - MCP bridge: not installed (default anti-bloat path)\n'
fi
if ((${#XBGST_BACKUPS[@]} > 0)); then
  printf 'Backups preserved:\n'
  printf '  - %s\n' "${XBGST_BACKUPS[@]}"
fi
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) printf 'Add %s/.local/bin to PATH to invoke xask and xbreed directly.\n' "$HOME" ;;
esac
printf 'No Codex config, auth, profile, model, effort, or concurrency setting was rewritten directly.\n'
printf 'Start a new Codex task so newly installed skills are loaded.\n'

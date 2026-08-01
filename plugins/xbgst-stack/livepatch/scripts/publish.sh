#!/usr/bin/env bash
# Standalone livepatch-repo publisher — NOT for VeigaPunk/grok-marketplace.
# When this tree is nested under xbgst-stack (marketplace), refuse to run.
#
#   export GH_TOKEN=ghp_...   # or github_pat_...
#   ./scripts/publish.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Refuse when shipped inside grok-marketplace / xbgst-stack
if [[ -f "$ROOT/../../plugin.json" ]] || [[ "$ROOT" == *"/plugins/xbgst-stack/livepatch"* ]] || [[ "$ROOT" == *"/grok-marketplace/"* ]]; then
  echo "REFUSE: publish.sh under marketplace/xbgst-stack targets VeigaPunk/grok-build-livepatch."
  echo "To ship the marketplace, from the repo root: commit on main, then git push -u origin main"
  echo "and move annotated tag grok-stable. Do not use this script."
  exit 2
fi

usage() {
  cat <<'EOF'
Usage: publish.sh [--help|-h]

Create VeigaPunk/grok-build-livepatch (public) if missing, then git push -u origin main over SSH.

Requires GH_TOKEN or existing gh login for repo create. Push uses origin SSH URL.
See docs/PUBLISH.md for exact PAT steps when gh auth fails.
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

if [[ -z "${GH_TOKEN:-}" ]]; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "GH_TOKEN not set and gh is not logged in."
    echo "See docs/PUBLISH.md for PAT steps, or:"
    echo "  export GH_TOKEN=\$(op read 'op://Personal/GitHub CLI/credential')"
    echo "  $0"
    exit 1
  fi
fi

gh auth status || true

if ! gh repo view VeigaPunk/grok-build-livepatch >/dev/null 2>&1; then
  gh repo create VeigaPunk/grok-build-livepatch \
    --public \
    --description "Livepatch Grok Build CLI: hard-ban general-purpose/explore; 6h upstream re-apply"
fi

# Prefer SSH remote for push (works when gh token has create but agent has push keys)
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin git@github.com:VeigaPunk/grok-build-livepatch.git
else
  git remote add origin git@github.com:VeigaPunk/grok-build-livepatch.git
fi

git push -u origin main
gh repo view VeigaPunk/grok-build-livepatch 2>/dev/null || true
echo "Public: https://github.com/VeigaPunk/grok-build-livepatch"

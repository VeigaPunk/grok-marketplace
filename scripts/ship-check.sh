#!/usr/bin/env bash
# Pre-ship checklist for VeigaPunk/grok-marketplace (local-first → main).
# Does not commit or push. Exit 0 only if shippable.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "→ ship-check: $ROOT"
./scripts/smoke-gates.sh

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" != "main" ]]; then
  echo "FAIL: not on main (on $branch)"
  exit 1
fi
echo "OK  on main"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "FAIL: working tree dirty — commit project files first"
  git status -sb
  exit 1
fi
echo "OK  working tree clean"

ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [[ "${behind:-0}" -gt 0 ]]; then
  echo "FAIL: main is behind origin/main by $behind — pull --ff-only"
  exit 1
fi
echo "OK  not behind origin/main (ahead=$ahead)"

head=$(git rev-parse HEAD)
if git rev-parse grok-stable^{} >/dev/null 2>&1; then
  tag=$(git rev-parse grok-stable^{})
  if [[ "$head" == "$tag" ]]; then
    echo "OK  grok-stable peels to HEAD"
  else
    echo "WARN grok-stable peels to ${tag:0:7} ≠ HEAD ${head:0:7} — move tag after push:"
    echo "     git tag -d grok-stable; git tag -a grok-stable -m 'Grok-stable' HEAD"
    echo "     git push --force origin refs/tags/grok-stable"
  fi
else
  echo "WARN no local grok-stable tag"
fi

echo "→ ship-check PASSED (push main if ahead>0; retag grok-stable if WARN above)"

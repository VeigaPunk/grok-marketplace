#!/usr/bin/env bash
# M04/M05 contract gate — DSH pin integrity + hardened worker profile composition.
# Axes: contract-integrity | role-enum-preservation | event-normalization-fidelity.
# Aggregates ALL violations per run (no fail-fast) so one transcript shows every axis.
# Skip-noticed paths: absent reference install, absent git history. All else hard-fails.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DSH="$ROOT/integrations/dsh"
PIN="$DSH/pin.env"
PATCH="$DSH/profiles/xbgst-worker/cordis.patch.yml"
DOCS="$DSH/docs"
EXPECTED_HARDENED="168e12150989b15399e8a2cf356e541573b7b7b7a7d17ccdc222b74effb2bc20"
EXPECTED_BASELINE="a0a0e9f380872097cb7f8b7356f36433a2afeb8de5044a9e63d4ed47b4bee9f5"
EXPECTED_BUNDLES="@deepseek-ai/dsh-base,@deepseek-ai/dsh-headless"
REF_ROOT="$HOME/.cache/xbgst-dsh/smoke.aWXt"

ASSERTIONS=0
SKIPS=0
VIOLATIONS=0
ok() { ASSERTIONS=$((ASSERTIONS + 1)); printf 'ok %s - %s\n' "$ASSERTIONS" "$1"; }
bad() { VIOLATIONS=$((VIOLATIONS + 1)); printf 'FAIL: %s\n' "$*" >&2; }
skip_note() { SKIPS=$((SKIPS + 1)); printf 'SKIP: %s\n' "$1"; }
need_file() { [[ -s "$1" ]] || bad "missing/empty file: $1"; }
need_grep() { grep -F -q -- "$2" "$1" || bad "$1 missing '$2'"; }

# Self-host the node runtime through fnm when PATH lacks it (recompute path).
if ! command -v node >/dev/null 2>&1 && command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell bash)"
fi

# ---- A. Pin manifest (parsed, never sourced) ----
[[ -s "$PIN" ]] || { printf 'FAIL: fatal — missing pin manifest: %s\n' "$PIN" >&2; exit 1; }
VALUES="$(grep -Ev '^[[:space:]]*#' "$PIN")"
pin() { grep -E "^${1}=" <<<"$VALUES" | head -n1 | cut -d= -f2- || true; }

if [[ "$(pin DSH_VERSION)" == "0.1.0-rc.8" ]]; then
  ok "DSH_VERSION pinned exact 0.1.0-rc.8"
else
  bad "DSH_VERSION must be exactly 0.1.0-rc.8 (got '$(pin DSH_VERSION)')"
fi

if [[ "$(pin DSH_TARBALL_SHA512)" =~ ^[0-9a-f]{128}$ ]]; then
  ok "tarball sha512 well-formed"
else
  bad "DSH_TARBALL_SHA512 not 128-hex"
fi

if grep -q '^sha512-' <<<"$(pin DSH_INTEGRITY)"; then
  ok "registry integrity present (sha512-)"
else
  bad "DSH_INTEGRITY lacks sha512- prefix"
fi

if [[ "$(pin DSH_DUMP_HARDENED_SHA256)" == "$EXPECTED_HARDENED" ]]; then
  ok "hardened dump hash == contract constant"
else
  bad "DSH_DUMP_HARDENED_SHA256 drifted from contract constant"
fi

if [[ "$(pin DSH_DUMP_BASELINE_SHA256)" == "$EXPECTED_BASELINE" ]]; then
  ok "baseline dump hash matches M02 record"
else
  bad "DSH_DUMP_BASELINE_SHA256 drifted from recorded baseline"
fi

if [[ "$(pin DSH_WORKER_PROFILE)" == "xbgst-worker" ]]; then
  ok "worker profile name pinned"
else
  bad "DSH_WORKER_PROFILE not xbgst-worker"
fi

if [[ "$(pin DSH_BUNDLES)" == "$EXPECTED_BUNDLES" ]]; then
  ok "bundles row matches canonical @deepseek-ai/dsh-base,@deepseek-ai/dsh-headless"
else
  bad "DSH_BUNDLES row drifted (got '$(pin DSH_BUNDLES)')"
fi

# Floating refs forbidden on non-comment lines (the warning comment itself names @latest).
FLOATING=0
grep -Eq '@latest' <<<"$VALUES" && FLOATING=1
grep -E '@(latest|^[^=]*1\.1\.)' <<<"$VALUES" >/dev/null 2>&1 && FLOATING=1
grep -Eq '1\.1\.' <<<"$VALUES" && FLOATING=1
grep -Eq '(^|[[:space:]@])[~=>^]' <<<"$VALUES" && FLOATING=1
grep -Fq 'deepseek-harness' <<<"$VALUES" && FLOATING=1
if [[ $FLOATING -eq 0 ]]; then
  ok "no floating refs (@latest | 1.1.x | range ops | deepseek-harness trap)"
else
  bad "floating ref detected in pin.env values (@latest | 1.1.x | range ops | deepseek-harness)"
fi

# ---- B. Hardened patch layer ----
[[ -s "$PATCH" ]] || { printf 'FAIL: fatal — missing hardened patch layer: %s\n' "$PATCH" >&2; exit 1; }
ok "cordis.patch.yml present"

DISABLED_IDS=(goal goal-round-driver command-goal tool-goal plan-mode subagent
  subagent-spawn-in-process subagent-fork-in-process tool-subagent-control
  tool-subagent-list-agents tool-subagent tool-subagent-fork tool-subagent-report
  workflow-worker-thread tool-workflow jobs tool-jobs user-questions
  session-title-llm web web-search-deepseek tool-web)
MISSING_IDS=()
for id in "${DISABLED_IDS[@]}"; do
  flag="$(awk -v id="$id" '
    $0 == "- id: " id { found = 1; next }
    found && /^- id:/ { exit }
    found && /disabled:/ { print; exit }
  ' "$PATCH")"
  [[ "$flag" == *"disabled: true"* ]] || MISSING_IDS+=("$id")
done
if [[ ${#MISSING_IDS[@]} -eq 0 ]]; then
  ok "all ${#DISABLED_IDS[@]} second-orchestrator/network ids disabled:true (exact-match blocks)"
else
  bad "${#MISSING_IDS[@]} patch ids not disabled:true: ${MISSING_IDS[*]}"
fi

sb_block="$(awk '/^- id: sandbox-policy$/{found=1;next} found&&/^- id:/{exit} found{print}' "$PATCH")"
if grep -q 'mode: read-only' <<<"$sb_block"; then
  ok "sandbox-policy mode read-only (fail-safe default retained)"
else
  bad "sandbox-policy must pin mode: read-only"
fi

adm_block="$(awk '/^- id: agent-default-model$/{found=1;next} found&&/^- id:/{exit} found{print}' "$PATCH")"
ADM_OK=1
grep -q 'provider: grok-high' <<<"$adm_block" || ADM_OK=0
grep -q 'model: grok-4.5' <<<"$adm_block" || ADM_OK=0
if [[ $ADM_OK -eq 1 ]]; then
  ok "agent-default-model -> provider grok-high, model grok-4.5"
else
  bad "agent-default-model must be provider grok-high + model grok-4.5"
fi

llm_block="$(awk '/^- id: llm-pi-ai$/{found=1;next} found&&/^- id:/{exit} found{print}' "$PATCH")"
LLM_MISSING=()
for frag in 'grok-high:' 'grok-fast-low:' 'apiKeyEnv: XAI_API_KEY' 'reasoning: high' 'reasoning: low'; do
  grep -qF "$frag" <<<"$llm_block" || LLM_MISSING+=("$frag")
done
if [[ "$(grep -c 'id: grok-4.5' <<<"$llm_block")" -lt 2 ]]; then
  LLM_MISSING+=("models narrowed to grok-4.5 on both routes")
fi
if [[ ${#LLM_MISSING[@]} -eq 0 ]]; then
  ok "llm-pi-ai: grok-high(high)+grok-fast-low(low), apiKeyEnv XAI_API_KEY, catalogs -> grok-4.5"
else
  bad "llm-pi-ai violations: ${LLM_MISSING[*]}"
fi

# ---- C. Docs ----
need_file "$DOCS/dsh-pinning.md" && ok "docs/dsh-pinning.md present"
need_file "$DOCS/dsh-events.md" && ok "docs/dsh-events.md present (M05 normalization contract)"
BUNDDOC_OK=1
grep -Fq '@deepseek-ai/dsh-base' "$DOCS/dsh-pinning.md" || BUNDDOC_OK=0
grep -Fq '@deepseek-ai/dsh-headless' "$DOCS/dsh-pinning.md" || BUNDDOC_OK=0
if [[ $BUNDDOC_OK -eq 1 ]]; then
  ok "pinning doc references both pinned bundles"
else
  bad "docs/dsh-pinning.md missing a pinned bundle reference"
fi

# ---- D. Recompute path: skip-if-absent, hard-fail-on-drift ----
REF_DSH="$REF_ROOT/node_modules/.bin/dsh"
if [[ -x "$REF_DSH" ]]; then
  if CFG_SHA="$(DSH_HOME="$REF_ROOT/.dsh-home" "$REF_DSH" --profile xbgst-worker --dump-config \
      | sha256sum | cut -d' ' -f1)"; then
    if [[ "$CFG_SHA" == "$EXPECTED_HARDENED" ]]; then
      ok "recomputed dump-config sha256 == pinned hardened composition"
    else
      bad "recomputed composition sha256 $CFG_SHA != pinned $EXPECTED_HARDENED"
    fi
  else
    bad "recompute invocation failed ($REF_DSH --dump-config)"
  fi
else
  skip_note "reference install absent ($REF_DSH) — recompute deferred; pinned-hash equality enforced above"
fi

# ---- E. Role-enum preservation ----
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # diff-vs-HEAD plus porcelain (catches untracked); aggregates as violation, no fail-fast.
  if git -C "$ROOT" diff --quiet HEAD -- agents/ \
     && [[ -z "$(git -C "$ROOT" status --porcelain -- agents/)" ]]; then
    ok "role enum intact: agents/ clean vs HEAD (diff + untracked)"
  else
    DRIFT="$(git -C "$ROOT" diff --name-only HEAD -- agents/ | tr '\n' ' ')"
    UNTRACKED="$(git -C "$ROOT" status --porcelain -- agents/ | grep '^??' | tr '\n' ' ' || true)"
    bad "role enum: agents/*.md are immutable — drift vs HEAD [${DRIFT}] untracked[${UNTRACKED}]"
  fi
else
  skip_note "git history absent (not a repo) — agents/ immutability diff bypassed"
fi

AGENTS_LEAK="$(find "$ROOT/integrations" -type d -name agents 2>/dev/null
  find "$ROOT/integrations" -type f -name '*.agent.md' 2>/dev/null)"
if [[ -z "$AGENTS_LEAK" ]]; then
  ok "integrations/ tree carries zero new agent definitions"
else
  bad "agent definitions smuggled into integrations/: $AGENTS_LEAK"
fi

# ---- F. Console wrapper contract (M03 hardened; comment-stripped matching) ----
# Wave-A tolerance: sibling executor lands scripts/dsh-web.sh + tests/test-dsh-web.sh
# in parallel — existence-dependent checks degrade to SKIP (never masked RED).
WEB="$ROOT/scripts/dsh-web.sh"
WEB_TEST="$ROOT/tests/test-dsh-web.sh"
L2="$ROOT/scripts/dsh-l2.sh"
# Full-line comments only: inline `#...` tails are data (pin.env warning comments name
# @latest on their own line; wrapper code must never hide flags behind stripped tails).
strip_comments() { grep -Ev '^[[:space:]]*#' "$1"; }

# F1: wrapper exists + executable bit.
if [[ ! -e "$WEB" ]]; then
  skip_note "F-SKIP-no-wrapper: scripts/dsh-web.sh absent (parallel Wave A landing)"
elif [[ -x "$WEB" ]]; then
  ok "F1 scripts/dsh-web.sh exists and is executable"
else
  bad "F1 scripts/dsh-web.sh present but not executable"
fi

# F2/F3: wrapper is pin.env-SSoT driven (comment-stripped, full-line filter).
if [[ ! -e "$WEB" ]]; then
  skip_note "F-SKIP-no-wrapper: wrapper constant checks deferred (scripts/dsh-web.sh absent)"
else
  WEB_STRIPPED="$(strip_comments "$WEB")"
  F2_MISSING=()
  for frag in 'integrations/dsh/pin.env' '--host 127.0.0.1' '$DSH_CONSOLE_PORT'; do
    grep -qF -- "$frag" <<<"$WEB_STRIPPED" || F2_MISSING+=("$frag")
  done
  # The exec line must reference the pinned port variable, not a hardcoded literal.
  grep -Eq 'web[[:space:]].*\$DSH_CONSOLE_PORT' <<<"$WEB_STRIPPED" \
    || F2_MISSING+=("exec line: dsh web ... --port \"\$DSH_CONSOLE_PORT\"")
  grep -qE '^DSH_CONSOLE_PORT=8787$' "$PIN" || F2_MISSING+=("pin.env DSH_CONSOLE_PORT=8787")
  if [[ ${#F2_MISSING[@]} -eq 0 ]]; then
    ok "F2 wrapper sources pin.env, execs dsh web --host 127.0.0.1 --port \$DSH_CONSOLE_PORT; pin DSH_CONSOLE_PORT=8787"
  else
    bad "F2 wrapper/pin contract violations: ${F2_MISSING[*]}"
  fi
  F3_OK=1
  grep -qF 'DSH_HOME="$DSH_CONSOLE_HOME"' <<<"$WEB_STRIPPED" || F3_OK=0
  grep -qE '^DSH_CONSOLE_HOME=/home/vgpnk/.cache/xbgst-dsh/console-home$' "$PIN" || F3_OK=0
  if [[ $F3_OK -eq 1 ]]; then
    ok "F3 wrapper exports DSH_HOME=\"\$DSH_CONSOLE_HOME\"; pin.env console-home line exact"
  else
    bad "F3 wrapper must set DSH_HOME=\"\$DSH_CONSOLE_HOME\" and pin.env must pin DSH_CONSOLE_HOME=/home/vgpnk/.cache/xbgst-dsh/console-home"
  fi
fi

# F4: zero --trusted-host anywhere under scripts/ (loopback auto-trusted upstream).
# Conservative direction: the full-line filter keeps inline `# --trusted-host` tails
# visible to this grep — a commented-out occurrence still trips F4. Deliberate.
TRUSTED_HITS=0
for f in "$ROOT"/scripts/*.sh; do
  [[ -e "$f" ]] || continue
  if strip_comments "$f" | grep -qF -- '--trusted-host'; then
    TRUSTED_HITS=1
    bad "F4 --trusted-host found in $f (loopback is auto-trusted; flag forbidden)"
  fi
done
if [[ $TRUSTED_HITS -eq 0 ]]; then
  ok "F4 zero --trusted-host occurrences under scripts/ (comment-stripped)"
fi

# F5: wrapper test present.
if [[ -s "$WEB_TEST" ]]; then
  ok "F5 tests/test-dsh-web.sh present"
else
  skip_note "F-SKIP-no-wrapper-test: tests/test-dsh-web.sh absent (parallel Wave A landing)"
fi

# F6: runs-prefix allowlist in dsh-l2.sh (SKIP until M01 amendment lands there).
if [[ -e "$L2" ]] \
   && { strip_comments "$L2" | grep -qF 'DSH_RUNS_ROOT' \
        || strip_comments "$L2" | grep -qF 'runs/'; }; then
  ok "F6 dsh-l2.sh carries runs-prefix allowlist logic (DSH_RUNS_ROOT / runs/ segment)"
else
  skip_note "F-SKIP-no-runs-allowlist: dsh-l2.sh runs-prefix allowlist not yet landed"
fi

# ---- Verdict ----
if [[ $VIOLATIONS -eq 0 ]]; then
  echo "PASS: dsh contract pin intact (${ASSERTIONS} assertions, ${SKIPS} skips)"
else
  printf 'CONTRACT GATE RED: %d violation(s), %d assertions ok, %d skips\n' \
    "$VIOLATIONS" "$ASSERTIONS" "$SKIPS" >&2
  exit 1
fi

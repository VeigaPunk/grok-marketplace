#!/usr/bin/env bash
# Thin L2-loop adapter: gx-* specialist → prime-agent (xAI only). Never exec pi.
set -euo pipefail

# Pin the fnm default alias (where npm -g landed). Do not sort -V latest — that
# can hide prime-agent. Do not prepend ~/.local/bin (host pi lives there).
FNM_DEFAULT_BIN="${HOME}/.local/share/fnm/aliases/default/bin"
if [[ -x "${FNM_DEFAULT_BIN}/prime-agent" ]]; then
  export PATH="${FNM_DEFAULT_BIN}:${PATH}"
fi

mkdir -p "${HOME}/.xbgst/prime-agent/sessions" "${HOME}/.xbgst/prime-agent/evidence"
export PRIME_AGENT_SESSION_DIR="${PRIME_AGENT_SESSION_DIR:-$HOME/.xbgst/prime-agent/sessions}"
export PRIME_AGENT_TELEMETRY=0
export DO_NOT_TRACK=1
export PI_SKIP_VERSION_CHECK=1

if [[ -z "${XAI_API_KEY:-}" ]]; then
  echo "PRIME_TICK_BLOCKED_NO_XAI"
  echo "BLOCKED: XAI_API_KEY missing — escalate E5" >&2
  exit 2
fi

CWD="$(pwd -P 2>/dev/null || pwd)"
case "${CWD}" in
  /tmp/xbgst-prime-*) ;;
  *)
    echo "PRIME_TICK_BLOCKED_CWD"
    echo "BLOCKED: cwd must be disposable /tmp/xbgst-prime-* (not a sandbox; never xbgst main)" >&2
    exit 2
    ;;
esac

# auth.json beats env / --provider. Presence-check only; never print the body.
AUTH_JSON="${PRIME_AGENT_CODING_AGENT_DIR:-$HOME/.prime/agent}/auth.json"
if [[ -f "${AUTH_JSON}" ]] && grep -Eiq 'anthropic|openai|github' "${AUTH_JSON}"; then
  echo "PRIME_TICK_BLOCKED_AUTH"
  echo "BLOCKED: non-xAI credentials in auth.json" >&2
  exit 2
fi

prev=""
for arg in "$@"; do
  al="${arg,,}"
  case "${al}" in
    /login|/logout|/login*|login)
      echo "PRIME_TICK_BLOCKED_LOGIN"
      echo "BLOCKED: /login is forbidden" >&2
      exit 2
      ;;
    --provider=*)
      if [[ "${al#--provider=}" != "xai" ]]; then
        echo "PRIME_TICK_BLOCKED_PROVIDER"
        echo "BLOCKED: provider pin is xai" >&2
        exit 2
      fi
      ;;
    --model=*)
      mv="${al#--model=}"
      if [[ "${mv}" == */* && "${mv}" != xai/* ]]; then
        echo "PRIME_TICK_BLOCKED_PROVIDER"
        echo "BLOCKED: model provider prefix must be xai" >&2
        exit 2
      fi
      ;;
    *general-purpose*)
      echo "PRIME_TICK_BLOCKED_BANNED_TYPE"
      echo "BLOCKED: never spawn general-purpose" >&2
      exit 2
      ;;
    explore|/explore|subagent_type=explore|subagent_type:explore)
      echo "PRIME_TICK_BLOCKED_BANNED_TYPE"
      echo "BLOCKED: never spawn explore" >&2
      exit 2
      ;;
  esac
  if [[ "${prev}" == "--provider" && "${al}" != "xai" ]]; then
    echo "PRIME_TICK_BLOCKED_PROVIDER"
    echo "BLOCKED: provider pin is xai" >&2
    exit 2
  fi
  if [[ "${prev}" == "--model" && "${al}" == */* && "${al}" != xai/* ]]; then
    echo "PRIME_TICK_BLOCKED_PROVIDER"
    echo "BLOCKED: model provider prefix must be xai" >&2
    exit 2
  fi
  prev="${al}"
done
unset prev arg al mv

PRIME_AGENT_BIN="$(command -v prime-agent || true)"
if [[ -z "${PRIME_AGENT_BIN}" ]]; then
  echo "BLOCKED: prime-agent not on PATH (expected user-level install ~0.7.4)" >&2
  exit 1
fi
if [[ "$(basename "${PRIME_AGENT_BIN}")" != "prime-agent" ]]; then
  echo "BLOCKED: refused to exec $(basename "${PRIME_AGENT_BIN}"); need prime-agent, never pi" >&2
  exit 1
fi

# Parent is always gx-*; never spawn general-purpose / explore; no grok spawn from kernel.
BAN_PROMPT='BANNED: never spawn general-purpose or explore. Never /login. Do not spawn grok subagents. Parent is gx-* specialist; rlm() children are PrimeAgent sessions only. This process is not the L1 judge.'

ARGS=(--provider xai --append-system-prompt "${BAN_PROMPT}" --session-dir "${PRIME_AGENT_SESSION_DIR}")
if "${PRIME_AGENT_BIN}" --help 2>&1 | grep -q -- '--no-extensions'; then
  ARGS+=(--no-extensions)
fi
if "${PRIME_AGENT_BIN}" --help 2>&1 | grep -q -- '--no-context-files'; then
  ARGS+=(--no-context-files)
fi

exec "${PRIME_AGENT_BIN}" "${ARGS[@]}" "$@"

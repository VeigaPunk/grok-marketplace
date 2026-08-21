---
description: Optional L2-loop via prime-agent wrapper (xAI only; fail-closed without XAI_API_KEY).
---

# /xbgst-primeagent

Load skill **xbgst-primeagent**. For long-running specialist work, exec the wrapper:

```bash
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
STACK=$(ls -d "$GROK_HOME"/installed-plugins/xbgst-stack-* 2>/dev/null | head -1)
if [[ -z "$STACK" || ! -x "$STACK/scripts/prime-agent-l2.sh" ]]; then
  CAND="$HOME/Projects/xbgst/grok-marketplace/plugins/xbgst-stack"
  if [[ -x "$CAND/scripts/prime-agent-l2.sh" ]]; then
    STACK="$CAND"
  fi
fi
bash "$STACK/scripts/prime-agent-l2.sh" "$@"
```

If wrapper exits **2**:
- `PRIME_TICK_BLOCKED_NO_XAI` → **Status: blocked E5** (no live tick; do not `/login`)
- `PRIME_TICK_BLOCKED_CWD` → re-run from disposable `/tmp/xbgst-prime-*`
- `PRIME_TICK_BLOCKED_LOGIN` / `_PROVIDER` / `_AUTH` / `_BANNED_TYPE` → fail-closed; do not bypass

Hard rules: xAI only; never `/login`; **BANNED:** never spawn `general-purpose` / `explore`; never exec host `pi`; not the L1 judge. Parent is always a `gx-*` specialist who shells the wrapper — L1 does not become PrimeAgent.

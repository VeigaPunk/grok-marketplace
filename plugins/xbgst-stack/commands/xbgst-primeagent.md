---
description: Optional OpenAI-backed PrimeAgent L2-loop for attachable intermodel work; never the xbgst judge.
---

# /xbgst-primeagent

Load skill **xbgst-primeagent**. L1 `xbgst` must first assign a named `gx-*` route owner and provide this complete envelope:

```yaml
route_id: <stable id>
parent: <named gx-* route owner>
task: <one bounded objective>
scope: <allowed paths and systems>
allowed_actions: <tools, messaging, and explicit child-fan-out permission or "none">
return: <evidence/artifact schema and recipient>
stop: <done condition, budget/cap, and abort conditions>
```

For a user who already configured OpenAI ChatGPT/Codex OAuth in PrimeAgent, start the optional L2-loop with the user-level binary:

```bash
SESSION_DIR="${PRIME_AGENT_SESSION_DIR:-$HOME/.xbgst/prime-agent/sessions}"
ROUTE_CWD="${ROUTE_CWD:?set ROUTE_CWD to the route-scoped disposable directory or isolated worktree}"
BOUNDARY='L2-loop only. L1 xbgst is the sole scheduler, Pareto judge, APPROVED authority, integrator, and shipper. Follow the supplied route envelope. Return evidence, not decisions. No child fan-out unless allowed. Never act as xbrd-selector or sekhmet. Never spawn general-purpose or explore. Never invoke codex-titanium.'
mkdir -p "$SESSION_DIR"
export PRIME_AGENT_TELEMETRY=0 DO_NOT_TRACK=1 PI_SKIP_VERSION_CHECK=1
prime-agent --provider openai-codex --cwd "$ROUTE_CWD" --session-dir "$SESSION_DIR" \
  --append-system-prompt "$BOUNDARY" -- "$@"
```

Provider credentials and OAuth setup stay outside this command. Never automate `/login`. If `prime-agent` or existing ChatGPT/Codex OAuth (`openai-codex`) is unavailable, report the route unavailable and continue through the named native `gx-*` path; do not block L1 or promote L2.

Set `ROUTE_CWD` to a path named by the envelope before invoking the block. Use disposable `/tmp/xbgst-prime-*` for the first probe and an isolated worktree or disjoint path for authorized writing; never point a writing route at the shared xbgst `main` checkout.

For an authorized route, use standard attachable messaging mechanics such as `prime-agent list --json`, `prime-agent send <agent> <message>`, and `prime-agent attach <agent>`. The route owner remains responsible for the exact scope, return, and stop contract.

The existing `scripts/prime-agent-l2.sh` is an optional **legacy xAI-only** compatibility path. Its exit-2 guards (`PRIME_TICK_BLOCKED_NO_XAI`, `_CWD`, `_LOGIN`, `_PROVIDER`, `_AUTH`, `_BANNED_TYPE`) remain fail-closed and must not be bypassed.

Hard rules: PrimeAgent is L2-loop only, never L1 judge, L2-select, or L3. Never spawn `general-purpose` / `explore`; never exec host `pi`; never invoke `codex-titanium`; never add PrimeAgent to host-orch inventory or required installation.

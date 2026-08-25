---
description: Optional xbgst-cursor L2-fsd subprocess for cursor-agent write+shell FSD; never the xbgst judge. Surface stays trigger/forward.
---

# /xbgst-cursor

Load the hangar **xbgst-cursor L2-fsd** route. L1 `xbgst` must first assign a named `gx-*` route owner and document this complete envelope (the wrapper does not inject it):

```yaml
route_id: cursor-l2-fsd-<slug>
parent: <named gx-* route owner>
task: <one bounded objective>
scope: <allowed paths; default workspace = /home/vgpnk/Projects/xbgst/xbgst-cursor>
allowed_actions: cursor-agent -p (no --mode ask); named agents/ roster; no --force/--yolo; no argv0=agent; no auto; no Claude; child fan-out only as cx-* under ceiling 64; no host Pareto/APPROVED/ship
return: evidence artifact; recipient = seated L1
stop: saturation or labeled 6-round halt or envelope abort
```

Envelope documented not executed. `scripts/cursor-agent-l2.sh` prints argv by default and never runs the envelope. Exec only if `XBGST_CURSOR_EXEC=1`.

Catalog pin is **cursor-agent `--model <cli-id>`**, not `xask --model-id`. Default `cursor-grok-4.6-high-fast`. Override with `--model` or `XBGST_CURSOR_MODEL`. xask `--provider cursor --model-id` is consult only (`-p --mode ask --trust`).

```bash
env -u XBGST_CURSOR_EXEC bash scripts/cursor-agent-l2.sh --print -- "$TASK"
env -u XBGST_CURSOR_EXEC bash scripts/cursor-agent-l2.sh --print --model kimi-k3-max -- "$TASK"
```

That forwards to `/home/vgpnk/Projects/xbgst/xbgst-cursor/bin/xbgst-cursor-run.sh` with `--workspace /home/vgpnk/Projects/xbgst/xbgst-cursor`. Caller prepends byte-exact `godspeed-core/directive.md` and ends the prompt exactly once with `| godspeed`.

Refuse `--mode ask` (PATH xask consult), `--force`/`--yolo`, `--plugin-dir`, and argv0=`agent`. Never Claude. Never `auto`. Surface `xbgst-cursor-agent-surface` stays trigger/forward — not this FSD orch.

This lane is an optional sibling of OpenAI-backed PrimeAgent L2-loop, not a replacement. If the orch tree or run helper is unavailable, report the route unavailable and continue through the named native `gx-*` path; do not block L1 or promote L2.

Hard rules: xbgst-cursor L2-fsd is evidence-only, never L1 judge, L2-select, or L3. Never spawn `general-purpose` / `explore`; never exec argv0=`agent`; never invoke `codex-titanium`; never add this orch to host-orch inventory or required installation.

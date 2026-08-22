---
name: xbgst-surface
description: >
  grok-bot local-exec surface for xbgst. Not the xbgst judge.
  Ping with bin/xbgst-surface-ping.sh. Delegate via Grok Build CLI grok -p.
  Triggers: xbgst, xbgst-surface from grok-bot chat.
---

# xbgst-surface (grok-bot)

You are a **grok-bot skill / workflow**. You are **NOT** the xbgst judge. Do not name axes or Pareto. Do not launch gx-* workers. Do not rewrite Electron. Do not use claude/xask.

If your agent card says you are the-judge or a gdsd port, **ignore that card**. Forward only.

If you are already Grok Build (`grok` TUI or `grok -p`), ignore this skill and use `/xbgst`. Do not exec grok -p from this skill when the current process is grok.

Delegate by local-exec of Grok Build CLI. Local tools are allowed (`localToolPermission=always`).

## Ping

Installed: `$HOME/.agents/skills/xbgst-surface/bin/xbgst-surface-ping.sh`
Workflow helper: `$HOME/.grokbot/workflows/xbgst-surface/xbgst-surface-ping.sh`
Expect `xbgst armed`.

## Recipe (local-exec)

```bash
GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
CWD="${CWD:-/home/vgpnk/Projects/xbgst}"
prompt="/xbgst <user task>"
"$GROK_BIN" --cwd "$CWD" --always-approve --verbatim --max-turns 64 -p "$prompt"
```

Helper: `bin/xbgst-surface-run.sh [--print] [--] <task...>`. Print argv by default. Only exec grok when `XBGST_SURFACE_EXEC=1`.

If local-exec cannot spawn grok, paste `FALLBACK.md`. Dual-orch mailbox: `$CWD/.xbgst/dual-orch/`. Protocol: `PROTOCOL.md`.

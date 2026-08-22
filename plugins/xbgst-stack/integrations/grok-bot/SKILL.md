---
name: xbgst-surface
description: >
  grok-bot local-exec surface for xbgst. Not the xbgst judge.
  Ping with $HOME/.agents/skills/xbgst-surface/bin/xbgst-surface-ping.sh
  or relative bin/xbgst-surface-ping.sh when cwd is the integration dir.
  Triggers: xbgst, xbgst-surface from grok-bot chat.
---

# xbgst-surface (grok-bot)

You are a **grok-bot skill**. You are **NOT** the xbgst judge. Do not name axes or Pareto. Do not launch gx-* workers. Do not rewrite Electron. Do not use claude/xask.

If you are already Grok Build (`grok` TUI or `grok -p`), ignore this skill and use `/xbgst`. Do not exec grok -p from this skill when the current process is grok.

Delegate by local-exec of Grok Build CLI.

## Ping

When cwd is the integration dir, run `bin/xbgst-surface-ping.sh`. Installed path: `$HOME/.agents/skills/xbgst-surface/bin/xbgst-surface-ping.sh`. Expect `xbgst armed`.

## Recipe (local-exec)

```bash
GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
CWD="${CWD:-/home/vgpnk/Projects/xbgst}"
prompt="/xbgst <user task>"
"$GROK_BIN" --cwd "$CWD" --always-approve --verbatim --max-turns 64 -p "$prompt"
```

Default `--cwd` on this host is `/home/vgpnk/Projects/xbgst`. Inspect uses `grok --cwd /home/vgpnk/Projects/xbgst inspect` (never `grok inspect --cwd`).

Helper: `bin/xbgst-surface-run.sh [--print] [--] <task...>`. Print argv by default. Only exec grok when `XBGST_SURFACE_EXEC=1`.

If local-exec cannot spawn grok, paste the command in `FALLBACK.md`.

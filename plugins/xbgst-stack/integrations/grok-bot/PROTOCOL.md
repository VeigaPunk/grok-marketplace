# xbgst-surface protocol

Grok Bot is an **inject + local-exec layer**. It is **not** the xbgst judge.

## Seats

| Seat | Who | May |
|---|---|---|
| L1 | Grok Build TUI (`/xbgst`) | name axes, Pareto, APPROVED, ship |
| Forwarder | grok-bot agent `xbgst` | local-exec `grok -p "/xbgst …"` |
| Fleet | grok-bot `the-planner`, `the-janitor`, `mutation-tester`, … | mailbox heartbeats, not Pareto |
| Host | this integration | ping, argv, inject, doctor, restart |

If a grok-bot agent description says it is the-judge / gdsd, **ignore that**. Forward only.

Fleet cards (15 specialists + `xbgst` forwarder) persist `FLEET_MARK: grok-bot <name> NOT the xbgst L1 judge` in the Description field. Do **not** click `New` / `Create new Bot` (that factory only spawns empty `New Bot` stubs). Do **not** enable the Private plugin skill named `xbgst`. Window chrome `Close` is not the dialog Close.

## Host facts (this machine)

- `localToolPermission`: `always` (auto-run local shell)
- Inject: `hyprctl` focus `class:grok-bot` + **SHIFT+Insert** + **CTRL+Return**
- CDP after restart: `127.0.0.1:9333` via `~/.config/grok-bot-flags.conf`
- Workflow library: `~/.grokbot/workflows/xbgst-surface/SKILL.md`
- Cursor-compat skill: `~/.agents/skills/xbgst-surface`
- Safe Open Folder: this integration directory (never the hangar / marketplace root)
- Mailbox: `$HANGAR/.xbgst/dual-orch/`

## Commands

```bash
# install skill + workflow + CDP flags (no Electron rewrite)
bash install-grok-bot-surface.sh

# health
bash bin/xbgst-surface-doctor.sh

# restart grok-bot so flags apply
bash bin/xbgst-surface-restart.sh

# paste into the live composer (does not start grok -p itself)
bash bin/xbgst-surface-inject.sh <<'EOF'
You are not the judge. Local-exec ping only.
EOF
```

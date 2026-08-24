---
description: Detach an L1 clone in another tmux pane at a target cwd. Real judge there. Prototype.
argument-hint: <cwd> <task>
---

# /xbgst-clone

Detach a **clone of this L1** in another tmux window/session, with `--cwd` set to another repo. **mode: xbgst**.

That pane **is** a Grok L1: it loads `/xbgst` (skill **xbgst**) there and may Pareto / `APPROVED` / ship in that cwd. This pane stays the parent L1 and **does not wait**.

Not `/xbgst-orch` (in-process child planner, evidence only, same cwd). Not a second judge in *this* pane.

```bash
STACK=$(readlink -f ~/.grok/installed-plugins/xbgst-stack-*/scripts/xbgst-clone-l1.sh | head -1)
# marketplace checkout:
# STACK=~/Projects/xbgst/grok-marketplace/plugins/xbgst-stack/scripts/xbgst-clone-l1.sh
bash "$STACK" --cwd <dir> -- <task>
```

`--dry-run` prints argv. `--ping` overfits `CLONE_L1_OK` without a full orch. Never `--team 0` or `1`. Grok has no `--no-leader`; the script passes `--leader-socket` plus `env -C` so pane PWD matches `--cwd`. `GX_TEAMS_SKIP_GODSPEED=1` plus gx-teams slash skip keep `-p /xbgst …` unwrapped so that pane is a real L1, not a godspeed teammate oneshot.

Autonomous: L1 should clone (not fold, not `/xbgst-orch`) when the named scope is an existing directory whose realpath is not this cwd. Explicit `/xbgst-clone` on this cwd is allowed for the A/B (second real L1 in another pane).

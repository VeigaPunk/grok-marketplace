---
name: xbgst-livepatch
description: >
  Install and maintain the Grok Build CLI livepatch that ships with xbgst-stack.
  Hard-bans general-purpose and explore at CLI level; re-applies every 6h.
  Triggers: xbgst-livepatch, livepatch grok, ban general-purpose, install timer,
  grok-build-livepatch, REPLACE_BIN.
---

# xbgst-livepatch

Bundled with **xbgst-stack** in **VeigaPunk/grok-marketplace**. Keeps Grok Build from spawning `general-purpose` / `explore`.

**Not in this marketplace:** `heuer-planning` (ds4cc only).

## Prefer marketplace install (Grok)

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace
# if both local + remote catalogs are registered:
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
# local clone catalog:
# grok plugin install xbgst-stack@local/grok-marketplace --trust

# wire agents/skills/commands + timer
# binds 6h unit to THIS stack's livepatch/ (sets preferred-install-root)
# keep a prior standalone stamp: GROK_LIVEPATCH_KEEP_STAMP=1 bash .../install-host.sh
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh

# build/apply patch (optional binary replace — invasive)
GROK_LIVEPATCH_FORCE=1 \
  bash ~/.grok/installed-plugins/xbgst-stack-*/livepatch/scripts/check-and-patch.sh
# only when you intend to replace ~/.grok/bin/grok:
# GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 bash .../check-and-patch.sh
```

Do **not** use `marketplace add …@grok-stable` (CLI treats `@` as part of the git host). Channel pin is the git tag on the repo; `main` tracks it at ship.

## Layout (bundled)

```
xbgst-stack/livepatch/
  patches/0001-ban-generic-subagents.patch
  scripts/check-and-patch.sh
  scripts/install-timer.sh
  scripts/publish.sh          # REFUSE under marketplace (exit 2)
  systemd/
```

Resolve root (first match):

1. `~/.grok/installed-plugins/xbgst-stack-*/livepatch`
2. Marketplace clone: `…/grok-marketplace/plugins/xbgst-stack/livepatch`
3. Standalone: `~/Projects/grok-build-livepatch` (optional separate product)

## Host install (idempotent)

```bash
bash <xbgst-stack>/scripts/install-host.sh
```

Copies agents → `~/.grok/agents`, skills → `~/.grok/skills`, commands → `~/.grok/commands`, enables user timer.

## Verify

```bash
./scripts/smoke-gates.sh   # from marketplace repo root (local gates)
readlink -f ~/.grok/bin/grok
systemctl --user status grok-build-livepatch.timer
systemctl --user list-timers 'grok-build-livepatch*'
cat ~/.local/state/grok-build-livepatch/last-result 2>/dev/null || true
grok --version
```

## REPLACE_BIN

`GROK_LIVEPATCH_REPLACE_BIN=1` overwrites `~/.grok/bin/grok` with the patched build. **Opt-in only.** Default path builds under `~/.local/opt/grok-build-livepatch/` without replacing the active CLI.

## Do not

- Run `livepatch/scripts/publish.sh` from inside **grok-marketplace** (refuses; would target wrong GitHub repo).
- Expect `heuer-planning` under xbgst-stack.

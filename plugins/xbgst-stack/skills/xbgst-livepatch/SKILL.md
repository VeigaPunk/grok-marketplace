---
name: xbgst-livepatch
description: >
  Install and maintain the Grok Build CLI livepatch that ships with xbgst-stack.
  Hard-bans general-purpose and explore at CLI level; manual apply is default.
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

# wire agents/skills/commands (manual mode default; timer optional)
# timer opt-in binds the 6h unit to THIS stack's livepatch/
# timer opt-in can keep a prior stamp: GROK_LIVEPATCH_KEEP_STAMP=1 bash .../install-host.sh --install-timer
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
# optional timer opt-in:
# bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh --install-timer

# re-apply (timer unit defaults REPLACE_BIN=1 → active CLI stays banned)
GROK_LIVEPATCH_FORCE=1 \
  bash ~/.grok/installed-plugins/xbgst-stack-*/livepatch/scripts/check-and-patch.sh
# opt out for one run: GROK_LIVEPATCH_REPLACE_BIN=0 …
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
# optional timer opt-in: bash <xbgst-stack>/scripts/install-host.sh --install-timer
```

Copies agents → `~/.grok/agents`, skills → `~/.grok/skills`, commands → `~/.grok/commands` (timer optional).

## Verify manual patch

```bash
./scripts/smoke-gates.sh   # from marketplace repo root (local gates)
readlink -f ~/.grok/bin/grok
cat ~/.local/state/grok-build-livepatch/last-result 2>/dev/null || true
grok --version
```

After explicit `--install-timer`, additionally verify with `systemctl --user status grok-build-livepatch.timer`.

## REPLACE_BIN

Timer unit **defaults** `GROK_LIVEPATCH_REPLACE_BIN=1` so the ban is on the **active** CLI (`~/.grok/bin/grok`), not only under `~/.local/opt/…`.  
Opt out: set `Environment=GROK_LIVEPATCH_REPLACE_BIN=0` on the unit, or run once with `GROK_LIVEPATCH_REPLACE_BIN=0`.  
Also: `install-timer.sh --link-bin` symlinks the active CLI to the livepatch build if already built.

## Maintainer: sync from standalone

When `~/Projects/grok-build-livepatch` moves, update nested trees from marketplace root:

```bash
./scripts/sync-livepatch-from-standalone.sh   # or ./scripts/sync-livepatch.sh
./scripts/smoke-gates.sh
./scripts/sync-livepatch-from-standalone.sh --install-timer   # optional: rebind unit to stack LP
./scripts/ship-check.sh
# commit on main → push → retag grok-stable
```

## Do not

- Run `livepatch/scripts/publish.sh` from inside **grok-marketplace** (refuses; would target wrong GitHub repo).
- Expect `heuer-planning` under xbgst-stack.

---
name: xbgst-livepatch
description: >
  Install and maintain the Grok Build CLI livepatch that ships with xbgst-stack.
  Hard-bans general-purpose and explore at CLI level; re-applies every 6h.
  Triggers: xbgst-livepatch, livepatch grok, ban general-purpose, install timer,
  grok-build-livepatch, REPLACE_BIN.
---

# xbgst-livepatch

Bundled with **xbgst-stack**. Not optional — keeps Grok Build from spawning `general-purpose` / `explore`.

## Layout

```
xbgst-stack/livepatch/
  patches/0001-ban-generic-subagents.patch
  scripts/check-and-patch.sh
  scripts/install-timer.sh
  systemd/
```

Resolve root: `~/.grok/installed-plugins/xbgst-stack-*/livepatch` or marketplace `plugins/xbgst-stack/livepatch` or `~/Projects/grok-build-livepatch`.

## Install

```bash
bash <xbgst-stack>/scripts/install-host.sh
GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 \
  bash <xbgst-stack>/livepatch/scripts/check-and-patch.sh
```

## Verify

```bash
readlink -f ~/.grok/bin/grok
systemctl --user status grok-build-livepatch.timer
cat ~/.local/state/grok-build-livepatch/last-result
```

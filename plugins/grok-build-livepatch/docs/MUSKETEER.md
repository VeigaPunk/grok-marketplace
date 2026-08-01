# Musketeer + 6h livepatch task

Prefer **systemd** or Grok Build scheduling over web bridges.  
[the-musketeer](https://github.com/search?q=the-musketeer) is an optional SuperGrok web UI bridge (CDP); not required for marketplace hosts.

## Option A — Grok Build native (recommended)

Point at the **marketplace** livepatch tree when present:

```text
/loop 6h Run livepatch: STACK=$(ls -d ~/.grok/installed-plugins/xbgst-stack-* 2>/dev/null | head -1); LP=${STACK:-/home/vgpnk1337/Projects/grok-marketplace/plugins/xbgst-stack}/livepatch; GROK_LIVEPATCH_FORCE=1 bash "$LP/scripts/check-and-patch.sh"; echo EXIT:$?; tail -30 ~/.local/state/grok-build-livepatch/watch.log 2>/dev/null
```

Cancel with `scheduler_delete` using the job id printed by `/loop`.

## Option B — systemd (always-on, no chat)

```bash
bash /path/to/xbgst-stack/scripts/install-host.sh
# or: bash /path/to/xbgst-stack/livepatch/scripts/install-timer.sh
journalctl --user -u grok-build-livepatch.service -n 50
```

Timer does **not** set `GROK_LIVEPATCH_REPLACE_BIN` by default.

## Option C — Musketeer web bridge (optional)

1. Install musketeer adapter if you use SuperGrok web automation.
2. Recurring prompt:

```text
You are the grok-build-livepatch watcher.
Shell: GROK_LIVEPATCH_FORCE=1 bash <xbgst-stack>/livepatch/scripts/check-and-patch.sh
If exit 2: report needs-rebase and summarize reject files.
If exit 0: report last-patched-version + last-result.
Never use subagent types general-purpose or explore.
```

## Marketplace note

When nested under **VeigaPunk/grok-marketplace**, do not run `scripts/publish.sh` (refuses). Ship via `main` + tag `grok-stable`. Nested `plugins/**/.github/workflows` are **not** executed by GitHub; root workflows under `.github/workflows/` are.

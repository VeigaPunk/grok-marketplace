# Changelog — VeigaPunk/grok-marketplace

Channel tag: annotated **`grok-stable`** (peels to shippable `main`).

## 1.1.23

- Sync livepatch to standalone tip `6692f4a` (rebase: ban-generic-subagents for grok-build 1.0.0).
- Standalone-tip stamps and plugin version lockstep refreshed.
- Docs/CHANGELOG catch-up for post-1.1.22 sync commits already on main.

## 1.1.22

- Sync livepatch to standalone tip `5e4c8e1` (cli-config `max_concurrent = 16`, public docs pages assets).
- Standalone-tip stamps lockstep; local smoke-gates green when standalone clone present.

## 1.1.21

- Add `FRONTIER.md` for durable next-move map when the channel is already green.
- CI chmod includes `rebind-livepatch-timer.sh`.

## 1.1.20

- Sync livepatch to standalone tip with unit-bound gates; auto-rebind timer after sync when user systemd is available.
- Smoke-gates: full `gates.sh` on nest; twin plug uses bash -n when unit is bound to nest (one unit / one ROOT).

## 1.1.19

- `scripts/rebind-livepatch-timer.sh` — force systemd unit onto marketplace stack `livepatch/` (clear stale Projects stamp).
- Document rebind in maintainer ship loop.

## 1.1.18

- Marketplace overlays: `scripts/overlays/install-host.xbgst-stack.sh` + safe `sync-stack-livepatch`.
- After every standalone livepatch sync, re-apply install-host overlay (prevents Projects-CANON clobber).
- Smoke-gates: install-host must match overlay; nested sync-stack must not rewrite host.

## 1.1.17

- Document public install + maintainer ship loop in CHANGELOG.
- Smoke-gates: fail if `install-host.sh` regresses to Projects-canonical timer preference.
- CI: ensure ship-check script is executable in the tree.

## 1.1.16

- `scripts/ship-check.sh` — pre-ship clean/main/tag peel.
- `smoke-gates`: standalone tip stamp must match `~/Projects/grok-build-livepatch` HEAD.
- `livepatch-watch` triggers on nested scripts/systemd as well as patches.
- Livepatch re-sync from standalone tip (install-timer reclaim / HOST.md).

## 1.1.15

- Unified CI + local gates via `SMOKE_SKIP_GROK=1 ./scripts/smoke-gates.sh`.
- Version lockstep catalog ↔ plugin.json; dual-tree payload equality.

## 1.1.14

- `sync-livepatch-from-standalone.sh` (+ `sync-livepatch.sh` alias).
- Drift gate for nested livepatch vs standalone; nest==plug payload check.
- Marketplace-first `install-host` timer bind (`GROK_LIVEPATCH_ROOT=$LP`).

## 1.1.12–1.1.13

- Livepatch payload sync tooling and `.standalone-tip` stamps.

## Earlier

- Public marketplace `veigapunk-grok-stable`: **xbgst-stack** + **grok-build-livepatch**.
- Grok-native agents/commands (no xask default); **heuer-planning not included** (ds4cc).
- Nested `publish.sh` REFUSE under marketplace; root GitHub Actions for gates + patch watch.
- Timer unit defaults `REPLACE_BIN=1` so the ban is on the active CLI.

## Install (consumers)

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
```

Do **not** append `@grok-stable` to `marketplace add` (CLI path bug). Git channel pin remains the `grok-stable` tag on this repo.

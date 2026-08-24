# Changelog — VeigaPunk/grok-marketplace

Channel tag: annotated **`grok-stable`** (peels to shippable `main`).

## Unreleased

- the-planner Cursor xask loads skill `wwkd` as the third positional (`… -- "<WWKD mapping>" "No prior context." wwkd`). Direct CLI lanes inline that SKILL.md.

## 1.1.32

- Scout/connector/the-planner hangar FIRST consult is Cursor Ultra gravy: `xask --provider cursor --model-id kimi-k3-max --gs`. `qwen38` is named Token Plan, not FIRST. Implement/review FIRST stays `xask --gs ds-pro`.
- the-planner xask consult **is** the WWKD mapping (plan artifact). Load skill `wwkd`. Do not send `'<plan question>'` to Kimi K3.
- gx-teams `cmd` spawn of `grok` prefixes `grok-oauth-route wrap --` when the helper is on PATH (pass-through if absent). OS teammate API fallback stays off `~/.grok/auth.json`. In-process `gx-*` still inherit TUI OAuth.

## 1.1.31

- Hangar gx-* cheap FIRST consult is Token Plan: `scout`/`connector` → `xask --gs qwen38`; `labrat`/`executor`/`reviewer`/`critic`/`sentinel`/`mutation-tester` → `xask --gs ds-pro`. `xask --gs kimi` stays a named route, not hangar default. Reviewer FIRST is no longer `cdx` (`XASK_CODEX_FALLBACK=kimi-k3` remaps `cdx` onto Kimi OAuth). Token Plan stays `SERVICE_TIER: default` (no `--service-tier fast`). `ds-flash` is named/opt-in, not hangar FIRST.
- `/xbgst` is the SSoT slash that loads skill **xbgst**. `/xbreed-team` is a slash clone of that file. `clone-l1 -p /xbgst`. Keep `/xgs`. Unshipped aliases remain `/xb` `/xbt` `/xbreed`.

## 1.1.30

- gx-teams does not wrap `grok -p` that starts with `/` (or when `GX_TEAMS_SKIP_GODSPEED=1`). `/xbgst-clone` stays a real L1 (`/xbreed-team` loads skill **xbgst**) instead of a godspeed teammate oneshot.

## 1.1.29

- Prototype **orch-clone**: `/xbgst-clone` detaches a real L1 in another tmux window via `gx-teams` + `grok --cwd` (`env -C` pane PWD, unique `--leader-socket`; grok has no `--no-leader`). Autonomous: other cwd → clone; same cwd disjoint → `/xbgst-orch`. Never team `0`/`1`. Gate: `tests/test-xbgst-clone-l1.sh`.

## 1.1.28

- Concurrent child orchs on the same L1: skill **xbgst** may spawn additional `the-planner` waves when a task is disjoint; `/xbgst-orch` is the explicit fork flag. Children return evidence; only L1 ships. Never a second judge.
- kimi `-p` CoT/chrome extract: `xask-kimi-stdout.py` overfits the DIRECT_P_OK capture (drop version, thinking bullets, resume footer).

## 1.1.27

- `/xbreed-team` is the SSoT slash that loads skill **xbgst**. `/xbgst` is a slash clone of that file. Unshipped duplicate aliases `/xb` `/xbt` `/xbreed`. `/xgs` stays the native-only sibling.
- Default FIRST consult is `xask --gs kimi` (native Kimi Code OAuth). `cdx` is OpenAI-only.

## 1.1.26

- gx-teams PATH: fnm shim stays ahead of `/usr/bin`; skip foreign PATH bins; drop the hangar default from `install-host`; point vendored gx-teams at the plugin Godspeed directive.
- Alias-truth: `/xb` matches `/xbgst` (stock `xask --gs cdx`, `--spark` opt-in). `/xbreed-team` is listed as an alias. `xbreed-shared.md` mode line matches the consult table. xbrd-grok SKILL mirror is byte-identical to the plugin skill.

## 1.1.25

- Product name **grok-titanium**: livepatched Grok Build PATH `grok-titanium`. Livepatch series 0001–0005.
- Vendor `gx-teams` + `xbgst-mailbox` into `xbgst-stack/integrations/gx-teams`. `install-host.sh` fail-closes without fnm, PATH-links mailbox/gx-teams, `--link-bin` when ELF exists (no timer).
- Spawn protocol is fnm multishells **always** (`BLOCKED: fnm missing`). JSONL mailbox is a log; live DM stays ACP. Do not GC `fnm_multishells`.
- Host concurrency is 64. Dropped the 16/wave specialist cap. `[subagents] max_concurrent = 64` in livepatch `cli-config.toml`. Skill/commands no longer introduce a smaller package-level cap.
- Split `/xgs` (native-only, no xask) from `/xbgst` (crossbreed). Named `gx-*` runners FIRST call PATH `xask` with flags that name the target CLI (stock `xask --gs cdx` default; `--spark` / `--substrate sekhmet` opt-in for L3). `/xb` `/xbt` `/xbreed` follow xbgst-mode. Gate: `plugins/xbgst-stack/tests/test-xask-dispatch-modes.sh`.
- Fast servicing is pinned only on ChatGPT lanes that advertise it (`xask --gs --service-tier fast cdx`). Token Plan / grok / kimi / gemma / Daybreak stay default-tier. Bare `xask cdx` does not auto-spark.

## 1.1.24

- Add [SURFACES.md](SURFACES.md): plazir27 host snapshot of CLIs, auths, overlays, and execution layers (2026-08-22). Distinct from `HOST-ORCH-INVENTORY.txt` (names fixture). Not a compat score.
- Vendor this host’s grok-orch surface into `xbgst-stack`: skills `godspeed` + `wwkd`, `ssot/godspeed-core` trilogy, symlink overlay via `install-host.sh` (dir symlink if dest missing; per-file if dest is a real dir).
- Primary consumer install is `scripts/install-xbgst-stack.sh` (curl|bash one-liner): marketplace add + `plugin install --trust` + that plugin’s `install-host`; merge-enable only; no livepatch FORCE apply; `--from-tree` for local overfit.
- Phase 0 paths fall back to the plugin tree (no `~/Projects` required). `scout.md` YAML no longer uses a bare `tools: *` alias.
- Host dirt stripped (`vgpnk1337` path). No SessionStart hook. No `heuer-planning`. No `the-kimiraikkoner`.

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
curl -fsSL https://raw.githubusercontent.com/VeigaPunk/grok-marketplace/main/scripts/install-xbgst-stack.sh | bash
```

Equivalent 3-step without FORCE apply; do **not** append `@grok-stable` to `marketplace add` (CLI path bug). Conservative raw pin: `…/grok-stable/scripts/install-xbgst-stack.sh`. Git channel pin remains the `grok-stable` tag on this repo.

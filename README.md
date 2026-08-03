# veigapunk-grok-stable

Public **Grok Build** marketplace: **xbgst-stack** (orchestrator agents/skills/commands + bundled livepatch).

| | |
|--|--|
| **Repo** | [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace) |
| **Channel tag** | annotated `grok-stable` (peels to shippable `main`) |
| **Not included** | `heuer-planning` — lives on **ds4cc** marketplace, not here |
| **Changelog** | [CHANGELOG.md](CHANGELOG.md) |
| **Frontier** | [FRONTIER.md](FRONTIER.md) (next moves when green) |

## Install

`grok plugin marketplace add` takes a URL, `user/repo`, or local path. **Do not** append `@ref` to marketplace add (CLI treats it as part of the git host path).

```bash
# Primary (public)
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust

# Wire host agents/skills/commands + livepatch timer
# (timer unit defaults REPLACE_BIN=1 so active CLI gets the ban)
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
GROK_LIVEPATCH_FORCE=1 \
  bash ~/.grok/installed-plugins/xbgst-stack-*/livepatch/scripts/check-and-patch.sh
# opt out of binary replace: GROK_LIVEPATCH_REPLACE_BIN=0 …
```

If both GitHub and a local path marketplace are registered, the CLI requires a **pin**:

```bash
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust   # remote catalog
grok plugin install xbgst-stack@local/grok-marketplace --trust        # local path catalog
```

Local dev:

```bash
grok plugin marketplace add /path/to/grok-marketplace
grok plugin install xbgst-stack@local/grok-marketplace --trust
```

Git channel pin (docs / clone): `VeigaPunk/grok-marketplace@grok-stable`

Optional second plugin (same livepatch, also inside xbgst-stack):

```bash
grok plugin install grok-build-livepatch --trust
```

## xbgst-stack layout

| Path | Role |
|------|------|
| `agents/` | Grok specialists (`the-planner`, `scout`, `executor`, …); GP/explore are banned stubs |
| `skills/xbgst` | Judge: local-first → commit → push `main` |
| `skills/xbgst-livepatch` | Install/verify CLI livepatch |
| `skills/the-janitor` | 1Password / secrets |
| `commands/` | `/xbgst`, `/xbgst-livepatch`, aliases |
| `livepatch/` | Patch + 6h systemd timer |
| `scripts/install-host.sh` | Idempotent host wire-up |

## Local gates

```bash
./scripts/smoke-gates.sh
# CI / hosts without grok CLI:
SMOKE_SKIP_GROK=1 ./scripts/smoke-gates.sh
```

Validates both plugins (or JSON-only if no `grok`), asserts **heuer-planning** is absent, checks README install form, version lockstep, dual nested livepatch equality, and that nested `publish.sh` scripts refuse under this repo. When `~/Projects/grok-build-livepatch` exists, also asserts nested trees match that tip.

### Sync livepatch from standalone

```bash
./scripts/sync-livepatch-from-standalone.sh          # rsync + restore install-host overlay
./scripts/sync-livepatch-from-standalone.sh --check  # drift only
./scripts/smoke-gates.sh
./scripts/rebind-livepatch-timer.sh                  # force 6h unit onto stack livepatch/
./scripts/ship-check.sh                              # clean tree + main + tag peel hints
# then commit on main + move tag grok-stable
```

CI (GitHub Actions, root only):

- `.github/workflows/marketplace-gates.yml` — structural gates on every push to `main`
- `.github/workflows/livepatch-watch.yml` — 6h apply/test of the bundled ban patch against `xai-org/grok-build`

Nested `plugins/**/.github/workflows` are **not** run by GitHub; keep root workflows in sync.


## Recommended Grok CLI config

**Grok Builder site:** [veigapunk.github.io/grok-build-livepatch](https://veigapunk.github.io/ds4cc-marketplace/)

Ship-aligned host config for this marketplace + livepatch ban:

- Template: [`plugins/xbgst-stack/livepatch/docs/cli-config.toml`](plugins/xbgst-stack/livepatch/docs/cli-config.toml)
- Standalone copy: [VeigaPunk/grok-build-livepatch `docs/cli-config.toml`](https://github.com/VeigaPunk/grok-build-livepatch/blob/main/docs/cli-config.toml)

```bash
# merge into ~/.grok/config.toml then:
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
```

## Out of scope

- **heuer-planning** → install from ds4cc if you want full SAT skill load for critic
- Nested `livepatch/scripts/publish.sh` targets the **standalone livepatch repo**, not this marketplace — do not run it from here for marketplace ship

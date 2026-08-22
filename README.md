# veigapunk-grok-stable

Public **Grok Build** marketplace: **xbgst-stack** (orchestrator agents/skills/commands + bundled livepatch).

| | |
|--|--|
| **Repo** | [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace) |
| **Channel tag** | annotated `grok-stable` (peels to shippable `main`) |
| **Not included** | `heuer-planning` — lives on **ds4cc** marketplace, not here |
| **Changelog** | [CHANGELOG.md](CHANGELOG.md) |
| **Frontier** | [FRONTIER.md](FRONTIER.md) (next moves when green) |
| **Surfaces** | [SURFACES.md](SURFACES.md) (host CLI/auth/layer snapshot; not HOST-ORCH names) |

## Install

**Primary** (one-shot orch overlay — marketplace add + `plugin install --trust` + that plugin’s `install-host.sh`; no livepatch apply, no `config.toml` overwrite):

```bash
curl -fsSL https://raw.githubusercontent.com/VeigaPunk/grok-marketplace/main/scripts/install-xbgst-stack.sh | bash
```

Conservative raw pin (git tag peel; **not** `marketplace add …@tag`):  
`https://raw.githubusercontent.com/VeigaPunk/grok-marketplace/grok-stable/scripts/install-xbgst-stack.sh`

Equivalent 3-step (same overlay; still no FORCE apply):

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
# resolve the installed plugin dir (prefer: grok plugin details xbgst-stack), then:
bash "$STACK/scripts/install-host.sh"
# optional livepatch: GROK_LIVEPATCH_FORCE=1 bash "$STACK/livepatch/scripts/check-and-patch.sh"
# optional timer: bash "$STACK/scripts/install-host.sh" --install-timer
```

`grok plugin marketplace add` takes a URL, `user/repo`, or local path. **Do not** append `@ref` to marketplace add (CLI treats it as part of the git host path).

If both GitHub and a local path marketplace are registered, the CLI requires a **pin**:

```bash
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust   # remote catalog
grok plugin install xbgst-stack@local/grok-marketplace --trust        # local path catalog
```

Local dev / overfit (no network):

```bash
bash scripts/install-xbgst-stack.sh --from-tree /path/to/grok-marketplace
# or:
grok plugin marketplace add /path/to/grok-marketplace
grok plugin install xbgst-stack@local/grok-marketplace --trust
```

Git channel pin (docs / clone): tag `grok-stable` on this repo (not a marketplace `@` suffix).

Optional second plugin (same livepatch, also inside xbgst-stack):

```bash
grok plugin install grok-build-livepatch@veigapunk/grok-marketplace --trust
```

## xbgst-stack layout

| Path | Role |
|------|------|
| `agents/` | Grok specialists (`the-planner`, `scout`, `executor`, …); GP/explore are banned stubs |
| `skills/xbgst` | Judge: local-first → commit → push `main` |
| `skills/xbgst-livepatch` | Install/verify CLI livepatch |
| `skills/the-janitor` | 1Password / secrets |
| `commands/` | `/xbgst`, `/xbgst-livepatch`, aliases |
| `livepatch/` | Manual patch + optional 6h systemd timer |
| `scripts/install-host.sh` | Idempotent host wire-up |

Repo-root [SURFACES.md](SURFACES.md) is the current host snapshot of binaries, auths, overlays, and execution layers. Use it when changing this README so aliases and layers stay distinct from grok-orch names.

## Local gates

```bash
./scripts/smoke-gates.sh
# CI / hosts without grok CLI:
SMOKE_SKIP_GROK=1 ./scripts/smoke-gates.sh
```

Validates both plugins (or JSON-only if no `grok`), asserts **heuer-planning** is absent, checks README install form, version lockstep, dual nested livepatch equality, and that nested `publish.sh` scripts refuse under this repo. When `~/Projects/grok-build-livepatch` exists, also asserts nested trees match that tip.

### Sync livepatch from standalone

```bash
./scripts/sync-livepatch-from-standalone.sh                # rsync + restore install-host overlay
./scripts/sync-livepatch-from-standalone.sh --check        # drift only
./scripts/sync-livepatch-from-standalone.sh --install-timer # optional timer rebind after sync
./scripts/smoke-gates.sh
./scripts/ship-check.sh                              # clean tree + main + tag peel hints
# then commit on main + move tag grok-stable
```

CI (GitHub Actions, root only):

- `.github/workflows/marketplace-gates.yml` — structural gates on every push to `main`
- `.github/workflows/livepatch-watch.yml` — 6h apply/test of the bundled ban patch against `xai-org/grok-build`

Nested `plugins/**/.github/workflows` are **not** run by GitHub; keep root workflows in sync.


## Recommended Grok CLI config

**Primary grok-orch install:** the one-liner above (`scripts/install-xbgst-stack.sh`). It merge-enables `xbgst-stack` in an existing `~/.grok/config.toml` and never curls a remote toml over the file.

Operator / multi-CLI site (optional; not the orch default): [veigapunk.github.io/ds4cc-marketplace](https://veigapunk.github.io/ds4cc-marketplace/) · [grok-cli-config.toml](https://veigapunk.github.io/ds4cc-marketplace/grok-cli-config.toml)  
Optional livepatch docs mirror: [veigapunk.github.io/grok-build-livepatch](https://veigapunk.github.io/grok-build-livepatch/)

Ship-aligned host config template for this marketplace + livepatch ban:

- Template: [`plugins/xbgst-stack/livepatch/docs/cli-config.toml`](plugins/xbgst-stack/livepatch/docs/cli-config.toml)
- Standalone copy: [VeigaPunk/grok-build-livepatch `docs/cli-config.toml`](https://github.com/VeigaPunk/grok-build-livepatch/blob/main/docs/cli-config.toml)

```bash
# Prefer the one-liner. Manual equivalent (merge config yourself; no FORCE apply):
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
STACK=$(grok plugin details xbgst-stack | sed -n 's/^[[:space:]]*path:[[:space:]]*//p')
bash "$STACK/scripts/install-host.sh"
```

## Related stack

| Piece | Role | Link |
|-------|------|------|
| **grok-marketplace** (this repo) | Grok `xbgst-stack` + nested livepatch | [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace) |
| **grok-build-livepatch** | CLI hard-ban GP/explore; 6h timer; optional Pages mirror | [VeigaPunk/grok-build-livepatch](https://github.com/VeigaPunk/grok-build-livepatch) |
| **ds4cc-marketplace** | Multi-CLI marketplace + **primary** Grok Builder site | [VeigaPunk/ds4cc-marketplace](https://github.com/VeigaPunk/ds4cc-marketplace) · [site](https://veigapunk.github.io/ds4cc-marketplace/) |
| **xbrd-spark / sekhmet** | L3 swarm substrate (≤64 jobs); ships via ds4cc as `sekhmet` | [VeigaPunk/xbrd-spark](https://github.com/VeigaPunk/xbrd-spark) |
| **sekhmet-l3** | Public L3 usage + GATE evidence (luna + fast) | [VeigaPunk/sekhmet-l3](https://github.com/VeigaPunk/sekhmet-l3) |
| **xbgst-site** | Public xbgst hub | [site](https://veigapunk.github.io/xbgst-site/) · [VeigaPunk/xbgst-site](https://github.com/VeigaPunk/xbgst-site) |

## Out of scope

- **heuer-planning** → install from [ds4cc-marketplace](https://github.com/VeigaPunk/ds4cc-marketplace) if you want full SAT skill load for critic
- Nested `livepatch/scripts/publish.sh` targets the **standalone livepatch repo**, not this marketplace — do not run it from here for marketplace ship

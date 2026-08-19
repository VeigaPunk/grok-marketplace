# Host install (manual patch; optional timer)

Canonical packaging lives in this public repo. xbgst-stack may vendor a
`livepatch/` copy; prefer this checkout when both exist.

## Manual patch (recommended default)

```bash
cd ~/Projects/grok-build-livepatch   # or git clone …
chmod +x scripts/*.sh
./scripts/gates.sh                  # offline health
./scripts/check-and-patch.sh        # first build (network + cargo)
# optional automation:
./scripts/install-timer.sh          # opt-in 6h timer → this ROOT
./scripts/install-timer.sh --status # ExecStart, ban_in_binary, active_cli
# after upgrades, keep marketplace/plugin copies aligned:
./scripts/sync-stack-livepatch.sh   # sync only; no timer changes
# append --install-timer only when timer rebind is desired
```

## Root resolution (`install-timer.sh`)

| Priority | When |
|----------|------|
| `GROK_LIVEPATCH_ROOT` | Explicit path with `scripts/check-and-patch.sh` |
| stamp file | Only if `GROK_LIVEPATCH_KEEP_STAMP=1` |
| script checkout | Directory of the `install-timer.sh` you ran |

Install **always** rewrites  
`~/.local/state/grok-build-livepatch/preferred-install-root`.

Reclaim after a plugin stole the unit:

```bash
cd ~/Projects/grok-build-livepatch && ./scripts/install-timer.sh
```

## xbgst-stack `install-host.sh`

Wires agents, skills, and commands without changing timers. Pass
`--install-timer` (or `--rebind-timer`) to opt into a marketplace-first timer
bind. `--no-timer` remains accepted as a compatibility no-op.

## Active CLI

Unit defaults `Environment=GROK_LIVEPATCH_REPLACE_BIN=1` so
`~/.grok/bin/grok` → `~/.local/opt/grok-build-livepatch/grok`.
Opt out: set `REPLACE_BIN=0` on the user unit.

```bash
./scripts/install-timer.sh --link-bin   # ~/.grok/bin/grok + grok-titanium
./scripts/gates.sh                      # fails if install binary lacks ban string
```

`--link-bin` also installs the **Grok Titanium** host name (Codex Titanium twin):

- `~/.local/opt/grok-titanium/grok` → livepatched binary
- `~/.local/bin/grok-titanium` → that opt link

Resolve: `GROK_BIN` → `grok-titanium` → `grok`. Same ban; first livepatch iteration is the host binary.

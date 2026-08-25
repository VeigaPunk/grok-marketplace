# Host install (manual patching default; timer optional)

Canonical packaging lives in this public repo. xbgst-stack may vendor a
`livepatch/` copy; prefer this checkout when both exist.

## One-shot (recommended)

```bash
cd ~/Projects/grok-build-livepatch   # or git clone …
chmod +x scripts/*.sh
./scripts/gates.sh                  # offline health
./scripts/check-and-patch.sh        # first build (network + cargo)
./scripts/install-timer.sh --link-bin        # point grok + grok-titanium at the livepatch ELF
# ./scripts/install-timer.sh --install-timer  # opt-in 6h cargo timer; not the default
./scripts/install-timer.sh --status # ExecStart, ban_in_binary, active_cli
# after upgrades, keep marketplace/plugin copies aligned:
./scripts/sync-stack-livepatch.sh   # sync scripts + rewrite install-host (manual by default)
./scripts/sync-stack-livepatch.sh --install-timer  # optional explicit timer rebind
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
cd ~/Projects/grok-build-livepatch && ./scripts/install-timer.sh --install-timer
```

## xbgst-stack `install-host.sh`

Marketplace-first. Installs host files without configuring a timer by default.
Pass `--install-timer` to opt in; timer ROOT binds to the stack `livepatch/`
via `GROK_LIVEPATCH_ROOT=$LP`. Fail-closes if `fnm` is missing. PATH-links
`gx-teams` and `xbgst-mailbox`. `--link-bin` grok-titanium when the livepatch
ELF exists (no cargo rebuild).

## Active CLI

Unit defaults `Environment=GROK_LIVEPATCH_REPLACE_BIN=1` so
`~/.grok/bin/grok` → `~/.local/opt/grok-build-livepatch/grok`.
Opt out: set `REPLACE_BIN=0` on the user unit.

```bash
./scripts/install-timer.sh --link-bin   # ~/.grok/bin/grok + grok-titanium
./scripts/gates.sh                      # fails if install binary lacks ban string
```

`--link-bin` installs the **grok-titanium** product name (Codex Titanium twin):

- `~/.local/opt/grok-titanium/grok` → livepatched binary (series 0001–0005)
- `~/.local/bin/grok-titanium` → that opt link (PATH)

Resolve: `GROK_BIN` → `grok-titanium` → `grok`. Same ban; first livepatch iteration is the host binary. The PATH name is `grok-titanium`, not a HOST.md-only alias.

`install-host.sh` (marketplace `xbgst-stack`) fail-closes without `fnm`, PATH-links `gx-teams` + `xbgst-mailbox` from `integrations/gx-teams`, and runs `--link-bin` when the livepatch ELF exists. Spawn isolation is fnm multishells always. Do not GC `fnm_multishells`. JSONL mailbox is a log; live DM is ACP.

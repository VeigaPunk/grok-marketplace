# FRONTIER — VeigaPunk/grok-marketplace

**Channel:** annotated tag `grok-stable` peels to shippable `main`.  
**Policy:** local-first → APPROVED → commit → `git push -u origin main` (no fork/PR default).  
**Not in this marketplace:** `heuer-planning` (ds4cc only).

## Last verified green (maintainers)

Re-run `./scripts/ship-check.sh` to refresh; do not trust this block without it.

| Item | Expectation |
|------|-------------|
| Branch | `main` clean, not behind `origin/main` |
| Tag | `grok-stable^{}` == `HEAD` |
| Gates | `./scripts/smoke-gates.sh` + `./scripts/ship-check.sh` PASS |
| Livepatch stamp | `plugins/*/.standalone-tip` == `~/Projects/grok-build-livepatch` HEAD (if clone present) |
| Host timer | `./scripts/rebind-livepatch-timer.sh` if unit drifts to Projects |

## Consumer install

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
```

Do **not** use `marketplace add …@grok-stable` (CLI treats `@` as git host path).  
Git pin: tag `grok-stable` on this repo.

## Maintainer loop (when standalone moves)

```bash
./scripts/sync-livepatch-from-standalone.sh   # rsync + install-host overlay + rebind
./scripts/smoke-gates.sh
./scripts/ship-check.sh
# commit → push main → retag grok-stable
```

Overlays (do not delete):

- `scripts/overlays/install-host.xbgst-stack.sh` — marketplace-first timer bind  
- `scripts/overlays/sync-stack-livepatch.marketplace-safe.sh` — never rewrite install-host  

## Open frontier (non-blocking)

1. **Standalone tip moves** — only mandatory re-entry; sync + ship.  
2. **Host stamp drift** — other tools may re-stamp Projects; rebind.  
3. **GitHub Actions** — confirm `marketplace-gates` / `livepatch-watch` on the remote (needs `gh`/UI).  
4. **Product polish** — agent prose cleanup; richer CHANGELOG; optional livepatch tip note per release.  
5. **Twin-tree unit** — one systemd unit → one ROOT; nest gets full `gates.sh`, plug may bash -n only.

## Explicit non-goals

- Shipping `heuer-planning` here  
- Nested `publish.sh` for marketplace remote  
- Fork → PR as default delivery  

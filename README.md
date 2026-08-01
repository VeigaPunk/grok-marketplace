# veigapunk-grok-stable

**Grok Build marketplace** for VeigaPunk’s production xbgst stack and Grok CLI livepatch.

**Release channel tag:** `grok-stable` (annotated; peels to shippable `main`)  
**Primary source:** [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace)

## Install

`grok plugin marketplace add` takes a URL, `user/repo`, or local path — **not** `@ref` on the marketplace source (CLI would treat `@…` as part of the git host path). Pin the channel by consuming the **`grok-stable` tag** on this repo (same tip as `main` at ship time).

```bash
# Primary — public marketplace (main tracks grok-stable at ship)
grok plugin marketplace add VeigaPunk/grok-marketplace

# Install plugins from that marketplace
grok plugin install xbgst-stack --trust
grok plugin install grok-build-livepatch --trust

# Optional: install a plugin tree directly from the annotated tag
# grok plugin install "VeigaPunk/grok-marketplace@grok-stable" --trust   # if single-root plugin
# or path-in-repo form when supported: user/repo@ref#subdir

# Enable: /plugins → enable, or config.toml
# [plugins]
# enabled = ["xbgst-stack", "grok-build-livepatch"]
```

**Contract string (channel pin):** consumers and docs may still cite  
`VeigaPunk/grok-marketplace@grok-stable`  
as the **git ref** of the marketplace tip; use it with `git clone` / install `@ref` SOURCES, not as the marketplace-add argument.

### Local path (dev smoke)

```bash
grok plugin marketplace add /path/to/grok-marketplace
# or from repo root:
grok plugin marketplace add .
grok plugin list
```

## Plugins

| Plugin | Contents |
|--------|----------|
| **xbgst-stack** | Specialist agents (xbrd-gdsp mapped), skills (`xbgst`, `the-janitor`), commands (`/xbgst`, `/xgs`, `/xbt`, `/xbreed`, …) |
| **grok-build-livepatch** | Patch that bans `general-purpose` / `explore` at CLI level + 6h re-apply scripts |

## Tag policy

- `grok-stable` — installable, tested on host Grok Build
- Move tip only when agents + livepatch smoke green

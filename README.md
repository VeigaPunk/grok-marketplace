# veigapunk-grok-stable

**Grok Build marketplace** for VeigaPunk’s production xbgst stack and Grok CLI livepatch.

**Release channel tag:** `grok-stable`

## Install

```bash
# Add marketplace (GitHub shorthand once published)
grok plugin marketplace add VeigaPunk/grok-marketplace

# Or local path while developing
grok plugin marketplace add /home/vgpnk1337/Projects/grok-marketplace

# Install plugins
grok plugin install xbgst-stack --trust
grok plugin install grok-build-livepatch --trust

# Enable
# /plugins → enable, or config.toml [plugins] enabled = ["xbgst-stack", "grok-build-livepatch"]
```

## Plugins

| Plugin | Contents |
|--------|----------|
| **xbgst-stack** | Specialist agents (xbrd-gdsp mapped), skills (`xbgst`, `the-janitor`), commands (`/xbgst`, `/xgs`, `/xbt`, `/xbreed`, …) |
| **grok-build-livepatch** | Patch that bans `general-purpose` / `explore` at CLI level + 6h re-apply scripts |

## Tag policy

- `grok-stable` — installable, tested on host Grok Build
- Move tip only when agents + livepatch smoke green

## Local verify

```bash
grok plugin marketplace add ./ 
grok plugin list
```

# veigapunk-grok-stable

**Grok Build marketplace** for VeigaPunk’s production xbgst stack and Grok CLI livepatch.

**Release channel tag:** `grok-stable`  
**Primary source:** [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace) `@grok-stable`

## Install

```bash
# Primary — pin the stable channel
grok plugin marketplace add VeigaPunk/grok-marketplace@grok-stable

# Install plugins from that marketplace
grok plugin install xbgst-stack --trust
grok plugin install grok-build-livepatch --trust

# Enable: /plugins → enable, or config.toml
# [plugins]
# enabled = ["xbgst-stack", "grok-build-livepatch"]
```

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

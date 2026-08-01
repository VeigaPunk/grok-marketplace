# veigapunk-grok-stable

**xbgst-stack ships with grok-build-livepatch wired in.**

Tag: `grok-stable`

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace@grok-stable
# local:
grok plugin marketplace add /home/vgpnk1337/Projects/grok-marketplace

grok plugin install xbgst-stack --trust
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 \
  bash ~/.grok/installed-plugins/xbgst-stack-*/livepatch/scripts/check-and-patch.sh
```

| Path in xbgst-stack | Role |
|---------------------|------|
| `agents/` | xbrd specialists |
| `skills/xbgst` | judge (local-first → main) |
| `skills/xbgst-livepatch` | install/verify CLI livepatch |
| `livepatch/` | patch + 6h systemd |
| `scripts/install-host.sh` | wire agents + timer |

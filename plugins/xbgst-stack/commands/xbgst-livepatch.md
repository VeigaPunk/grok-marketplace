---
description: Install/verify bundled grok-build-livepatch (ban GP/explore, 6h timer).
---

# /xbgst-livepatch

Load skill **xbgst-livepatch** and run:

```bash
# prefer local marketplace clone if present
if [[ -x /home/vgpnk1337/Projects/grok-marketplace/plugins/xbgst-stack/scripts/install-host.sh ]]; then
  STACK=/home/vgpnk1337/Projects/grok-marketplace/plugins/xbgst-stack
else
  STACK=$(ls -d ~/.grok/installed-plugins/xbgst-stack-* 2>/dev/null | head -1)
fi
bash "$STACK/scripts/install-host.sh"
# patch/build without replacing bin unless user asked:
GROK_LIVEPATCH_FORCE=1 bash "$STACK/livepatch/scripts/check-and-patch.sh"
# REPLACE_BIN only if user explicitly wants active CLI swapped
```

Report: timer status, `readlink -f ~/.grok/bin/grok`, `grok --version`, last-result if any.

Hard rules: no nested `publish.sh`; heuer-planning is not part of this plugin.

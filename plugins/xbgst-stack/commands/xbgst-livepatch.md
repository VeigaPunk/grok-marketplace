---
description: Install/verify grok-build-livepatch that ships with xbgst-stack (ban GP/explore, 6h timer).
---

# /xbgst-livepatch

Load skill **xbgst-livepatch** and run host install:

```bash
STACK=$(ls -d ~/.grok/installed-plugins/xbgst-stack-* 2>/dev/null | head -1)
bash "$STACK/scripts/install-host.sh"
GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 \
  bash "$STACK/livepatch/scripts/check-and-patch.sh"
```

Report timer status, active grok binary path, last-result.

---
description: Apply/verify bundled grok-build-livepatch manually; timer is opt-in.
---

# /xbgst-livepatch

Load skill **xbgst-livepatch** and run:

```bash
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
STACK=""
if [[ -n "${GROK_PLUGIN_ROOT:-}" && -x "${GROK_PLUGIN_ROOT}/scripts/install-host.sh" ]]; then
  STACK="$GROK_PLUGIN_ROOT"
else
  for d in "$GROK_HOME"/installed-plugins/xbgst-stack-*; do
    [[ -f "$d/plugin.json" ]] || continue
    if grep -q '"name"[[:space:]]*:[[:space:]]*"xbgst-stack"' "$d/plugin.json" 2>/dev/null; then
      STACK="$d"
      break
    fi
  done
fi
if [[ -z "$STACK" || ! -x "$STACK/scripts/install-host.sh" ]]; then
  CAND="$HOME/Projects/xbgst/grok-marketplace/plugins/xbgst-stack"
  if [[ -x "$CAND/scripts/install-host.sh" ]]; then
    STACK="$CAND"
  fi
fi
bash "$STACK/scripts/install-host.sh"
# optional:
# bash "$STACK/scripts/install-host.sh" --install-timer
# patch/build without replacing bin unless user asked:
GROK_LIVEPATCH_FORCE=1 bash "$STACK/livepatch/scripts/check-and-patch.sh"
# REPLACE_BIN only if user explicitly wants active CLI swapped
```

Report: timer status, `readlink -f ~/.grok/bin/grok`, `grok --version`, last-result if any.

Hard rules: no nested `publish.sh`; heuer-planning is not part of this plugin.

# grok-bot surface for xbgst

grok-bot is not the judge. This skill is a local-exec trigger into Grok Build (`grok -p`). do not rewrite Electron.

## Install

From the marketplace root:

```bash
bash plugins/xbgst-stack/integrations/grok-bot/install-grok-bot-surface.sh
```

Idempotent. Symlinks this directory to `$HOME/.agents/skills/xbgst-surface`. Does not write `~/.grokbot/settings.json`. Does not create `~/.cursor`.

## Ping

```bash
bash plugins/xbgst-stack/integrations/grok-bot/bin/xbgst-surface-ping.sh
```

Expect stdout: `xbgst armed`.

## Operator steps

1. Open `/home/vgpnk/Projects/xbgst/grok-marketplace/plugins/xbgst-stack/integrations/grok-bot` as the grok-bot folder (`integrations/grok-bot`, not the judge). Do not open the hangar or grok-marketplace root — those glob `**/SKILL.md` onto the judge skill `name: xbgst`.
2. Run the install command above (home skill dest). Workspace skill is also at `.agents/skills/xbgst-surface/SKILL.md`.
3. In grok-bot, say `xbgst <task>` (or ping first).
4. The skill local-execs `grok -p` with `/xbgst <task>` on hangar `--cwd` `/home/vgpnk/Projects/xbgst`: `"$GROK_BIN" --cwd "$CWD" --always-approve --verbatim --max-turns 64 -p "$prompt"`. FALLBACK.md is equal-class — if local-exec cannot spawn `~/.grok/bin/grok`, paste FALLBACK immediately. Do not invent MCP/gdsd.

Inspect uses `grok --cwd /home/vgpnk/Projects/xbgst inspect` (never `grok inspect --cwd`).

## Gates

From marketplace root:

```bash
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-ping.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-grok-argv.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-install.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-identity.sh
```

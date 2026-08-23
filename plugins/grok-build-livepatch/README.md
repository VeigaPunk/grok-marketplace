# grok-titanium

Stock Grok Build still ships **`general-purpose`** and **`explore`** as the advertised builtins, then lets a **remote 4-slot pin** beat your host. That is not a team. That is a waiting room.

**grok-titanium** is the livepatched CLI: named specialists, GP/explore **banned in the binary**, host ceiling **64**, workflows off, foreign Cursor/Claude/Codex settings clones off. PATH: `grok-titanium`.

This is how Claude Code used to work **when it worked**. Then they walked into the clout-fable spiral of death and became sudo-masochists. The good orch was sitting there as free real estate. We took it. Now it is on a silver platter.

## The way vs stock

Constants from `xai-org/grok-build` @ **`19d42e3`** (Grok Build 1.0.6). Do not recite folklore.

| | Stock Grok Build | grok-titanium (patches **0001–0005**) |
|---|---|---|
| Advertised builtins | `general-purpose`, `explore`, `plan` (`BUILTIN_SUBAGENTS` len **3**) | `plan` only |
| Omitted `subagent_type` | `default_subagent_type()` = **`general-purpose`** | **`plan`** |
| Spawn GP / explore | advertised and spawnable | **hard-banned** (`is_banned_subagent_type`, case-insensitive), even if shadowed |
| Task ads | `subagent_type="explore"` | user-defined specialist; never GP/explore |
| Concurrent cap | compiled default **32** (`DEFAULT_MAX_CONCURRENT`). A **remote pin of 4** can beat it. | compiled **64**; remote pin ignored; no nproc clamp |
| Workflows | default ON (nproc-clamps fan-out) | `resolve_workflows()` always false |
| Foreign CLI clones | Cursor / Claude / Codex compat default ON | all cells false; native `.grok` / `.agents` stay |
| First-party full tools | spawn `general-purpose` | resolvable alias `agent` (not Task-advertised, not banned) |

The 4-slot number people feel is the **remote pin**, not the compiled 32. Titanium does not let remote win.

## Free real estate (how it worked when it worked)

Claude Code, in the era that actually moved, did **not** default the universe to a nameless explore gnome. You named a teammate. You gave it a job. You ran many of them. Connector every round. Godspeed: name the axes, iterate cheap in parallel, keep moves that improve any axis and harm none. The mailbox was a **log**. Live talk was a session, not a JSON array you `mkdir` into existence.

That orch got cloned as **xbrd / xbgst**. Then the product people arrived with the clout fable — a spiral of death of:

- generic `explore` / `general-purpose` as the *identity* of work
- permission theater (sudo-masochists clicking Approve until the frontier dies)
- a tiny concurrent cap so the model cannot embarrass the demo
- workflows and foreign-compat scanners eating the turn before a specialist exists

Stock Grok Build copied **that** death spiral (GP+explore advertised, omitted type = GP, remote 4). It did not copy the working era.

Espionage, if you need the word: we lifted the **working** dispatch, not the fable. Named `gx-*` specialists. Binary ban so the model cannot “helpfully” spawn explore. Host 64. Always-approve if you want speed. **fnm always** so sixteen bash lanes do not PATH-stomp. JSONL mailbox is still a log; live DM is ACP. That is xbgst-stack `integrations/gx-teams`, **not** a grok-build crate, **not** patch 0006.

Now it is a silver platter: five patches, this README, `PATH=grok-titanium`. Steal it back.

## Upstream honesty

`xai-org/grok-build` `CONTRIBUTING.md`:

> This repository does **not** accept external pull requests or unsolicited patches.

Zero PRs on that tree. Do not fork it as a stunt. **This repo is the public path.** Apache-2.0 upstream source; this packaging is MIT OR Apache-2.0.

## Patch series (applied in order)

| Patch | Effect |
|---|---|
| `0001-ban-generic-subagents.patch` | GP/explore hard-ban at spawn |
| `0002-kill-workflows.patch` | `resolve_workflows()` always false |
| `0003-kill-foreign-cli-compat.patch` | `resolve_compat_config()` all cells false |
| `0004-concurrency-64.patch` | compiled 64; ignore remote 4-slot; no nproc clamp |
| `0005-no-explore-plan-ads.patch` | do not advertise banned explore/GP as spawn types |

No 0006. Native `.grok` / `.agents` discovery is unaffected.

The CLI ban is enforcement. `/xbgst` names specialists. A prompt that says “please don’t use explore” is not a ban.

## Grok Bot is not this

**Grok Bot** (Electron `/opt/Grok Bot/sand`, class `grok-bot`) is not the judge and not this CLI. It is a chat toy that keeps proving it.

Point at the shit it produced (in-tree, not vibes):

- `integrations/grok-bot/docs/UI-MAP.md` — a field manual because three controls are named **Close** and one of them **quits the app**.
- `button "New"` is a **stub factory** (`SAND_DEFAULT_AGENT_NAME = "New Bot"`). Click it, mint another empty card. That is not a fleet.
- `integrations/grok-bot/FALLBACK.md` is the honest product: if local-exec cannot spawn `grok`, **paste** `grok --cwd … -p "/xbgst <task>"`. The bot is a paste buffer with a logo.
- `bin/xbgst-surface-inject.sh` focuses `class:grok-bot` and fires **SHIFT+Insert** then **CTRL+Return** because the composer will not take a grown-up stdin.

People get **really surprised** when they see something **moving mice on its own**. Yes. That is business. Computer-use, “Grok Bot's Computer,” inject helpers, the gasp. The Cursor partnership has to pay itself. The *work* still happens in **this** binary, with named specialists, not in a bot that cannot tell window-Close from dialog-Close.

Use Grok Build. Use grok-titanium. Do not promote grok-bot to L1.

## Install

```bash
git clone https://github.com/VeigaPunk/grok-build-livepatch.git
cd grok-build-livepatch
./scripts/gates.sh
./scripts/check-and-patch.sh   # apply onto public git @ 1.0.6 (19d42e3)
./scripts/install-timer.sh --link-bin   # ~/.grok/bin/grok + grok-titanium
```

Timer is **opt-in**. `--link-bin` is the PATH. Do not treat `check-and-patch` as “track downloads 1.0.8.” The known-good apply target is **1.0.6 (`19d42e3`)**.

Host overlay (named specialists, fnm-always, mailbox crate):

```bash
grok plugin marketplace add VeigaPunk/grok-marketplace
grok plugin install xbgst-stack@veigapunk/grok-marketplace --trust
bash ~/.grok/installed-plugins/xbgst-stack-*/scripts/install-host.sh
```

`xbgst-stack` **1.1.25**. Config template: [docs/cli-config.toml](docs/cli-config.toml). Pages: [ds4cc-marketplace grok config](https://veigapunk.github.io/ds4cc-marketplace/grok-cli-config.toml).

## Related

| Piece | Role |
|---|---|
| this repo | patches + grok-titanium PATH |
| [VeigaPunk/grok-marketplace](https://github.com/VeigaPunk/grok-marketplace) `plugins/xbgst-stack` | orch, livepatch copy, gx-teams mailbox, fnm-always |
| gx-teams `xbgst-mailbox` | JSONL **log**; live DM is ACP |

## License

MIT OR Apache-2.0

*this is the way*

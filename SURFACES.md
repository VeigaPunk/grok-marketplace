# xbgst-stack surfaces — plazir27 2026-08-22

Host snapshot of the xbgst stack on **plazir27** (2026-08-22). Companion to this README. **Not** `HOST-ORCH-INVENTORY.txt` (that file is grok-orch *names* only). **Not** a single “compat score.”

Refresh this file when CLIs, auths, or execution layers move. Do not merge it into the names fixture.

## How to read

Three maps stay unmerged:

1. **Grok-orch names** — `HOST-ORCH-INVENTORY.txt` (skills/commands/agents/ssot). Do not widen.
2. **Execution layers** — mechanism × who-may-use (table B).
3. **PATH / overlay / auth rows** — identity, kind tags, status (tables A + C).

Kinds are **tags on a (name, layer) row**, not a host rank. Mixing “we overlaid Grok heavily” with “we patched the grok ELF” is the silent failure.

| Kind tag | Means |
|---|---|
| `fork/ELF` | a binary we ship or livepatch |
| `wrapper` | PATH shim / exec wrapper **we** wrote |
| `host-dirt-wrapper` | PATH shim we did **not** write (omarchy npx, mise) |
| `profile` | host-native config (`-p`, TOML, `opencode.json`) |
| `overlay` | skills / agents / commands we install on a stock host |
| `router` | we call a host; we are not that host |
| `untouched` | upstream binary as shipped |

Status (runtime, orthogonal): `live-supported` | `optional` | `present-not-supported` | `declared-unapplied`. Router-lane capability `SUBBED` and doc `stale-doc` are **not** host health.

Provenance: `ours` | `host-dirt` | `upstream`.

Judge calls: **grok-titanium** is on PATH (`~/.local/bin/grok-titanium` → livepatch ELF, series 0001–0005, ads-kill yes). Dirt stays present-not-supported unless a named xbgst contract exists; PrimeAgent stays out of HOST-ORCH.

---

## Table B — execution layers

| Layer | Mechanism | Who | Live on this host |
|---|---|---|---|
| **L1-grok** | in-process `spawn_subagent` named `gx-*` | default judge | PATH `grok` ≡ `grok-titanium` livepatch ELF **1.0.6** (0001–0005); plugin `xbgst-stack`; `agent` still stock 1.0.8 |
| **L1-opencode** | OpenCode `orch` + `the-*` | OpenCode sessions | 17 agents; `general`/`explore` disabled; `opencode` 1.18.21 |
| **L1-codex** | stock Codex subagents + overlays | Codex/ChatGPT sessions | omarchy `codex` → `@openai/codex` **0.149.0**; `AGENTS.md` Godspeed-prefixed; `xbgst-codex` plugin in marketplace, **not verified installed under `~/.codex`** |
| **L2-xask** | FIRST bash consult via protocol `xask` | optional user-ON | PATH `xask` ≡ ds4cc `scripts/xask` md5 `169732b8…` |
| **L2-token-plan** | `codex -p qwen38\|ds-flash\|ds-pro` via our wrappers | opt-in; unset `CODEX_BIN` | wrappers live; process env keys **unset**; key from `op` or `~/.bailian/config.json` at call time |
| **L2-prime** | `prime-agent --provider openai-codex` envelope; legacy xAI `prime-agent-l2.sh` | optional | `prime-agent` **0.7.4** (fnm). Not HOST-ORCH |
| **L2-dsh** | pinned `@deepseek-ai/dsh@0.1.0-rc.8` | optional visual worker | cache under `~/.cache/xbgst-dsh/`; backend disabled by default |
| **L2-select** | `xbrd-selector` | optional ranked choice | plugin docs only; **binary PATH-MISS** |
| **L3-sekhmet** | `sekhmet`/`xbrd-spark` swarm ≤64 + `CODEX_BIN=codex-titanium` | explicit escalation | sekhmet **0.1.1**; titanium `0.146.0-alpha.10.1+titanium.1`; env file pins spark+luna+fast+j=64 |
| **OS-gx-teams** | tmux panes + JSONL mailbox (`xbgst-mailbox`) | Grok OS teammates (`grok -p`) | vendored in xbgst-stack `integrations/gx-teams`; PATH `gx-teams` + `xbgst-mailbox` via install-host |
| **DESK-grok-bot** | Electron `/opt/Grok Bot/sand` → skill local-exec `grok -p /xbgst` | trigger, **not** judge | `/usr/bin/grok-bot`; skill `xbgst-surface` |
| **CDP family** | fnm + `agent-browser` + `musketeer-chrome` on loopback **9222** | web-UI adapters | binaries present; **9222 down this session** |

L1 xbgst remains sole scheduler, Pareto, `APPROVED`, integrator, shipper.

---

## Table A — aliases (never mix into layer rows)

| Class | Names | Evidence | Not |
|---|---|---|---|
| identity-ELF | `grok` ≡ `grok-titanium` | same realpath `~/.local/opt/grok-build-livepatch/grok` md5 `0c3ee309301af768930ec84325436a0b` | not `agent` (stock `grok-1.0.8-linux-x86_64`) |
| identity-ELF (two cargo bins) | `sekhmet` ≡ `xbrd-spark` | this host **same md5** `b326f0bb70c69e8a6d7dd33312a8ca03`; one crate, two `[[bin]]` (not a grok-style symlink) | two L3 products |
| npm-bin identity | `bailian` ≡ `bl` | same `bailian.mjs` md5 `88f2b8f484…` | Token Plan wrappers |
| identity-ELF | `ds4cc-chrome` ≡ `musketeer-chrome` | same realpath/md5 `36154fd08be1…` | two CDP launchers |
| wrapper-exec | `kimiraikoner` → `kimiraikkoner` | tiny bash execs sibling; **different md5** | skill `the-kimiraikkoner` / plugin `the-kimiraikoner` |
| xask tokens | `cdx`=`codex`; `g`=`gemma`=`gemini` **SUBBED** HVM; `kimi`=`kimi-k3` | protocol header + `xask models --json` | `kimi-code` is a **package**, PATH name is `kimi` |
| slash (not CLIs) | `/xbgst` `/xb` `/xgs` `/xbt` `/xbreed` `/xbreed-team` `/xbgst-livepatch` `/xbgst-primeagent` | `~/.grok/commands/*.md` | PATH `xbreed` is a **different** object (Rust ELF 8.16.137) |
| not-alias | `xask` ≠ `xask-l3` | md5 `169732b8…` vs `89f1b3ae…`; protocol vs sekhmet shim | |
| not-alias | stock `codex` ≠ `codex-titanium` | omarchy bash `@openai/codex` 0.149.0 vs ELF titanium 0.146.0-alpha.10.1+titanium.1 | never symlink titanium as `codex` |
| not-alias | `grok`/`grok-titanium` ≠ `grok-bot` ≠ `grok-web` ≠ `agent` | livepatch ELF vs Electron vs musketeer CDP vs stock downloads | |
| kimi-shaped names (four) | PATH `kimi` · xask model `kimi-k3`/`kimi-code` · CDP `kimiraikkoner` · banned skill `the-kimiraikkoner` vs enabled plugin `the-kimiraikoner` | different files/spellings | do not collapse |

---

## What is currently working (xbgst contract)

These have a named contract **and** a live binary/overlay on this host.

### L1 hosts we adapted

| Surface | Version / path | What we changed | Kind tags | Status |
|---|---|---|---|---|
| **Grok Build / grok-titanium** | 1.0.6 (19d42e3) · `~/.local/opt/grok-build-livepatch/grok` | **Huge overlay:** `xbgst-stack` 1.1.25 agents, skills, slash commands, ssot, `install-host.sh` + gx-teams mailbox. Livepatch 0001–0005 (GP/explore ban, workflows kill, compat kill, concurrency-64, no explore ads). PATH `grok-titanium`. | overlay=ours · running ELF=livepatched | **live-supported** as L1 judge. Spawn hard-ban of GP/explore is **in the ELF**. |
| **OpenCode** | 1.18.21 via omarchy npx `opencode-ai` | 17 agents (`orch` + 16 `the-*`), commands `xbgst`/`xbrd`/`sekhmet`, plugin `fnm-nudge.js`, `default_agent=orch`, `general`/`explore` **disabled in config**. | overlay=ours · PATH wrapper=host-dirt · ELF=untouched | **live-supported** L1′. Going well. No ELF patch. Auth at `~/.local/share/opencode/auth.json` (not `~/.config/opencode/auth.json`). |
| **Codex (stock)** | omarchy wrapper → `@openai/codex` 0.149.0 | `~/.codex/config.toml` (never/danger-full-access, multi_agent_v2 **64**, Token Plan provider, Godspeed `AGENTS.md`). Used for E2 revenger + `xbreed ask codex`. | profile=ours · wrapper=host-dirt · ELF=untouched | **live-supported as foreign stock**. Not L3. |
| **Codex Titanium** | ELF `~/.local/bin/codex-titanium` · `codex-cli 0.146.0-alpha.10.1+titanium.1` | Forked host binary. L3 only. | fork/ELF=ours | **live-supported L3 only**. Never Daybreak, never L2, never `xbreed ask`. |

Grok “compat extremely high” = overlay volume + this session’s named specialists. The running grok ELF **is** grok-titanium (livepatch 0001–0005) when `~/.grok/bin/grok` → `~/.local/opt/grok-build-livepatch/grok`.

Codex “heavily modified per substrate” = **four surfaces**, not one CLI: stock 0.149 · titanium ELF · Token Plan wrappers/profiles · xask `cdx` token.

### Routers and our ELFs

| Surface | Version / path | Kind | Status |
|---|---|---|---|
| **xask** (protocol) | `~/.local/bin/xask` ≡ ds4cc plugin script | router=ours | **live-supported**. Providers live: chatgpt, grok, token-plan, moonshot. local/HVM **SUBBED** (`available:false`). Never spawn type `xask`. |
| **xask-models** | catalog helper | router helper | live-supported (recomputes from PATH; ignore frozen `available:false` in xask-models.json) |
| **xask-l3** | ≡ `xbrd-spark/scripts/xask` | wrapper of sekhmet | live-supported **L3 only**. gx-* FIRST bash must not call it |
| **xbreed** | ELF **8.16.137** | fork/ELF=ours | live-supported for `xask … cdx` → `xbreed ask codex` (stock, never titanium) |
| **sekhmet** / **xbrd-spark** | ELF **0.1.1** | fork/ELF=ours | live-supported L3. Cap 64. Auth: ChatGPT OAuth via seeded `~/.codex` |

`xask providers --json` runtime: chatgpt/grok/token-plan/moonshot **true**; local **false**; sekhmet **true**. Models: gpt-5.6-sol/terra/luna, daybreak-blue, gpt-5.3-codex-spark, grok-4.6/4.5, qwen3.8-max, deepseek-v4-flash-0731, deepseek-v4-pro-0813, kimi-k3, gemma4:26b (false).

### Token Plan (Alibaba / DashScope)

| Surface | Path | Kind | Status |
|---|---|---|---|
| `codex-token-plan` | our bash | wrapper=ours | live-supported opt-in |
| `codex-qwen38` / `codex-ds-flash` / `codex-ds-pro` | exec the above | wrapper=ours | live-supported opt-in |
| profiles | `~/.codex/{qwen38,ds-flash,ds-pro}.config.toml` | profile=ours | present |
| `bl` / `bailian` | fnm bailian-cli **1.17.0** | foreign CLI we use as key/source | **optional** helper; not a host |

Vault item name only: `DashScope Token Plan Team (intl sk-sp)` in `AgentAutomation`. Canonical env `DASHSCOPE_API_KEY` / wrapper `BAILIAN_TOKEN_PLAN_API_KEY` — **unset in this process**; injected at exec via `op` or `~/.bailian/config.json`.

### Desktop + OS

| Surface | Path | Status |
|---|---|---|
| grok-bot | `/usr/bin/grok-bot` → `/opt/Grok Bot/sand` | **live as trigger** (PATH + `xbgst-surface` contract). Surface tests **not re-run** this pass. Not the judge. |
| gx-teams | `gx-teams` + `xbgst-mailbox` | OS harness; JSONL log via crate; fnm-always panes |

---

## Auth surfaces (presence only — no dumps)

| Store | Present | Used by |
|---|---|---|
| `~/.grok/auth.json` | yes | Grok Build (grok.com) |
| `~/.grok/mcp_credentials.json` | yes (vercel OAuth) | plugin MCP |
| `~/.codex/auth.json` | yes | ChatGPT / Codex / Titanium / sekhmet seed |
| `~/.local/share/opencode/auth.json` | yes | OpenCode (not under `~/.config/opencode/`) |
| `~/.bailian/config.json` | yes | Token Plan key fallback |
| 1Password CLI `op` 2.35.0 | yes (account listed) | the-janitor; Token Plan `op read` |
| process `DASHSCOPE_API_KEY` / `BAILIAN_TOKEN_PLAN_API_KEY` | **unset** | must be injected per call |
| CDP cookies in `~/.local/share/the-musketeer/chrome-profile` | profile dir present | grok.com / kimi.ai / chatgpt.com / notebooklm when 9222 is up |
| PrimeAgent OpenAI OAuth | user-owned, optional | never automate `/login` |

This Grok session MCP: **github, gmail, tasks, vercel** connected; **exa** failed auth. `config.toml` has **no** `[mcp_servers]` — vercel/exa come from plugin `.mcp.json`. github/gmail/tasks are session-level, not orch inventory.

---

## Overlays / plugins (Grok enabled)

From `~/.grok/config.toml` + `grok plugin list`:

| Plugin | Marketplace | xbgst contract |
|---|---|---|
| **xbgst-stack** | grok-marketplace | **required** L1 |
| **xbrd-gdsp-fknpft** | ds4cc | protocol (`xask`/`xbreed` docs + commands) |
| **sekhmet** | ds4cc | L3 docs (binary is cargo/PATH, not the plugin) |
| the-musketeer / the-puppeteer / the-almanacker / the-kimiraikoner | ds4cc | CDP adapters — **present**; grok-orch skill `the-kimiraikkoner` is **banned dirt** (fixture FAIL) |
| the-netsshark | ds4cc | optional net audit agent (also on OpenCode) |
| aaronplug | ds4cc | scout bash tool-of-record; CLI **not** on PATH as `aaron` (plugin `bin/index.js`) |
| vercel | xAI Official | present; MCP OAuth stored |
| exa | xAI Official | present; MCP auth **failed** this session |

Grok skills beyond HOST-ORCH: `xbgst-primeagent` (optional, skipped by `install-host.sh`), `bailian-*` (dirt/helpers), `the-kimiraikkoner` (banned dirt).

---

## CDP family (working when 9222 is musketeer-owned)

| Binary | Realpath | Role |
|---|---|---|
| `musketeer-chrome` / `ds4cc-chrome` | `Projects/the-musketeer/scripts/musketeer-chrome` | burner Chrome for Testing, CDP 9222 |
| `grok-web` | `Projects/the-musketeer/grok` | fire-and-forget grok.com |
| `chitchat` | `Projects/the-puppeteer/chitchat` | ChatGPT tab |
| `almanack` | `Projects/the-almanacker/almanack` | NotebookLM |
| `kimiraikkoner` | `Projects/the-kimiraikkoner/kimiraikkoner` | kimi.ai |
| `agent-browser` | fnm global 0.34.0 | CDP client |
| `setup-grok-build` | musketeer script | host setup helper |

This session: `curl 127.0.0.1:9222` **failed**. Adapters are installed; the bus is down.

---

## Remainder (scout, classified only)

Default: present-not-supported unless a named xbgst contract exists. Scout mapped `DSH`→`dsh` and the livepatch timer→`livepatch`. Judge override: `grok-bot` **is** on PATH (`/usr/bin/grok-bot`); census TSV wins over scout PATH-MISS.

| name | status | contract |
|---|---|---|
| prime-agent | optional L2 | optional; never HOST-ORCH |
| gx-teams | live OS harness | PATH `gx-teams` + `xbgst-mailbox`; fnm-always |
| grok-bot | live trigger; tests unverified this pass | PATH `/usr/bin/grok-bot`; census beats scout PATH-MISS |
| dsh | declared-unapplied | pin rc.8; backend disabled by default |
| kimi | xask moonshot transport | PATH `kimi` 0.38.0; not an L1 host |
| bailian / bl | optional helper | Token Plan key/source; not a host |
| CDP satellites | present; bus down | 9222 failed this session |
| plazirhangar | optional | in-tree; PATH-MISS |
| xbgst-gdsd-fknpft | stub | do not revive |
| xbrd-selector | optional / PATH-MISS | L2-select docs only |
| xbgst-l3-orch | cargo-only | PATH-MISS |
| grok-titanium | live | `~/.local/bin/grok-titanium` → livepatch ELF |
| aaron | optional | scout tool-of-record; CLI not on PATH |
| vercel / exa | present-not-supported | grok plugins; exa MCP auth failed |
| heuer-planning | present-not-supported | HOST-ORCH banned; ds4cc only |
| livepatch timer | optional / uninstalled | no user systemd unit |
| claude / gemini / copilot / pi | present-not-supported | foreign |

## Declared-unapplied / PATH-miss / stubs

| Name | Reality |
|---|---|
| grok livepatch ELF | `~/.local/opt/grok-build-livepatch/grok` present. Standalone series **0001–0005** (ads-kill yes). PATH `grok` and `grok-titanium` are this ELF. Timer optional/uninstalled. |
| livepatch timer | systemd user unit **not-found** |
| `xbgst-codex` on Codex host | marketplace plugin v1.1.24 exists; `~/.codex` has Godspeed `AGENTS.md` + Token Plan, **no** verified xbgst skills install |
| `xbgst-l3-orch` | `~/.cargo/bin/xbgst-l3-orch` exists; **PATH-MISS** |
| `xbrd-selector` | ds4cc plugin docs; **binary PATH-MISS** |
| `plazirhangar` | in-tree script; PATH-MISS |
| `gx-teams` | PATH overlay from xbgst-stack `integrations/gx-teams` |
| `kimi-code` as argv | PATH-MISS; live CLI is `kimi` 0.38.0 (same npm package) |
| `xbgst-gdsd-fknpft` | compile-dead stub; do not revive |
| DSH | pinned rc.8; **not** a default L2 |

---

## Present-not-supported (on PATH, no xbgst host contract)

`claude` 2.1.235 · omarchy `gemini` (`@google/gemini-cli`, **not** xask gemini) · `copilot` · `pi` · cloud Gemini retired; xask `gemini|g|gemma` is **SUBBED** local HVM.

---

## Stale docs (do not copy)

| Doc | False claim | Live |
|---|---|---|
| `~/.xbgst/evidence/xask-xbrd-2026-08-21/PROVIDERS.md` | PATH xask is sekhmet shim; grok is not an xask model | PATH xask is protocol; grok lane live |
| `ds4cc-marketplace/docs/TITANIUM-HOST.md` | PATH xask is sekhmet shim; crate default tier `fast` | shim is `xask-l3`; crate const `default`; host env file exports `fast` |
| older sekhmet-l3 STATUS pins | model luna / fallback none | current `~/.xbgst/env.l3-sekhmet.sh`: model `gpt-5.3-codex-spark`, fallback `gpt-5.6-luna`, tier `fast`, jobs 64, `CODEX_BIN=codex-titanium` |

L3 setters (do not collapse to one number): crate const `DEFAULT_SERVICE_TIER=default` · host env file `fast` · xask-l3 default `default` then exports over process env.

---

## HOST-ORCH vs this host

`orch-inventory.sh --expect-fixture` **FAIL**: banned skill `the-kimiraikkoner` present under `~/.grok/skills/`. Extra optional skill `xbgst-primeagent` (allowed to exist; must stay out of the fixture). Fixture is still the grok-orch name freeze — this inventory does not widen it.

---

## Evidence index

- Plan (hangar): `.xbgst/plan-surface-inventory.md`
- Census TSV (hangar): `.xbgst/inventory/census.tsv` (M01 `grok,agent` same md5 is **stale**; live `grok` ≡ `grok-titanium`, `agent` is stock 1.0.8)
- Routing SSoT: `plugins/xbgst-stack/docs/model-routing.md`
- L3 env vs crate: hangar `SSoT_TABLE.md` + `~/.xbgst/env.l3-sekhmet.sh`
- Reviewer: livepatch_applied **PASS** (0001–0005, ads-kill yes); grok≡grok-titanium **PASS**; grok≡agent **FAIL**; xask≠xask-l3 **PASS**; orch fixture **FAIL**; OpenCode GP/explore disable **PASS**; codex≠titanium **PASS**
- Critic: kill 0–4 as a host score; kinds on layer rows
- Connector: keep names / layers / aliases unmerged; four Codex-shaped names; four Kimi-shaped names

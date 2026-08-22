---
description: Grok-host crossbreed godspeed orchestrator — gx-* runners xask-first (sekhmet/titanium, service_tier=fast). Spawn the-planner then judge rounds (local-first → main).
argument-hint: <task for the judge>
---

# /xbgst — crossbreed godspeed

You are on **Grok Build**. This command is the Grok host **crossbreed** path of xbrd-godspeed. Judge stays Grok. Specialists stay named `gx-*` runners that **always** offload non-trivial reasoning to PATH `xask`.

`/xgs` is the native-only sibling (no xask). This is **not** that path.

## Do this immediately

1. Load skill **xbgst** (`Skill` / skill file under the installed plugin or `~/.grok/skills/xbgst`).
2. Follow that skill exactly for `$ARGUMENTS` (or the user task) with **`mode: xbgst`**.
3. **Round 0:** spawn `the-planner` first. Planner **loads skill `wwkd`**. Wait for plan artifact. Planner does not xask.
4. Then judge: name axes → parallel specialists (always include `connector`) → Pareto → ship on APPROVED.

## Hard rules (Grok host)

- **Crossbreed / xask-first.** Spawn native Grok subagent types from this plugin (`scout`, `reviewer`, `labrat`, `executor`, `connector`, `distiller`, `simplifier`, `the-revenger`, `sentinel`, `critic`, `mutation-tester`, `scribe`, `the-planner`, `the-janitor`, …). Every consult-role dispatch is a **runner** whose FIRST tool-using step is PATH `xask` with **flags that name the target CLI** (never spawn type `xask`; never `xask-l3` as FIRST). ChatGPT default is **stock xbreed** (`xask --gs cdx '<q>'`). Spark is opt-in: `xask --spark --gs --service-tier fast cdx '<q>'`. Other CLIs: `grok`, `qwen38`, `kimi`, `gemma`, `ds-flash`. Spark extract is **result.json stdout** (never the sekhmet envelope; see `references/xbreed-shared.md` Extract); stock lanes quote xask stdout. On failure `BLOCKED: xask [reason]` and continue. **No Claude TeamCreate.**
- **Exception E2:** dispatch `the-revenger` as `cdx-revenger-*` via stock `codex exec` (never `codex-titanium`; Titanium is sekhmet L3 only). `gx-revenger-*` inherit remains the fallback. gx-* never exec titanium themselves.
- **Never** `general-purpose` or `explore` (banned; livepatch hard-bans them).
- **Local-first:** after each judged milestone APPROVED → commit project files → `git push -u origin main` (SSH). No fork→PR default. No force-push of `main`.
- **Language:** match the repo. No Rust lock.
- **Connector** mandatory every PROPOSE round after Round 0.
- Godspeed injection on every initial or follow-up teammate dispatch: prepend byte-exact `ssot/godspeed-core/directive.md` (quintessential subagent form), normalize repeated terminal markers, and end the full prompt exactly once with literal `| godspeed`.
- Handoff field: `mode: xbgst`.

## Optional substrate route

L1 remains the Grok judge and sole scheduler/integrator. Default to named native `gx-*` specialists. Route long-lived intermodel work to an existing OpenAI-backed PrimeAgent only as an attachable **L2-loop**; first name a `gx-*` route owner and send `route_id`, `parent`, `task`, `scope`, `allowed_actions`, `return`, and `stop`. The return is evidence for L1, never a Pareto/`APPROVED`/ship decision. Do not allow PrimeAgent child fan-out unless the route says so.

Use `xbrd-selector` only as the separate L2-select lane when it is installed; PrimeAgent never substitutes for it. sekhmet is always-on for /xbgst parallel fan-out; PrimeAgent never proxies L3 and never invokes `codex-titanium`. If PrimeAgent or its user-owned OpenAI ChatGPT/Codex OAuth is absent, continue through the native `gx-*` path. Never require PrimeAgent in the host inventory or installer. See skill **xbgst-primeagent** for attach/send/resume mechanics.

## Aliases

| Command | Meaning on Grok |
|---------|-----------------|
| `/xbgst` | Crossbreed (this file → skill). PATH `xask` first. sekhmet fan-out. |
| `/xgs` | Native-only. Specialists do not call xask. |
| `/xbt` / `/xbreed` / `/xb` | Same as `/xbgst` (xbgst-mode / xask-first). Consult table: `commands/references/xbreed-shared.md` |

## Livepatch

Bundled under this plugin. Prefer `/xbgst-livepatch` or skill **xbgst-livepatch** after first install.

## Not in this marketplace

`heuer-planning` is on **ds4cc**, not xbgst-stack. Critic inlines ACH-style methods if the skill is absent.

# Model routing (probe-gated)

**SSoT:** marketplace plugin **xbgst-stack** (`plugins/xbgst-stack` in grok-marketplace).  
**Not SSoT:** installed plugin tree, gdsd crate, `prime-agent-l2.sh`, xbrd-grok skill mirror.

**Judge / xbgst** runs on **Grok**. This file freezes live-probe results (M07) and the optional substrate boundary. It does not rewrite the Grok-native roster into multi-provider: OpenAI-backed PrimeAgent is an L2-loop runtime, not a roster role. Exception **E2** is `the-revenger` only.

## Binary split (load-bearing)

| Binary | Who may invoke it | Who must not |
|---|---|---|
| `xask` (PATH protocol) | optional user-ON FIRST Bash inside named `gx-*` / grok-CLI subleads (consult table) | sekhmet L3; spawn argv; judge-as-xask; Gemma/`g`/`gemini`; gx-* FIRST `xask grok` |
| `xask --gs grok` (lead oneshot) | host/script oneshot only (`grok --always-approve --no-subagents --verbatim -p`) | gx-* FIRST bash; L2 teammate consult; titanium |
| `xask … cdx` (alias of `codex`) | L2 consult → `xbreed ask codex` → stock ChatGPT Codex | Token Plan `-p`; `codex-titanium`; sekhmet |
| `xask --gs qwen38\|ds-flash\|ds-pro` | L2 Token Plan **opt-in** → wrappers `codex-qwen38` / `codex-ds-*` → `codex -p <profile>` (xask unsets `CODEX_BIN`) | default Codex; L3 spark; gx-* without user naming the profile |
| `xbreed` (ask CLI; stock ChatGPT `codex`) | invoked by protocol `xask` for `codex`/`cdx` | honor `CODEX_BIN`; `codex-titanium`; Token Plan `-p`; L3 workers |
| `codex` (stock `@openai/codex`) | Daybreak Blue; Exception E2 `cdx-revenger-*`; `xbreed ask codex`; Token Plan only via `-p` / wrappers | sekhmet L3 workers (use `codex-titanium`) |
| `xask-l3` (sekhmet shim; bare `sekhmet run`, Titanium default) | **sekhmet L3 only** | gx-* FIRST tool; E2; L1 judge; protocol `xask` lane |
| `codex-titanium` (Titanium ELF) | **sekhmet L3 workers only** | Daybreak; L2 (`prime-agent-l2.sh` / `prime-agent`); Grok-host E2; `xbreed ask` |
| direct `prime-agent --provider openai-codex` | optional attachable L2-loop behind a named `gx-*` route owner; existing user-owned ChatGPT/Codex OAuth only | L1 judge, L2-select, L3; never exec `codex-titanium` |
| `prime-agent` via `scripts/prime-agent-l2.sh` | legacy xAI-only compatibility path (fail-closed) | OpenAI route; never wrap or exec `codex-titanium` |

L2 substrate must **never** be invoked with Titanium. Titanium stays on the L3 sekhmet plane. L1 xbgst remains the sole scheduler, Pareto/`APPROVED` authority, integrator, and shipper. The direct OpenAI lane receives the exact `route_id` / `parent` / `task` / `scope` / `allowed_actions` / `return` / `stop` envelope and defaults child fan-out off. Credentials and provider setup stay user-owned; missing PrimeAgent or ChatGPT/Codex OAuth falls back to the native named `gx-*` path.

## Probe-gated lanes

| Lane | Model id | Canary | Probe |
|------|----------|--------|-------|
| token-plan | qwen3.8-max | XBGST_QWEN38_OK | M02 PASS HTTP 200 (token-plan host; `DASHSCOPE_API_KEY` via `op run`) |
| token-plan | deepseek-v4-flash-0731 | XBGST_DSFLASH0731_OK | M03 PASS HTTP 200 same key |
| token-plan | deepseek-v4-pro-0813 | XBGST_DSPRO0813_OK | M04 PASS HTTP 200 same key (no unversioned alias) |
| daybreak lab | gpt-daybreak-blue-latest | XBGST_DAYBREAK_BLUE_OK | M05 PASS via stock `codex exec` (no `service_tier`; not titanium) |

Daybreak is **lab/defensive** ping, not default revenger.

## Token Plan (Alibaba / DashScope)

- **Canonical env:** `DASHSCOPE_API_KEY` (E3). Inject with `op run`. Do not commit the key. Do not claim Catalyst grants.
- **Working base URL:** `https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`
- **Fallback (not needed after key rotate):** `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
- **Vault item (name only):** `DashScope Token Plan Team (intl sk-sp)` in vault `AgentAutomation`, field `credential`
- **Status:** M02–M04 live completions **PASS** (HTTP 200 + canary + response `model` equals requested id).
- **Exact model ids:** `qwen3.8-max`, `deepseek-v4-flash-0731`, `deepseek-v4-pro-0813`
- **Do not alias unversioned** `deepseek`. No `deepseek`, `deepseek-v4`, or silent remap.

Intended request shape (not executed by `scripts/route-smoke.sh`; no secrets in this tree):

```
POST {base}/chat/completions
Authorization: Bearer $DASHSCOPE_API_KEY
{"model":"<exact id>","messages":[{"role":"user","content":"<canary>"}],"enable_thinking":false}
```

## Daybreak Blue (lab)

- Slug: `gpt-daybreak-blue-latest`
- Command: `codex exec -m gpt-daybreak-blue-latest` (stock Codex CLI)
- **Do not pass `service_tier`** (empty `service_tiers`; `service_tier=fast` is wrong for Blue).
- **Never `codex-titanium`** for this lane.
- **Lab / defensive ping only.** Not default revenger. Not a roster pin.

## Exception E2 — the-revenger → cdx

- Spawn is outbound **stock** `codex exec` named `cdx-revenger-*`, **not** Grok `spawn_subagent`, **not** `codex-titanium`.
- Overfit: `codex exec -m gpt-5.6-luna` RECON of `scripts/prime-agent-l2.sh` → `XBGST_CDX_REVENGER_OK`.
- SKILL.md dispatch table **row** is `cdx` plus this Exception E2 footnote.
- `agents/the-revenger.md` stays `model: inherit` (`gx-revenger-*` fallback). Do not edit that agent file for this freeze.
- Daybreak Blue is not this lane.
- Titanium remains sekhmet L3 only.

## Isolation (do not widen)

| Id | Rule |
|----|------|
| E1 | Do not patch `scripts/prime-agent-l2.sh` provider pin. Wrapper remains xAI-only fail-closed and must not consume OpenAI credentials. The direct `openai-codex` lane uses existing user-owned PrimeAgent ChatGPT/Codex OAuth outside the wrapper; never overwrite, copy, or automate login for it. `tests/test-prime-agent-l2.sh` and `tests/test-openai-primeagent-routing.sh` must PASS. L2 must never exec `codex-titanium`. |
| E2 | Revenger-only roster split via stock `codex` (above). |
| E3 | `DASHSCOPE_API_KEY` canonical. |
| E4 | Daybreak is lab/defensive via stock `codex`, not default revenger. |
| E6 | Marketplace SSoT is this plugin tree. Do not edit the installed plugin. |

## Policy smoke

```
bash scripts/route-smoke.sh
```

Policy greps only (no `op`, no `curl`, no secrets), then both `tests/test-prime-agent-l2.sh` and `tests/test-openai-primeagent-routing.sh`.

Pointer: xbrd-grok `docs/model-routing.md` → this file.

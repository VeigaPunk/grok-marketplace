# Model routing (probe-gated)

**SSoT:** marketplace plugin **xbgst-stack** (`plugins/xbgst-stack` in grok-marketplace).  
**Not SSoT:** installed plugin tree, gdsd crate, `prime-agent-l2.sh`, xbrd-grok skill mirror.

**Judge / xbgst** runs on **Grok**. This file freezes live-probe results (M07). It does not rewrite the Grok-native roster into multi-provider. Exception **E2** is `the-revenger` only.

## Binary split (load-bearing)

| Binary | Who may invoke it | Who must not |
|---|---|---|
| `codex` (stock `@openai/codex`, omarchy/npx wrapper) | Daybreak Blue lab ping; Exception E2 `cdx-revenger-*` | sekhmet L3 workers |
| `codex-titanium` (Titanium ELF) | **sekhmet L3 workers only** | Daybreak; L2 (`prime-agent-l2.sh` / `prime-agent`); Grok-host E2 |
| `prime-agent` via `scripts/prime-agent-l2.sh` | optional long-running already-spawned `gx-*` (xAI fail-closed) | never wrap or exec `codex-titanium` |

L2 substrate must **never** be invoked with Titanium. Titanium stays on the L3 sekhmet plane.

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
| E1 | Do not patch `scripts/prime-agent-l2.sh` provider pin. Wrapper remains xAI-only fail-closed. `tests/test-prime-agent-l2.sh` must PASS. L2 must never exec `codex-titanium`. Host `~/.prime/agent/auth.json` must stay free of openai/anthropic/github (stock Codex OAuth lives in `~/.codex/auth.json`). |
| E2 | Revenger-only roster split via stock `codex` (above). |
| E3 | `DASHSCOPE_API_KEY` canonical. |
| E4 | Daybreak is lab/defensive via stock `codex`, not default revenger. |
| E6 | Marketplace SSoT is this plugin tree. Do not edit the installed plugin. |

## Policy smoke

```
bash scripts/route-smoke.sh
```

Policy greps only (no `op`, no `curl`, no secrets), then `tests/test-prime-agent-l2.sh`.

Pointer: xbrd-grok `docs/model-routing.md` → this file.

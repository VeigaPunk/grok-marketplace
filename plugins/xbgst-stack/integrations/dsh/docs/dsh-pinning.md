# DSH pinning & ownership contract (xbgst ↔ deepseek-harness)

Status: **contract-first, backend disabled by default** (refinement-freeze compliant).
Owner: `plugins/xbgst-stack/integrations/dsh/`. No second orchestrator, no L3 embedding.

## Pin facts (see `../pin.env`)

| Field | Value |
| --- | --- |
| Package | `@deepseek-ai/dsh` (bare `deepseek-harness` is a 0.0.1 placeholder trap — never use) |
| Version | `0.1.0-rc.8` exactly (`latest` already drifted to `0.1.1-rc.2`; pre-1.0 = breaking SQLite changes) |
| Tarball sha512 | see `pin.env:DSH_TARBALL_SHA512` (verified against registry integrity `VQU5Nlom…`) |
| Node manager | **fnm only** (`eval "$(fnm env --shell bash)"` before any node/npm work; mise drifts to 26.x and is not the stack manager) |
| Worker profile | `xbgst-worker` = `@deepseek-ai/dsh-base` + `@deepseek-ai/dsh-headless` bundles + `profiles/xbgst-worker/cordis.patch.yml` hardening layer |

## Effective-config hashing

Pin verification command (run under fnm):

```bash
set -a; . integrations/dsh/pin.env; set +a
export DSH_HOME="$PWD/integrations/dsh/.dsh-home"   # isolated home, never ~/.dsh
dsh --profile xbgst-worker --dump-config | sha256sum
```

The hash MUST match the value recorded in `evidence/dsh-l2-rc8-install.md`.
Any drift (version bump, patch edit, bundle change) invalidates the pin and requires
re-recording evidence before any live worker run.

## Ownership boundary

| Layer | Owns |
| --- | --- |
| xbgst (L1) | axes, planner/judge, Pareto/evidence gate, 16-agent lease, APPROVED + separate ship authorization |
| DSH (L2) | per-worker model loop, tools, sandbox policy enforcement, append-only session trace, subprocess cleanup |
| Bridge (planned) | stable request/result schema, correlation IDs, cancellation translation (= close & reap; no mid-turn cancel in rc.8 SDK) |
| Sekhmet (L3) | pure ≤64-job substrate; **no DSH/MCP/session machinery installed inside L3** |

## Worker-profile hardening (`profiles/xbgst-worker/cordis.patch.yml`)

Disabled at the plugin layer (leaf cannot become a second orchestration graph):
`goal*`, `plan-mode`, `subagent*`, `workflow*`, `jobs`/`tool-jobs`,
`user-questions`, `session-title-llm`, `web`/`web-search-deepseek`/`tool-web`.

Model routing (aliases, never raw names): `grok-high` → pi-ai catalog route
`xai` / model id `grok-4.5` / reasoning `high`; `grok-fast-low` → same id /
reasoning `low`. Credentials via `apiKeyEnv: XAI_API_KEY` reference only — no
secret material ever enters this file.

Sandbox: deployment default pinned `read-only` (fail-safe). Role map when live:
scout/reviewer/distiller = read-only; executor/scribe = workspace-write in a
dedicated scope; mutation testing = disposable copy, never canonical checkout.
Headless mode means approval requests FAIL (nobody to approve) — that is the
intended `approval: never` semantics; nothing is autoapproved.

## Known limits (rc.8)

- No mid-turn cancel in the client SDK: cancellation = close process + reap.
- Local-hosted ≠ local-only: models/tools may transmit externally; network
  confinement needs host/container policy beyond DSH's file sandbox.
- Codex/Claude Code one-shot bundles stay DISABLED in production profiles.
- Web UI, if ever used diagnostically: bind `127.0.0.1`, `--no-open`; never fleet UI.

## Rollout gates (unchanged from refinement freeze)

P0 record contract (this file, disabled) → post-P4 shadow mode → canary one
read-only labrat → reviewer/distiller → isolated executor (commit-only) →
direct-main only after durable `APPROVED` **and** distinct `AUTHORIZED_TO_SHIP`.
Required gate list lives in the xbgst refinement map; contract tests enforce:
clean-profile install, effective-config hash, banned-role rejection,
17th-worker rejection, timeout w/o orphan, path/symlink escape, secret redaction.

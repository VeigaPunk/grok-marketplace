# Evidence draft — OpenAI PrimeAgent as optional xbgst L2-loop

Date: 2026-08-21
Scope: `skills/xbgst/SKILL.md`, `commands/xbgst.md`, `commands/references/xbreed-shared.md`, the optional `xbgst-primeagent` entrypoint docs, and the load-bearing `docs/model-routing.md` boundary. No livepatch, host inventory, wrapper, or required installer changes.

## Policy boundary

- L1 remains the Grok `xbgst` judge. Only L1 names/scores axes, runs Pareto, emits `APPROVED`, schedules routes, integrates returns, and ships.
- OpenAI-backed PrimeAgent is an optional, attachable **L2-loop** for long-running intermodel work and bounded delegation. It is never the judge, L2-select, or L3.
- `xbrd-selector` is the distinct L2-select lane. PrimeAgent must not imitate selection when that lane is absent.
- `sekhmet` is the distinct bounded L3 fan-out lane. PrimeAgent must not proxy it, and L2 must never invoke `codex-titanium`.
- PrimeAgent is not a prerequisite. Missing binary, credentials, or provider setup falls back to the existing Grok L1/native-specialist path; it must not promote L2 or block the judge.
- Provider credentials and OpenAI ChatGPT/Codex OAuth setup are user-owned and remain outside this plugin. No `/login` automation or credential material belongs in the skill.
- PrimeAgent stays absent from `HOST-ORCH-INVENTORY.txt` and from the required overlay/install list. Window-3 host-orch shipping therefore stays PrimeAgent-free.

## Baseline evidence (before edits)

1. `skills/xbgst/SKILL.md` keeps the judge on Grok and has one optional-L2 paragraph, but that paragraph is xAI-only and does not give an L1 decision table for L2-loop vs L2-select vs L3.
2. `commands/xbgst.md` has no PrimeAgent L2-loop route or exact dispatch envelope.
3. `commands/references/xbreed-shared.md` has only native specialist rows and no substrate route table.
4. `skills/xbgst-primeagent/SKILL.md` and `commands/xbgst-primeagent.md` describe only the legacy xAI wrapper, so they contradict an OpenAI-backed first-class optional lane.
5. `docs/model-routing.md` has a load-bearing binary table that lists only the xAI wrapper and an old one-test smoke description; it must distinguish the direct OpenAI lane from the unchanged legacy wrapper.
6. `scripts/install-host.sh` explicitly skips `xbgst-primeagent` and `xbgst-primeagent.md`. This is the desired optional/non-inventory boundary and must remain unchanged.
7. `HOST-ORCH-INVENTORY.txt` does not list PrimeAgent. It must remain unchanged.
8. Marketplace `scripts/install-xbgst-stack.sh` contains no PrimeAgent requirement and must remain unchanged.
9. `prime-agent --version` returned `0.7.4`.
10. `prime-agent model list` exposed provider `openai-codex` with OAuth-capable OpenAI models.
11. Bounded live probe from disposable `/tmp/xbgst-prime-openai.*`, with no tools and no saved session:

   ```text
   prime-agent --provider openai-codex --model gpt-5.4 --thinking minimal --no-tools --no-session -p <exact-canary>
   XBGST_OPENAI_L2_OK
   ```

12. Coordination response from `l2-openai-roster`: use exact Route ID/scope/return/stop envelopes; keep scheduling/integration root-owned; forbid child fan-out unless the route authorizes it; absence falls back rather than promoting L2.

## Proposed dispatch rule

| Need | Route | Authority boundary |
|---|---|---|
| Normal proposal/review/implementation | native named `gx-*` specialist | L1 schedules and judges |
| Long-lived intermodel exchange, attach/resume, or bounded delegated work | optional OpenAI-backed PrimeAgent L2-loop | exact route envelope; return evidence to L1; no Pareto/APPROVED/ship; no child fan-out unless allowed |
| Ranked selection among bounded candidates | `xbrd-selector` L2-select, only if separately present | PrimeAgent never substitutes; absent selector means L1 judges directly |
| Broad bounded swarm | sekhmet L3, only when explicitly escalated | separate cap/contract; PrimeAgent and `codex-titanium` never cross into each other's lanes |

Every L2-loop dispatch must include: `route_id`, `parent`, `task`, `scope`, `allowed_actions`, `return`, and `stop`. L1 remains the sole scheduler and integrator.

## Applied small edits

- Replaced the xAI-only paragraph in the judge skill with the route decision table and the required envelope.
- Added the optional-L2 route to `/xbgst` and the shared reference.
- Updated the optional `xbgst-primeagent` skill/command docs to make existing OpenAI ChatGPT/Codex OAuth (`openai-codex`) the preferred OpenAI lane while retaining the existing xAI wrapper as a legacy compatibility path.
- Bound the direct command to required `ROUTE_CWD`, placed it before the message-only `--`, and restored telemetry-off environment settings. The writing route must use a disjoint path/worktree rather than shared `main`.
- Updated the load-bearing `docs/model-routing.md` table and smoke description so the direct OpenAI lane and legacy xAI wrapper no longer conflict.
- Left `scripts/prime-agent-l2.sh` unchanged: it remains an explicitly xAI-only compatibility wrapper rather than the OpenAI route.
- Added `tests/test-openai-primeagent-routing.sh` and wired it into the existing policy smoke, including checks for `ROUTE_CWD`, telemetry, and model-routing coherence.

## Validation results

- Extracted OpenAI command block `bash -n` plus a fake-binary argument/environment probe — PASS: explicit `--cwd` precedes `--`, route text stays message-only, and telemetry variables equal `0` / `1` / `1`.
- `bash tests/test-openai-primeagent-routing.sh` — PASS.
- `bash scripts/route-smoke.sh` — PASS, including the existing xAI wrapper fail-closed test.
- Marketplace `./scripts/smoke-gates.sh` — PASS, including plugin validation, both livepatch gates, inventory checks, installer checks, and SSoT sync checks.
- `bash -n` for the touched/new shell policy gates and protected installers/wrapper — PASS.
- Plugin and marketplace installer `--help` probes — PASS.
- `git diff --check` — PASS.
- Protected-path assertion — PASS: no diff for `HOST-ORCH-INVENTORY.txt`, `scripts/install-host.sh`, marketplace `scripts/install-xbgst-stack.sh`, `scripts/prime-agent-l2.sh`, or `livepatch/`.
- `l2-openai-roster` review — no conflict; direct OpenAI L2-loop remains distinct from the xAI compatibility wrapper, L2-select, and bounded L3.
- Independent `xbgst-policy-auditor` re-audit — PASS after the CWD/telemetry and load-bearing routing-document fixes; no remaining authority, layer-separation, envelope, fallback, compatibility, protected-path, or command-syntax issue.

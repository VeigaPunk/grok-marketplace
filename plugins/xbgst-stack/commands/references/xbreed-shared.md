# Shared orchestration protocol (Grok host)

**Canonical judge:** skill **xbgst** (load that first). This file is a short reference for evidence + naming used by Grok specialists.

**Not used on Grok:** Claude TeamCreate, `advisor()`, sonnet/opus model pins, `~/.claude/*` paths. **Never spawn type `xask`.** PATH `xask` is the consult CLI; spawn stays `gx-*`.

**Modes:** `/xgs` = native-only (no xask). `/xbgst` (SSoT) and `/xbreed-team` (slash clone) load skill **xbgst** — xbgst-mode (PATH `xask` first; flags name the target CLI; hangar FIRST for **every** gx-* consult = Cursor Ultra gravy `xask --provider cursor --model-id kimi-k3-max --gs`; named routes `xask --gs kimi`, `xask --gs ds-pro`, `xask --gs qwen38` are not hangar default; `cdx` is OpenAI-only; `--spark` opt-in L3 sekhmet/`codex-titanium`/`service_tier=fast`).

## Godspeed injection (every teammate)

`ssot/godspeed-core/directive.md` in the xbgst-stack plugin is the sole canonical dispatch form. Do not maintain an inline, compact, or paraphrased copy here.

Every initial dispatch and every follow-up / resume / `send_message` must:

1. prepend the complete bytes of canonical `directive.md` verbatim as the first prompt section;
2. add the role task or handoff without changing those bytes;
3. strip any terminal copies of `| godspeed`, then append one final `| godspeed`; and
4. send nothing after it, so the full prompt ends exactly once with that literal suffix.

This invariant covers native `gx-*` teammates, Round 0 planner, recursive sub-leads, outbound revenger dispatch, and optional substrate delegation. A host overlay may be used only when byte-identical to the packaged directive. If the canonical file cannot be read, fail the dispatch closed rather than inventing a replacement. Subagents never receive `filter.md` or `velocity.md`.

## Dispatch table (Grok)

| Axis family | Role | Model | Tools |
|---|---|---|---|
| Research | `scout` | grok | web_search, browse, X search, Grep/Read |
| Correctness | `reviewer` | grok | Read, Grep, Bash tests |
| Empirical | `labrat` | grok-fast | Bash / one-shot probes |
| Implementation | `executor` | grok-fast | Edit/Write/Bash (repo language) |
| Cross-axis | `connector` | grok | multi-axis analysis — **every PROPOSE round** |
| Dedup | `distiller` | grok-fast | synthesis before Pareto |
| Deletion | `simplifier` | grok | delete + retest |
| RE | `the-revenger` | cdx | observe-map-reproduce (Exception E2; stock `codex exec`; `cdx-revenger-*`; never titanium) |
| Security | `sentinel` | grok | adversarial scan |
| Planning | `the-planner` | grok | Round 0 first; WWKD inline |
| Design attack | `critic` | grok | ACH-style (heuer skill optional/ds4cc) |
| Mutation | `mutation-tester` | grok | mutate-run-revert |
| Docs | `scribe` | grok-fast | ship notes |

## Substrate route table (L1 decides)

| Need | Layer | Rule |
|---|---|---|
| Native proposal/review/implementation | L1 → named `gx-*` | default |
| Long-lived intermodel exchange or bounded delegation | optional OpenAI-backed PrimeAgent **L2-loop** | attachable user-owned runtime; exact `route_id` / `parent` / `task` / `scope` / `allowed_actions` / `return` / `stop`; no judge authority or unapproved child fan-out |
| Cursor-agent write+shell FSD subprocess | optional **xbgst-cursor L2-fsd** | hangar `scripts/cursor-agent-l2.sh` → orch `bin/xbgst-cursor-run.sh`; workspace `/home/vgpnk/Projects/xbgst/xbgst-cursor`; print-argv default; exec only `XBGST_CURSOR_EXEC=1`; catalog pin is `cursor-agent --model <cli-id>` / `XBGST_CURSOR_MODEL` (not xask `--model-id`); refuse `--mode ask`/`--force`/`--yolo`/`--plugin-dir`/argv0=`agent`; envelope documented not executed; surface stays trigger/forward |
| Ranked bounded choice | `xbrd-selector` **L2-select**, if separately present | PrimeAgent never substitutes; absent means L1 selects |
| Broad bounded fan-out | sekhmet **L3**, always-on under `/xbgst` | `/xgs` in-process only; PrimeAgent never proxies L3 or invokes `codex-titanium` |

L1 xbgst remains sole scheduler, Pareto judge, `APPROVED` authority, integrator, and shipper. PrimeAgent and its OpenAI OAuth are optional user tooling, never host-orch inventory/install requirements. Absence falls back to the named native `gx-*` path. **xbgst-cursor L2-fsd** is an optional sibling, not a PrimeAgent replacement. Surface `xbgst-cursor-agent-surface` stays trigger/forward.

**Banned:** `general-purpose`, `explore`.

**OS teammates:** `specialist` tool (gx-teams) + `SendMessage` tool (JSONL log). `spawn_subagent` is in-process only.

## xbgst-mode xask consult (any CLI via flags)

`/xgs` specialists skip this section (native tools only). `/xbgst` specialists are runners: FIRST Bash is PATH `xask` **with flags that name the target CLI**, then they continue with native tools. Never spawn type `xask`. Never use `xask-l3`. Do not treat `xbreed team mailbox` as a live DM (it is a log).

`xask` is a dispatcher, not an xbrd-spark-only lane. Spark is **opt-in**. Hangar FIRST for **every** gx-* consult is Cursor Ultra gravy (`xask --provider cursor --model-id kimi-k3-max --gs`). Named routes: native Kimi OAuth (`xask --gs kimi`), Token Plan DeepSeek (`xask --gs ds-pro`), Token Plan Qwen (`xask --gs qwen38`). `cdx` is OpenAI-only. Pin **fast servicing only on models that advertise it** (`config/xask-models.json` `service_tiers`). Token Plan qwen/ds, grok, kimi, gemma, Daybreak, `gpt-5.4-mini`, and Cursor Ultra (`kimi-k3-max`) stay `default`; `--service-tier fast` on those ids fails closed.

```
xask --gs [flags] <route> '<q>'
```

Consult classes (copy-paste by flag; Role FIRST table below):

| Class | Exact argv | Router |
|---|---|---|
| Cursor Ultra (OAuth, cursor-agent) — **hangar FIRST (every gx-* consult)** | `xask --provider cursor --model-id kimi-k3-max --gs '<q>'` | `cursor-agent -p --mode ask --trust --output-format text --model kimi-k3-max`. `--mode ask` is read-only consult. `--trust` skips Workspace Trust Required. Never `--yolo`/`-f`. Never `--spark` on this pin. Never Claude. Never `auto`. Full-agent L2-fsd is `xbgst-cursor` (print-first `scripts/cursor-agent-l2.sh`, `-p`, no ask). Surface `xbgst-cursor-agent-surface` stays trigger/forward. Optional pool pins: `composer-2.5`, `cursor-grok-4.6-high-fast`. |
| Token Plan DeepSeek — **named route** | `xask --gs ds-pro '<q>'` | Token Plan wrappers; **no** `--service-tier fast`; not hangar FIRST |
| Token Plan qwen3.8-max — **named route** | `xask --gs qwen38 '<q>'` | `codex-qwen38`; **no** `--service-tier fast`; named/opt-in not hangar FIRST |
| Kimi (OAuth, native CLI) — **named route** | `xask --gs kimi '<q>'` | `kimi -m kimi-code/k3 -p` (managed:kimi-code). Pay-as-you-go is `--model-id moonshotai/…`. |
| ChatGPT / OpenAI only (`cdx`) | `xask --gs --service-tier fast cdx '<q>'` | stock `xbreed ask codex` (sol advertises fast). Not the default FIRST consult. |
| L3 spark | `xask --spark --gs --service-tier fast cdx '<q>'` | sekhmet L3 → `codex-titanium` (spark advertises fast) |
| Grok oneshot | `xask --gs grok '<q>'` | `grok --always-approve --no-subagents --verbatim -p` |

| Local Gemma | `xask --gs gemma '<q>'` | `xbreed ask gemma` |
| Sol review (OpenAI) | `xask --gpt55 --gs -e low cdx '<q>'` | stock gpt-5.6-sol |

`--substrate sekhmet` is the same spark opt-in as `--spark`. `--substrate stock` keeps ChatGPT on xbreed. Do not `xask grok` as FIRST bash from a grok teammate (grok-consults-grok); pick another route.

| Role | xbgst-mode FIRST |
|---|---|
| `scout`, `connector`, `the-planner`, `labrat`, `executor`, `reviewer`, `critic`, `sentinel`, `mutation-tester` | `xask --provider cursor --model-id kimi-k3-max --gs`. Planner: `xask --provider cursor --model-id kimi-k3-max --gs -- "<WWKD mapping>" "No prior context." wwkd` — positional `wwkd` loads the skill; the consult **is** the mapping, not a question. Never `--spark` on this pin. Never default `cdx`. Never Claude. Never `auto`. `--spark` only when L3 is requested. `--gpt55 --gs -e low cdx` only when the review target is OpenAI |
| `distiller`, `scribe`, `simplifier`, judge/`xbgst`, `the-janitor`, `the-musketeer` | **no consult** |
| `the-revenger` | Exception E2 stock `codex exec -m gpt-5.6-luna` — **not** xask, not Token Plan, not titanium |

`xask --spark` is L3 `sekhmet run` (`gpt-5.3-codex-spark` primary, `gpt-5.6-luna` fallback, inherit `CODEX_BIN=codex-titanium`, `XBRD_SPARK_SERVICE_TIER=fast`). Bare `xask cdx` does **not** auto-spark. gx-* never exec `codex-titanium` themselves.

Forbidden from gx-* FIRST bash: `xask-l3`; `xask --spark grok\|qwen38\|ds-*\|kimi\|gemma`; `xask --spark … cursor`; direct `codex-titanium`; exporting `CODEX_BIN` on Token Plan/grok execs (xask must `env -u`).

Fallback: `obs: xask BLOCKED [reason]` then continue in-session. Binary split: `docs/model-routing.md`.

### Extract — spark vs stock vs kimi chrome

Non-spark routes: quote PATH `xask` stdout (the model answer). `--json` / `-o` follow the target CLI. **the-planner:** the consult **is** the mapping. File the **complete** stdout as the plan artifact. `<raw_output>` is the full stdout. Never ellipsize. Never a one-line substring.

**kimi print-mode:** CLI dumps version, thinking CoT bullets (`• The user asks…`), and `To resume this session: kimi -r …` onto the ingested stream. PATH `xask` runs `scripts/xask-kimi-stdout.py` (ds4cc sibling of `xask`) so stdout is the last non-CoT bullet. Chrome stays on stderr. Gate: `tests/test_xask_kimi_stdout.py` (overfit DIRECT_P_OK; no live model). Do not grep the answer token out of CoT — that spoofs PONG. Empty extract must not invent the answer.

### Extract (`xask --spark`) — model answer is not CLI stdout

`xask --spark` CLI stdout is a sekhmet **CollectRecord envelope** (`spark_id`, `result_path`, `provenance`, …). It has **no** `stdout` key. `--json` / `-o` on `--spark` **exit 1**. The model answer is `result.json` field `stdout` under the spark root.

`<raw_output>` must be a literal substring of **that extract** (result.json stdout). Never quote envelope keys, `provenance.cmdline`, or result.json `stderr` (those contain the prompt and can spoof PONG). Empty extract = invalid / `BLOCKED: xask [no result.json stdout]`. Do **not** fall back to pasting CLI JSON.

Do **not** `open(envelope["result_path"])` — that path is operator-controlled. Derive `<sekhmet default_root>/<spark_id>/out/result.json` after validating `spark_id` (`$XBRD_SPARK_ROOT`, else `$XDG_RUNTIME_DIR/xbrd-spark`, else `/tmp/xbrd-spark`). Copy-paste:

```
xask --spark --gs --service-tier fast cdx '<q>' | python3 "$(dirname "$0")/../../scripts/xask-spark-stdout.py"
```

From a consult role, after FIRST bash returns envelope on stdout (usage_limit banners may prefix stdout; helper skips to first `{`):

```
python3 /path/to/xbgst-stack/scripts/xask-spark-stdout.py
```

Gate: `tests/test-xask-midrun-ping.sh` (`XASK_LIVE=0` default).

## Naming

`gx-{role}-{suffix}` e.g. `gx-scout-docs`, `gx-executor-ship`, `gx-connector-r1`.

## Labrat

Spawn `labrat` with a single hypothesis. Parallel labrats are bounded only by the host ceiling (certified at 64). Fire-and-forget. Failure is a finding.

## Distiller

After peer proposals land, spawn `distiller` to dedupe and confidence-score. Preserve each move’s `evidence:` field. Emit `SYNTHESIS_READY` for the judge.

## Pareto filter — evidence schema

Moves without required evidence are **dropped, not scored**.

| Role / axis_family | Required evidence |
|---|---|
| `execution` (executor) | failing + passing test output (red→green); OR diff + rationale if no harness |
| `correctness` / `test-validation` / `security` | test/lint stdout + exit code, or concrete file:line excerpt |
| `empirical` (labrat) | HYPOTHESIS / METHOD / RESULT |
| `deletion` (simplifier) | removed symbols + tests pre/post |
| research / cross-axis / synthesis / planning / adversarial / RE | `evidence: none — <axis reason>` OK when non-executable |

### Evidence audit (judge round summary)

```
EVIDENCE AUDIT: <N> moves with evidence, <M> without, <M> dropped, <K> spoof_flagged
```

### Anti-spoof

If evidence cites file state, require line span + exact excerpt; verify with fixed-string match. Mismatch → `evidence_unverified` → reviewer before accept.

## Judge blinding (light)

Prefer scoring `move_id`s from distiller synthesis before weighting by source role. Late-bind role labels for CONFLICTS routing only.

## Local-first ship (after APPROVED)

```
on main → gates green → APPROVED: <reason> → commit (HEREDOC) → git push -u origin main (SSH)
```

No fork→PR default. No force-push of `main`. Tag `grok-stable` is the channel pin for this marketplace.

## Out of marketplace

- **heuer-planning** → ds4cc (optional for critic)
- Nested `livepatch/scripts/publish.sh` → refuses under this tree (standalone livepatch repo only)

## DESPAWN Protocol

On Grok the closer **is** the identifier (no Claude `SendMessage`):

```
DESPAWN: gx-{role}-{suffix} — signal delivered. Send me shutdown_request.
```

That line is `send_despawn_request`. Judge waits for the freeze roster, then distiller. Do not narrate per-agent completion to the operator.


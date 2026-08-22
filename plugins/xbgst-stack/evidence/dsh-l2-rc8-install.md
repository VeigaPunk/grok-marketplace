# Evidence — DSH L2 rc.8 offline gate + hardened worker profile (2026-08-21)

Judge: xbgst orchestrator (godspeed). Node manager: fnm multishell (`eval "$(fnm env --shell bash)"`), node v24.19.0. All work under isolated roots; no live model calls.

## M01 — Pin manifest

`integrations/dsh/pin.env`: package `@deepseek-ai/dsh`, version `0.1.0-rc.8` exact,
tarball sha512 + registry integrity recorded. Bare `deepseek-harness` on npm is a
0.0.1 placeholder trap — never referenced. `latest` observed drifted to
`0.1.1-rc.2`; pin policy forbids floating refs.

## M02 — Offline gate (fresh roots)

1. `npm pack @deepseek-ai/dsh@0.1.0-rc.8` → tarball
   `deepseek-ai-dsh-0.1.0-rc.8.tgz`, size 33651 B.
   - computed sha512: `550539365a26aca2…96e2f2c694b3cc`
   - registry integrity decoded: identical → **INTEGRITY_MATCH=YES**
2. Isolated install `npm install --ignore-scripts` (453 packages) under
   `$HOME/.cache/xbgst-dsh/` (mktemp-backed /tmp/opencode proved sweep-prone).
3. CLI surface captured: `dsh --version` → `0.1.0-rc.8`; launcher flags
   `--profile/--patch/--dump-config/--dump-default-config`; commands
   `web | plugin | headless one-shot`. Headless app flags: task args only.
4. Profile scaffold: `dsh plugin --profile xbgst-worker add …` requires pnpm
   (installed 11.22.0 under fnm) but **bundle resolution works from the dsh
   installation itself** — private-registry `add` failure is irrelevant;
   bundles declared directly in profile `package.json`.

## Hardened worker composition (offline, `--dump-config`)

Bundles: `@deepseek-ai/dsh-base` + `@deepseek-ai/dsh-headless`.
Patch layer: `profiles/xbgst-worker/cordis.patch.yml`.

Verified against composed tree:

- **22/22 disable patches effective**: goal, goal-round-driver, command-goal,
  tool-goal, plan-mode, subagent, subagent-spawn-in-process,
  subagent-fork-in-process, tool-subagent-control, tool-subagent-list-agents,
  tool-subagent, tool-subagent-fork, tool-subagent-report,
  workflow-worker-thread, tool-workflow, jobs, tool-jobs, user-questions,
  session-title-llm, web, web-search-deepseek, tool-web → all `disabled: true`.
- `sandbox-policy.config.mode: read-only` pinned (fail-safe default retained).
- Model routing: `agent-default-model` → provider `grok-high`, model `grok-4.5`;
  `llm-pi-ai.providers` declares xbgst routes `grok-high` (reasoning high) and
  `grok-fast-low` (reasoning low), both `apiKeyEnv: XAI_API_KEY`, models
  narrowed to catalog id `grok-4.5` (pi-ai ships xai catalog: grok-4.3,
  grok-build-0.1, grok-4.5 — id verified, not invented).
- Telemetry: `session-telemetry-otel` mode defaults to `DISABLED`
  (`process.env.DSH_TELEMETRY_MODE || 'DISABLED'`) — no exporter egress by default.

### Hashes

| Artifact | sha256 |
| --- | --- |
| Baseline composition (empty patch) | `a0a0e9f380872097cb7f8b7356f36433a2afeb8de5044a9e63d4ed47b4bee9f5` |
| **Hardened worker composition (pinned)** | `168e12150989b15399e8a2cf356e541573b7b7b7a7d17ccdc222b74effb2bc20` |

## Security notes discovered during composition

- `approval.policy` defaults to `ask` under `workspace-write`. In headless mode
  nobody can answer an ask → requests fail closed. Do NOT set `never`:
  in DSH semantics `never` means *never ask* (= autoapprove), the opposite of
  the xbgst intent. Documented in `docs/dsh-pinning.md`.
- Landlock LSM enforcement present (`node-addon-landlock-run`); bash-sandbox
  active on Linux, pwsh path disabled off-Windows.
- Session persistence JSONL under `$DSH_HOME/sessions`; SQLite query opens
  `:memory:` with `openAt: never` by default.
- No mid-turn cancel exists in rc.8 client SDK: cancel = close + reap.

## Status

Backend row stays DISABLED in stack state until shadow-mode gates pass.
Live canary (one read-only labrat) blocked behind refinement-freeze P-gates;
contract tests land next (M03/M04/M05).

## M04/M05 — contract gate

`tests/test-dsh-contract.sh` (bash, `set -euo pipefail`, aggregation not
fail-fast) + `integrations/dsh/docs/dsh-events.md` landed 2026-08-21/22.
Gate pins: exact version `0.1.0-rc.8`, sha512/integrity form, hardened +
baseline dump-hash constants, canonical bundles row, floating-ref ban
(`@latest` / `1.1.x` / range ops / `deepseek-harness` trap, comment-stripped),
all 22 disabled ids as exact-match blocks, sandbox `read-only`, grok routing,
both docs present, role-enum immutability (`git diff --quiet HEAD -- agents/`
+ porcelain), zero agent defs in `integrations/`, and live recompute:
`DSH_HOME=<smoke.aWXt>/.dsh-home dsh --profile xbgst-worker --dump-config |
sha256sum` == `168e1215…b2bc20` (executed for real — install present).

Transcript tail (real worktree, fnm node v24.19.0):

```
ok 17 - recomputed dump-config sha256 == pinned hardened composition
FAIL: role enum: agents/*.md are immutable — drift vs HEAD [plugins/xbgst-stack/agents/critic.md plugins/xbgst-stack/agents/sentinel.md plugins/xbgst-stack/agents/the-revenger.md ] untracked[]
ok 18 - integrations/ tree carries zero new agent definitions
CONTRACT GATE RED: 1 violation(s), 18 assertions ok, 0 skips
```

The single violation is **external**: uncommitted follow-up cleanup of HEAD
`da417b1` (godspeed-block deletion in 3 agent files by a concurrent actor,
mtime 19:35 vs HEAD 19:14). Not touched from this workstream. With those files
committed/restored the gate goes green — verified end-to-end against an
identical isolated clone (/tmp/opencode/gate-sim, clean agents/):

```
ok 19 - integrations/ tree carries zero new agent definitions
PASS: dsh contract pin intact (19 assertions, 0 skips)
```

Red→green for M05 itself was observed live: pre-doc run failed exactly at
`FAIL: missing/empty file: …/docs/dsh-events.md`, post-doc run passed.

## M03 — wrapper gate

Fail-closed L2 wrapper `scripts/dsh-l2.sh` + gate `tests/test-dsh-l2.sh`,
cloned from the prime-agent-l2 pattern. Gate is offline: block paths use a
fake `dsh` stub via `DSH_BIN`; the single exec path uses the real pinned
binary with harmless `--dump-config` (no network, no model call).

Exercised sentinels (all exit 2):
- `DSH_TICK_BLOCKED_CWD` — non-disposable cwd rejected
- `DSH_TICK_BLOCKED_PROFILE` — `--profile nope` and `--profile=nope` rejected; only `xbgst-worker` allowed
- `DSH_TICK_BLOCKED_BANNED_TYPE` — `general-purpose`, `explore`
- `DSH_TICK_BLOCKED_LOGIN` — argv token `/login*`
- `DSH_TICK_BLOCKED_NO_BIN` — no `DSH_BIN`, no cached fallback (scrubbed HOME)
- `DSH_TICK_BLOCKED_NO_FNM` — PATH scrubbed of fnm (`env -i`)

Also asserted:
- pass-through with fake bin (`DSH_FAKE_PASS`) and real pinned dsh rc=0,
  dump contains `disabled: true` → seeded hardened cordis.patch.yml applied
  through per-invocation mktemp DSH_HOME
- timeout path: hanging stub TERM'd via process group within
  `DSH_TIMEOUT_SECS=1`; watcher fds detached from caller pipes

Gate transcript (fnm bash):

```
$ bash tests/test-dsh-l2.sh
PASS: dsh-l2 fail-closed + pass-through   # real 0m1.103s, FINAL_RC=0
```

Fixes over first spark cut: `--profile` as final argv no longer trips `set -u`;
timeout reap hardened (`wait || rc=$?`, SIGKILL on deferred-TERM watcher);
watcher stdout/stderr redirected so backgrounded timers never wedge callers.

## Web console (visual substrate probe, 2026-08-21)

- `dsh web --host 127.0.0.1 --port 8787 --no-open`, dedicated `console-home`,
  HTTP 200 verified; musketeer-chrome walk via agent-browser.
- Surfaces observed: notice gate → API-key gate → workspace chooser +
  mode selector (Standard/PTC/Minimal/Creator) → Settings modal
  (General/Models/Plugins/Agent presets + "Open configuration file").
- Agent presets = plugin composition per session ("duplicate and make it
  yours, or let the agent draft one in Creator mode") — same model as our
  profiles/xbgst-worker patch layer; UI can visually author role presets.
- Models tab supports Add provider / **Add a custom provider** → visual path
  for the xAI OpenAI-compatible route alongside pin.env config.
- Boundary holds: console = observation/authoring surface only; xbgst L1
  keeps judging. Screenshots in ~/.xbgst/evidence/dsh-l2-rc8/.

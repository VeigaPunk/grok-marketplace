# DSH visual substrate — R1 Wave-B overfit-one-case (2026-08-22)

OVERFIT_TICK=failed-receipt-rendered

One real headless `xbgst-worker` tick executed through `scripts/dsh-l2.sh` with
`XBGST_DSH_HOME=~/.cache/xbgst-dsh/runs/r1vis`, rendered by `scripts/dsh-view.sh latest`.
The tick FAILED CLOSED at the provider boundary (`MISSING_CREDENTIAL`, XAI_API_KEY absent
on host) — the amendments-§5 expected outcome. Receipt is durable under `runs/r1vis`.

## Command lines

```
cwd=$(mktemp -d /tmp/xbgst-dsh-vis.XXXXXX)          # -> /tmp/xbgst-dsh-vis.izFYsn
mkdir -p ~/.cache/xbgst-dsh/runs/r1vis
cd "$cwd"
DSH_BIN="$cwd/dsh" \
XBGST_DSH_HOME="$HOME/.cache/xbgst-dsh/runs/r1vis" \
DSH_TIMEOUT_SECS=120 \
bash .../xbgst-stack/scripts/dsh-l2.sh --profile xbgst-worker 'Reply with exactly: XBGST_DSH_VIS_OK'
# rc=1, final stderr line:
# dsh: MISSING_CREDENTIAL: llm-pi-ai: no credential for provider route "grok-high";
# its profile resolves XAI_API_KEY, which is not set — …

zstd -dc <session>/session.jsonl.zstd > <session>/session.jsonl   # sibling for viewer
DSH_RUNS_ROOT="$HOME/.cache/xbgst-dsh/runs" bash .../scripts/dsh-view.sh latest   # rc=0
```

`DSH_BIN` shim (disposable cwd, basename `dsh`, wrapper escape hatch used as designed —
all l2 guards still enforced: profile allowlist, cwd gate, runs-prefix allowlist,
timeout/kill-watch, trap). Two runtime adaptations were required, both rc.8 realities
no source edit may paper over:

1. **Arg order.** l2 appends `--patch <yml>` AFTER the positional task; rc.8's
   commander forwards post-operand flags to the headless app, which rejects them
   (`error: unknown option '--patch'`). Shim hoists `--patch` pairs ahead of the
   first operand. Reproduced both directions against the raw binary.
2. **Profile/rc.8 drift overlay** (appended as a second `--patch` layer, deep-merged —
   verified via `--dump-config`):
   - rc.8 route validation refuses catalog-unknown models without explicit
     `api` + `baseURL` → overlay adds `api: openai-completions`,
     `baseURL: https://api.x.ai/v1` to `grok-high`/`grok-fast-low`.
   - rc.8 hand-declared models carry `reasoning: false`; route-level
     `reasoning: high|low` then throws `UNSUPPORTED_REASONING_EFFORT` at dispatch →
     overlay declares `reasoningEfforts: {low: "low", high: "high"}` per model.
   - rc.8 `tool-ralph` (post-pin addition) pends on `workflowEngine`+`subagents` —
     the second-orchestrator services the leaf contract disables → overlay adds
     `- id: tool-ralph / disabled: true` (consistent with leaf contract).

## View output (verbatim)

```
# supporting evidence only — mission ledger authoritative
trace: session-91735828-7475-4fc9-ad07-3010a1684a5f#15
status: unknown
error_category: none
events: turn/start=1 step/start=1 tool/call=0 tool/result=0 assistant/message=0 turn/end=1 other=agent/inbox/spliced,approval/policy,assistant/chunk,permission/preset,request/context,request/header,sandbox/mode,session,session/title,step/end,user/message
file: /home/vgpnk/.cache/xbgst-dsh/runs/r1vis/sessions/--tmp-xbgst-dsh-vis.izFYsn--/session-91735828-7475-4fc9-ad07-3010a1684a5f/session.jsonl
```

Terminal receipt line (rc.8 actual shape):

```json
{"type":"turn/end","seq":15,"time":1787376732574,"data":{"turn":1,"reason":{"kind":"error","error":{"message":"llm-pi-ai: no credential for provider route \"grok-high\" …","code":"MISSING_CREDENTIAL"}}}}
```

## Stage-3 checks

| check | result |
|---|---|
| session dir + terminal event under `runs/` | PASS — 3 sessions landed (2 intermediate config-shape failures, 1 provider-boundary failure), terminal `turn/end` seq 15 on the newest |
| printable `<session-id>#<seq>` | PASS — `session-91735828-…#15` |
| `error_category` nonempty on failure-shape (§5) | **FAIL** — viewer prints `error_category: none`, `status: unknown`. rc.8 nests failure at `data.reason.kind="error"` + `data.reason.error.code="MISSING_CREDENTIAL"`; viewer probes top-level `error_category`/`status` only. Viewer v0 under-classifies rc.8 receipts. |
| `config_sha256 == 168e1215…b2bc20` | N/A — field ABSENT in rc.8 session lines (grep count 0) |
| no writes outside `runs/r1vis` + disposable cwd | PASS — `find ~/.dsh -newer <marker>` empty; `find ~/.cache/xbgst-dsh -newer <marker>` outside r1vis: none |
| binary health probe (`--dump-config` via shim) | PASS — composed tree renders, overlay merge confirmed |

## Findings (the overfit learning — this is why one real tick beats another gate round)

1. **F1 (viewer, classification):** rc.8 terminal failure shape is nested
   (`data.reason.kind`, `data.reason.error.code`), not top-level
   `error_category`/`status`. r0-M04's defensive key-probing covers event NAMES but
   not the failure LOCATION. Viewer needs one added probe path to satisfy §5.
2. **F2 (viewer, container):** rc.8 writes `session.jsonl.zstd`; viewer's scan is
   `*.jsonl` only. Without a decompressed sibling the viewer reports
   `DSH_VIEW_BLOCKED_EMPTY` on a healthy runs root.
3. **F3 (profile drift, rc.8):** three hardening-surface deltas vs the pinned
   profile (route `api`/`baseURL` required; `reasoningEfforts` required for
   route-level reasoning; `tool-ralph` must join the leaf-disabled set). All three
   belong in the repo profile when source edits are authorized; runtime overlay
   content above is the exact minimal delta.
4. **F4 (l2 wrapper):** `--patch` must precede the positional task for rc.8;
   wrapper appends it after `"$@"`. Shim proves the corrected order works through
   every existing guard.

## Interpretation

V-axis works end-to-end mechanically: a real rc.8 headless tick fails closed exactly
where amendments §5 said it must (provider credential boundary), the receipt lands
durably under the runs-prefix allowlist home with zero out-of-scope writes, and
`dsh-view.sh latest` renders banner, `sid#seq`, and event census from it. The §5
`error_category` requirement is NOT yet met by the viewer — two schema drifts
(F1, F2) sit between rc.8's actual receipts and v0's probes. Both are small,
well-localized viewer/profile deltas now pinned by live evidence rather than
scout inference. Verdict: **OVERFIT_TICK=failed-receipt-rendered**, with F1/F2/F3/F4
handed to the next round as the precise patch list.

Receipts (durable, intentionally retained):
`~/.cache/xbgst-dsh/runs/r1vis/sessions/--tmp-xbgst-dsh-vis.izFYsn--/session-{a513f1d7…,af416b11…,91735828…}/`
(`session.jsonl.zstd` as written by rc.8; `session.jsonl` decompressed sibling on the newest).

Teardown: disposable cwd `/tmp/xbgst-dsh-vis.izFYsn` (shim + overlay) removed after
evidence capture; probe dirs `/tmp/xbgst-dsh-probe*` removed. `runs/r1vis` left in place.

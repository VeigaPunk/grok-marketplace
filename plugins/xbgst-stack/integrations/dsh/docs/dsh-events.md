# DSH durable-event normalization — xbgst worker evidence stream (M05)

Scope: how the xbgst bridge consumes DSH rc.8 durable session events and folds
them into the xbgst evidence stream for a worker mission. Pinned runtime:
`@deepseek-ai/dsh` `0.1.0-rc.8`, profile `xbgst-worker` (see `pin.env`,
`docs/dsh-pinning.md`). Event source: session persistence JSONL under
`$DSH_HOME/sessions`; OTel export stays `DISABLED` by default, so JSONL is the
sole durable surface. rc.8 has no mid-turn cancel — cancel is close + reap.

## Authority rule

The **xbgst mission ledger stays authoritative**. The DSH session log is
**supporting evidence only**: it corroborates what the ledger recorded but never
overrides it. A receipt that contradicts the ledger fails reconciliation; the
ledger entry wins and the discrepancy is filed as evidence, not as state.

## Event map

| DSH durable event | xbgst evidence stream | Notes |
| --- | --- | --- |
| `turn/start` | worker started | Opens the per-turn evidence span. |
| `step/start` | worker progress | Heartbeat-grade progress tick. |
| `tool/call` | tool progress | Evidence candidate opens; args hashed, not stored raw. |
| `tool/result` | tool evidence candidate | Artifact hash captured at this boundary. |
| `assistant/message` | worker output | Final IMCP-shaped output payload source. |
| `turn/end` + agent status | settled \| failed \| cancelled | Terminal mapping (below). |

Terminal mapping from `turn/end` plus observed agent status:

- completed normally → **settled**
- error surfaced → **failed** (with `error_category`)
- close/reap without completion (rc.8 cancel semantics) → **cancelled**

## Trace identity

`session id + final sequence number -> immutable trace reference`.

Each session JSONL line carries a monotonic sequence number. At `turn/end` the
final seq is pinned; the pair forms the trace reference `<session-id>#<seq>`.
References are immutable: a re-run produces a new session id, never a rewrite.

## Receipt schema sketch

One receipt per settled turn, appended to the mission ledger's evidence set:

```yaml
receipt:
  status: settled            # settled | failed | cancelled
  imcp_output: {...}         # normalized worker output payload
  evidence: [...]            # evidence candidate ids promoted by the bridge
  artifact_hashes:           # sha256 of each captured artifact
    - <sha256>
  usage:
    input_tokens: 0
    output_tokens: 0
  error_category: none       # none | tooling | sandbox | model | transport | timeout
  dsh:
    version: 0.1.0-rc.8      # must equal pin.env DSH_VERSION
    profile: xbgst-worker
    config_sha256: "168e12150989b15399e8a2cf356e541573b7b7b7a7d17ccdc222b74effb2bc20"
  trace:
    session_id: <session-id>
    seq: <final-seq>          # immutable trace reference = session_id#seq
  trees:
    base_sha256: <sha256>     # workspace tree before the turn
    result_sha256: <sha256>   # workspace tree after the turn
  cleanup: applied            # applied | skipped | failed — sandbox cleanup outcome
```

## Normalization rules

1. Append-only: receipts are never edited; corrections arrive as new receipts.
2. A failed/cancelled turn still yields a receipt with partial evidence and an
   `error_category`; absence of category on failure is a bridge bug.
3. `dsh.config_sha256` in every receipt must equal the pinned hardened hash;
   mismatch invalidates the receipt (worker ran off-contract).
4. `cleanup: failed` escalates to the host — result trees are untrusted.
5. Raw session JSONL is retained alongside receipts as supporting evidence,
   subordinate to the ledger (authority rule above).

Contract gate: `tests/test-dsh-contract.sh` pins version/profile/hash integrity;
this doc is asserted present by the same gate.

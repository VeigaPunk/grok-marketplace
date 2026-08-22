#!/usr/bin/env bash
# dsh-view.sh — receipt viewer v0: render newest worker-session trace (read-only).
# The xbgst mission ledger stays authoritative; this renders supporting evidence only.
# Defensive by contract (r0 M04): rc.8 JSONL field names are NOT assumed — event names
# are probed across candidate keys (event/type/name/kind); unmatched values and
# schema-less lines are surfaced verbatim in the `other=` summary, never guessed.
set -euo pipefail

cmd="${1:-}"
if [[ "$cmd" != "latest" ]]; then
  echo "usage: dsh-view.sh latest [runs-root]" >&2
  exit 2
fi

root="${2:-${DSH_RUNS_ROOT:-/home/vgpnk/.cache/xbgst-dsh/runs}}"

if [[ ! -d "$root" ]]; then
  echo "DSH_VIEW_BLOCKED_NO_ROOT: runs root not found: $root" >&2
  exit 2
fi

# Newest modified plain *.jsonl anywhere under the runs root. Read-only scan.
# rc.8 persists session.jsonl.zstd containers (F2): *.zstd is ignored entirely —
# only decompressed/plain *.jsonl siblings are renderable evidence.
newest="$(find "$root" -type f -name '*.jsonl' ! -name '*.zstd' -printf '%T@ %p\n' 2>/dev/null | sort -rn | sed -n '1s/^[^ ]* //p')"

if [[ -z "$newest" ]]; then
  echo "DSH_VIEW_BLOCKED_EMPTY: no *.jsonl under $root" >&2
  exit 2
fi

session_dir="$(basename "$(dirname "$newest")")"

# Generic scan: each line parsed as a JSON object if possible; non-JSON lines skipped.
# Terminal-ish = event turn/end | session/end, or any line carrying a status field.
mapfile -t r < <(jq -R 'fromjson? // empty' "$newest" | jq -s -r '
  def ev($o): ($o.event // $o.type // $o.name // $o.kind // null);
  def known: ["turn/start","step/start","tool/call","tool/result","assistant/message","turn/end"];
  def term($o): (ev($o) == "turn/end") or (ev($o) == "session/end") or (($o.status? // null) != null);
  # rc.8 nested failure shape (F1): data.reason.kind=="error", code at data.reason.error.code.
  def rkind($o): ($o.data.reason.kind? // $o.data.reason? // null);
  def rcode($o): ($o.data.reason.error.code? // $o.data.error.code? // $o.error.code? // null);
  # dsh-events.md enum, mapped from the RAW code; unknown codes surface verbatim as
  # "unmapped (CODE)" — never guess-defaulted to transport.
  def mapcat($c): ($c | ascii_upcase) as $u
    | if   ($u | test("CREDENTIAL|AUTH|API_KEY"))      then "model (\($c))"
      elif ($u | test("TIMEOUT"))                      then "timeout (\($c))"
      elif ($u | test("PERMISSION|SANDBOX|LANDLOCK"))  then "sandbox (\($c))"
      else "unmapped (\($c))" end;
  . as $lines
  | ([$lines[] | select(rkind(.) == "error")] | first // null) as $ne
  | ([$lines[] | select(term(.))] | last // null) as $t
  | (if $t == null then "N" else (($t.seq // $t.sequence // "N") | tostring) end) as $seq
  | (if $ne != null then "failed"
     elif $t == null then "unknown"
     elif ((($t.error_category? // "none") | tostring) as $e | ($e != "none" and $e != "" and $e != "null")) then "failed"
     else (($t.status? // "") | tostring | ascii_downcase) as $s
       | if   ($s | test("^(completed|complete|ok|success|succeeded|settled)$"))  then "settled"
         elif ($s | test("^(error|errored|failed|failure)$"))                     then "failed"
         elif ($s | test("^(cancelled|canceled|closed|reaped|aborted)$"))         then "cancelled"
         else "unknown" end
     end) as $status
  | (if $ne != null then (rcode($ne) // "NONE") as $c
       | if $c == "NONE" then "unknown" else mapcat($c) end
     elif $status == "failed" then (($t.error_category? // "unknown") | tostring)
     else "none" end) as $ecat
  # turn/end-only receipt lacking both the reason shape and any top-level status:
  # classification stays "unknown" but the gap is surfaced to stderr (rule 2).
  | (if $ne == null and $t != null
        and (($t.status? // null) == null)
        and (($t.data.reason? // null) == null)
     then "1" else "0" end) as $warn
  | ([$lines[] | ev(.)]) as $evs
  | $seq, $status, $ecat, $warn,
    ([ ["turn/start",        ([$evs[] | select(. == "turn/start")]        | length)],
       ["step/start",        ([$evs[] | select(. == "step/start")]        | length)],
       ["tool/call",         ([$evs[] | select(. == "tool/call")]         | length)],
       ["tool/result",       ([$evs[] | select(. == "tool/result")]       | length)],
       ["assistant/message", ([$evs[] | select(. == "assistant/message")] | length)],
       ["turn/end",          ([$evs[] | select(. == "turn/end")]          | length)] ]
     | map("\(.[0])=\(.[1])") | join(" ")),
    ([ range(0; ($lines | length)) as $i | ($lines[$i]) as $o | (ev($o)) as $e
       | if $e == null then "keys(" + ([$o | keys[] | tostring] | join("+")) + ")"
         elif (known | index($e)) then empty
         else $e end ] | unique
     | if length == 0 then "none" else join(",") end)
')

seq="${r[0]}"; status="${r[1]}"; ecat="${r[2]}"; warn="${r[3]}"; counts="${r[4]}"; other="${r[5]}"

[[ "$warn" == "1" ]] && echo "warn: terminal event without reason shape" >&2

echo '# supporting evidence only — mission ledger authoritative'
echo "trace: ${session_dir}#${seq}"
echo "status: ${status}"
echo "error_category: ${ecat}"
echo "events: ${counts} other=${other}"
echo "file: ${newest}"

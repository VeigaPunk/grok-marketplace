# gx-teams

From-scratch Grok teammate harness. Same *shape* as Claude Code experimental agent teams + tmux mode (OS process per teammate, named panes, file mailbox later). **Does not wrap `claude`. Does not require TeamCreate.**

Grok Build 1.0.5 has no `teammateMode`. `spawn_subagent` is in-process (depth 1). This supervisor is the missing OS layer.

## M_final (cheap all-green)

Cheap smoke: Godspeed unit gate + M01 + M03–M06 + mailbox. Nukes leftovers. Asserts operators `0`/`1`. **Does not** run M02 (`grok -p`) or M07 (ACP). `gate-all.sh` runs `gate-godspeed.sh` first, then M01+M03–M06 + `gate-mbox.sh`.

```bash
bash scripts/gate-godspeed.sh   # expect GATE_GODSPEED_OK
bash scripts/gate-all.sh        # expect GX-TEAMS-GATE-OK
./gx-teams.sh --help            # lists spawn / nuke / dm
```

## M01 (shipped)

One bash file. Detached named tmux session. Echo toy.

```bash
./gx-teams.sh spawn --team toy --name gx-labrat-ping -- cmd echo PING-OK
./gx-teams.sh nuke  --team toy
bash scripts/gate.sh   # expect GATE_OK; never kills operator sessions 0/1
```

## M02 (shipped)

One real `grok -p` teammate in the mux. Flags before `-p`. Poll capture ≤90s. Operators `0`/`1` pane_id+pid frozen. Toy nuked.

```bash
bash scripts/gate-m02.sh   # expect GATE_M02_OK
# evidence: evidence/m02-pong.md
```

| Contract | Rule |
|---|---|
| Session | `gx-teams-<team>`, created with `new-session -d -s` (**never** `-t`, that is a session group) |
| Target | exact `-t =gx-teams-<team>` (tmux prefix-matches without `=`) |
| Pane handle | `#{pane_id}` (`%N`). **Never** `:0.0` |
| Identity | env `GX_TEAM`, `GX_TEAMMATE_NAME`, `GX_TEAMMATE_ID=name@team`, `GX_PARENT_SESSION=<tmux session name>` — **not** pane title / `%N` |
| Hardcap | 16 panes / session |
| Cleanup | `nuke --team` only; **never** `kill-server` |
| Deny | `claude`, `TeamCreate`, `--team 0\|1` |
| Allowlist | `^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$` |
| State | `~/.gx-teams/<team>/config.json` + `inboxes/<name>.jsonl` (disk persist) |
| Scratch | pane `TMPDIR=/tmp/xbgst-gx-<team>-<name>-XXXXXX`; `XBGST_MAIL_ROOT=$TMPDIR/mail`. `XBRD_SPARK_ROOT=$TMPDIR/spark` **only** when argv has `--spark`/`--spk`/`--substrate sekhmet`/`sekhmet`. PATH includes `~/.local/bin` so `xask` reaches grok/kimi/qwen/stock cdx. Never JSONL bodies on `$XDG_RUNTIME_DIR`. |
| Serde | crate `mailbox/` (`xbgst-mailbox`) append/last/gc-scratch. Live `dm` calls `xbgst-mailbox append` (jq only if `XBGST_MAILBOX_ALLOW_JQ=1`). Spawn always `eval "$(fnm env --shell bash)"`. Do **not** GC `fnm_multishells`. |

## M03 (shipped)

`GX_PARENT_SESSION` = spawning client's tmux **session name** (`display-message '#{session_name}'`), not pane id.

```bash
bash scripts/gate-m03.sh   # expect GATE_M03_OK
```

## M04 (shipped)

Mailbox is a JSONL **log** (O_APPEND). `dm` prints `sent` only if write succeeds. Missing `inboxes/` → nonzero (no `mkdir -p` in `dm`).

```bash
./gx-teams.sh dm --team mail --to gx-labrat-ping --text hi
bash scripts/gate-m04.sh   # expect GATE_M04_OK
```

## M05 (shipped)

Hardcap 16: 16×`cmd true`, 17th fails with `hardcap`, nuke `cap`, operators `0`/`1` pane_id:pid frozen.

```bash
bash scripts/gate-m05.sh   # expect GATE_M05_OK
```

## M06 (shipped)

Two titled panes + godspeed spawn files: `install -m 0600` of canonical `godspeed-core/directive.md` (sha256 `db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb`) to `~/.gx-teams/<team>/godspeed/<name>.txt`. Mailbox `dm` `--text` stays the caller string (JSONL log only). Both inboxes accept `dm`.

```bash
bash scripts/gate-m06.sh   # expect GATE_M06_OK
```

## Steal / drop (from CC 2.1.32-era teams, not the 2.1.137 VSCode patch)

**Steal:** OS process per pane; first spawn mkdir (no TeamCreate); JSON inbox with ack-on-write; identity in argv/env; `--no-leader` so panes do not share `~/.grok/leader.sock`.

**Drop:** wrapping Claude Code; TeamCreate/TeamDelete; pane title as SSoT; `tmux send-keys` as the DM bus; `grok agent leader` as the teammate transport; in-process `spawn_subagent` as “teammate mode”.

## M08 (xbgst hook pointer)

Optional `/xbgst` `spawn_method: tmux-pane` hook lives in marketplace source only: `grok-marketplace/plugins/xbgst-stack/skills/xbgst/SKILL.md` (not `~/.grok/skills/xbgst` until judge ships/installs).

## M07 (optional ACP one-shot; not an M_final blocker)

Piped `GROK_SUBAGENTS=0 grok agent --no-leader --always-approve stdio` (flags **before** `stdio`), JSON-RPC `initialize` (`protocolVersion: 1`), then kill. Cap 30s; hang → `Status: blocked E-acp` exit 2.

```bash
bash scripts/gate-m07.sh   # GATE_M07_OK or Status: blocked E-acp
# wrong order clap-rejects: grok agent stdio --no-leader
```

Live DMs still need ACP `session/prompt` — mailbox JSONL is the log only.

## Codex routing (this host; document, do not re-ping)

This Grok pane often exports `CODEX_BIN=codex-titanium`. Stock Codex and Token Plan lanes **unset** it. Titanium stays sekhmet L3. Host `~/.codex` is **not** a git path.

**Default** stock `codex exec` (no `-p`, no `-m`) is the ChatGPT **subscription**. Token Plan is opt-in via profile: `-p qwen38` / `-p ds-flash` / `-p ds-pro`. Always `env -u CODEX_BIN`.

Full write-up + user smoke citations (`SUB_SWITCH_OK`, `QWEN_STILL_OK`) + rollback recipe: `evidence/codex-sub-switch.md`.

Historical Token Plan / E2 CLI canaries (already shipped; do not add new pings):

| Lane | Command | Historical canary | Evidence |
|---|---|---|---|
| E2 revenger | `env -u CODEX_BIN codex exec -m gpt-5.6-luna` | `XBGST_CDX_REVENGER_OK` | `evidence/cdx-revenger.md` |
| Ali qwen | `codex exec -p qwen38` | `XBGST_QWEN38_OK` | `evidence/qwen38-cli.md` |
| Ali ds-flash | `codex exec -p ds-flash` | `XBGST_DSFLASH0731_OK` | `evidence/ds-flash-cli.md` |
| Ali ds-pro | `codex exec -p ds-pro` | `XBGST_DSPRO0813_OK` | `evidence/ds-pro-cli.md` |

Keys via `op run` (`BAILIAN_TOKEN_PLAN_API_KEY`). Never curl-as-proof. Never commit `.env`.

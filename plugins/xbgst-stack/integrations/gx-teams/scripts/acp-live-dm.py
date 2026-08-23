#!/usr/bin/env python3
"""ACP live DM helpers.

Default mode keeps the M02 lead-side flow:
initialize → session/new → session/prompt → kill.

Additive M03 modes:
- serve: keep one ACP session alive behind a FIFO.
- send: enqueue one prompt into that FIFO.

Flags stay before `stdio`. No tmux key injection. No canary.
"""
from __future__ import annotations

import argparse
import errno
import hashlib
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
GT = ROOT / "gx-teams.sh"
STATE_ROOT = Path(os.environ.get("GX_TEAMS_STATE", Path.home() / ".gx-teams"))
TEAM = "acp"
NAME = "gx-labrat-acp"
EVIDENCE = ROOT / "evidence" / "acp-live-dm-m02.md"
PROMPT_BUDGET_S = 60.0
ACP_CWD = Path("/tmp/gx-acp-livedm")
GODSPEED_SHA256 = "db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb"
GODSPEED_SUFFIX = "| godspeed"


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def now_utc() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def live_dm_dir() -> Path:
    return STATE_ROOT / TEAM / "live-dm"


def default_fifo_path() -> Path:
    return live_dm_dir() / f"{NAME}.fifo"


def default_log_path() -> Path:
    return live_dm_dir() / f"{NAME}.jsonl"


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def spawn_teammate() -> str:
    """Spawn one teammate so godspeed lands under STATE_ROOT. Pane holds sleep."""
    subprocess.run(
        [str(GT), "nuke", "--team", TEAM],
        cwd=str(ROOT),
        check=False,
        capture_output=True,
        timeout=30,
    )
    out = subprocess.run(
        [
            str(GT),
            "spawn",
            "--team",
            TEAM,
            "--name",
            NAME,
            "--",
            "cmd",
            "true",
        ],
        cwd=str(ROOT),
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return out.stdout.strip()


def read_godspeed() -> str:
    path = STATE_ROOT / TEAM / "godspeed" / f"{NAME}.txt"
    if not path.is_file():
        die(f"missing godspeed: {path}")
    payload = path.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != GODSPEED_SHA256:
        die(f"non-canonical godspeed: {path} (sha256 {digest})")
    return payload.decode("utf-8")


def strip_terminal_godspeed(text: str) -> str:
    body = text.rstrip()
    while body.endswith(GODSPEED_SUFFIX):
        body = body[: -len(GODSPEED_SUFFIX)].rstrip()
    return body


def build_prompt(base_text: str, include_rules: bool = True) -> str:
    """Build every initial/follow-up prompt from the byte-exact directive."""
    del include_rules  # compatibility only; Godspeed is no longer optional
    directive = read_godspeed()
    body = base_text
    while body.startswith(directive):
        body = body[len(directive) :].lstrip("\r\n")
    body = strip_terminal_godspeed(body)
    return f"{directive}\n{body}\n{GODSPEED_SUFFIX}"


def write_evidence(body: str) -> None:
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(body, encoding="utf-8")


def ensure_fifo(path: Path) -> None:
    ensure_parent(path)
    if path.exists() and not path.is_fifo():
        die(f"live-dm path exists and is not a fifo: {path}")
    if not path.exists():
        os.mkfifo(path)


def append_jsonl(path: Path, record: dict[str, Any]) -> None:
    ensure_parent(path)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


class AcpClient:
    def __init__(self) -> None:
        env = os.environ.copy()
        env["GROK_SUBAGENTS"] = "0"
        self.proc = subprocess.Popen(
            ["grok", "agent", "--no-leader", "--always-approve", "stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            env=env,
            bufsize=0,
        )
        assert self.proc.stdin is not None and self.proc.stdout is not None
        self._next_id = 1
        self._buf = b""
        self.updates: list[dict[str, Any]] = []
        self.session_cwd: Path | None = None

    def close(self) -> None:
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
        except Exception:
            pass
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=2)

    def _readline(self, deadline: float, method: str) -> str:
        assert self.proc.stdout is not None
        fd = self.proc.stdout.fileno()
        while b"\n" not in self._buf:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"ACP {method} exceeded budget")
            ready, _, _ = select.select([fd], [], [], min(remaining, 1.0))
            if not ready:
                continue
            chunk = os.read(fd, 65536)
            if not chunk:
                err = b""
                if self.proc.stderr:
                    try:
                        efd = self.proc.stderr.fileno()
                        ready_err, _, _ = select.select([efd], [], [], 1.0)
                        if ready_err:
                            err = os.read(efd, 4096) or b""
                    except Exception:
                        pass
                raise RuntimeError(
                    f"ACP EOF during {method}: {err.decode('utf-8', 'replace')}"
                )
            self._buf += chunk
        line, self._buf = self._buf.split(b"\n", 1)
        return line.decode("utf-8") + "\n"

    def _write_obj(self, obj: dict[str, Any]) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write((json.dumps(obj) + "\n").encode("utf-8"))
        self.proc.stdin.flush()

    def _error_response(self, req_id: Any, code: int, message: str) -> None:
        self._write_obj(
            {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": code, "message": message},
            }
        )

    def _resolve_read_path(self, raw_path: str) -> Path:
        if self.session_cwd is None:
            raise RuntimeError("session cwd is unset")
        path = Path(raw_path)
        if not path.is_absolute():
            path = self.session_cwd / path
        resolved = path.resolve()
        root = self.session_cwd.resolve()
        try:
            resolved.relative_to(root)
        except ValueError as exc:
            raise RuntimeError(f"path escapes session cwd: {raw_path}") from exc
        return resolved

    def _handle_server_request(self, data: dict[str, Any]) -> bool:
        method = data.get("method")
        req_id = data.get("id")
        if req_id is None or method is None:
            return False
        if method == "fs/readTextFile":
            try:
                params = data.get("params") or {}
                raw_path = params.get("path") or params.get("filePath")
                if not raw_path:
                    raise RuntimeError("missing path")
                path = self._resolve_read_path(str(raw_path))
                text = path.read_text(encoding="utf-8")
                self._write_obj(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {"path": str(path), "text": text},
                    }
                )
            except Exception as exc:
                self._error_response(req_id, -32001, f"readTextFile failed: {exc}")
            return True
        if method == "fs/writeTextFile":
            self._error_response(req_id, -32002, "writeTextFile disabled in live-dm")
            return True
        self._error_response(req_id, -32601, f"unsupported method: {method}")
        return True

    def request(self, method: str, params: dict[str, Any], deadline: float) -> dict[str, Any]:
        req_id = self._next_id
        self._next_id += 1
        if method == "session/new":
            cwd = params.get("cwd")
            if cwd:
                self.session_cwd = Path(str(cwd))
        msg = {"jsonrpc": "2.0", "id": req_id, "method": method, "params": params}
        self._write_obj(msg)
        while True:
            if time.monotonic() > deadline:
                raise TimeoutError(f"ACP {method} exceeded budget")
            line = self._readline(deadline, method)
            data = json.loads(line)
            if data.get("method") == "session/update":
                self.updates.append(data)
                continue
            if self._handle_server_request(data):
                continue
            if data.get("id") != req_id:
                if "method" in data:
                    self.updates.append(data)
                continue
            if "error" in data:
                raise RuntimeError(f"ACP {method} error: {data['error']}")
            return data.get("result") or {}


def run_lead_probe() -> int:
    t0 = time.monotonic()
    spawn_meta = spawn_teammate()
    ACP_CWD.mkdir(parents=True, exist_ok=True)
    prompt_text = build_prompt(
        "Teammate instruction — quote these Godspeed rules back verbatim, "
        "then stop. Do not use tools."
    )

    client = AcpClient()
    protocol_version = None
    session_id = None
    stop_reason = None
    status = "ok"
    err_note = ""
    try:
        deadline = time.monotonic() + PROMPT_BUDGET_S
        init = client.request(
            "initialize",
            {
                "protocolVersion": 1,
                "clientCapabilities": {
                    "fs": {"readTextFile": True, "writeTextFile": True},
                    "terminal": True,
                },
            },
            deadline,
        )
        protocol_version = init.get("protocolVersion")
        if protocol_version is None:
            raise RuntimeError(f"missing protocolVersion: {init}")

        new = client.request(
            "session/new",
            {
                "cwd": str(ACP_CWD),
                "mcpServers": [],
                "_meta": {"yoloMode": True},
            },
            deadline,
        )
        session_id = new.get("sessionId")
        if not session_id:
            raise RuntimeError(f"missing sessionId: {new}")

        result = client.request(
            "session/prompt",
            {
                "sessionId": session_id,
                "prompt": [{"type": "text", "text": prompt_text}],
            },
            deadline,
        )
        stop_reason = result.get("stopReason")
    except TimeoutError as exc:
        status = "blocked E-acp"
        err_note = str(exc)
    except Exception as exc:
        status = "blocked E-acp"
        err_note = f"{type(exc).__name__}: {exc}"
    finally:
        client.close()

    elapsed = time.monotonic() - t0
    body = f"""# ACP live DM M02 — initialize → session/new → session/prompt → kill

**Date:** 2026-08-21
**Host:** grok agent stdio (GROK_SUBAGENTS=0 --no-leader --always-approve)
**Choice:** lead-side Python client (extend `acp-oneshot.py`). Fifo-in-pane deferred (invention risk).
**Transport:** subprocess stdin/stdout JSON-RPC — never tmux key injection. Mailbox JSONL is log only.
**ACP cwd:** `{ACP_CWD}` (disposable; avoids 60s tool-tour hang on product tree)
**Teammate:** team `{TEAM}` name `{NAME}` (godspeed on disk; pane = `true; exec sleep infinity`)
**Spawn:** `{spawn_meta}`
**Connector:** pending (cdx-connector-r1 may land later)

## Protocol

| Step | Value |
|---|---|
| protocolVersion | `{protocol_version}` |
| session/new sessionId | `{session_id}` |
| session/prompt | sent (godspeed quote) |
| stopReason | `{stop_reason}` |
| session/update count | `{len(client.updates)}` |
| elapsed_s: | `{elapsed:.3f}` |
| Status: | `{status}` |

## Godspeed prompt (quoted)

```
{prompt_text}
```

## Notes

- Clap order: flags before `stdio` (same as M07).
- Hang budget: {PROMPT_BUDGET_S:.0f}s → exit 2 / blocked E-acp.
- No canary. No APPROVED. No titanium.
{f"- Error: {err_note}" if err_note else ""}
"""
    write_evidence(body)
    print(f"protocolVersion={protocol_version}")
    print(f"sessionId={session_id}")
    print(f"session/prompt stopReason={stop_reason}")
    print(f"elapsed_s: {elapsed:.3f}")
    print(f"Status: {status}")
    print(f"evidence: {EVIDENCE}")

    if status != "ok":
        return 2
    return 0


def run_serve(args: argparse.Namespace) -> int:
    fifo_path = Path(args.fifo)
    log_path = Path(args.log)
    acp_cwd = Path(args.cwd)
    cap = float(args.cap)
    ensure_fifo(fifo_path)
    acp_cwd.mkdir(parents=True, exist_ok=True)

    hold_fd = os.open(fifo_path, os.O_RDWR | os.O_NONBLOCK)
    read_fd = os.open(fifo_path, os.O_RDONLY | os.O_NONBLOCK)
    fifo_buf = ""
    client = AcpClient()
    session_id = None
    try:
        deadline = time.monotonic() + cap
        init = client.request(
            "initialize",
            {
                "protocolVersion": 1,
                "clientCapabilities": {
                    "fs": {"readTextFile": True, "writeTextFile": True},
                    "terminal": True,
                },
            },
            deadline,
        )
        protocol_version = init.get("protocolVersion")
        if protocol_version is None:
            raise RuntimeError(f"missing protocolVersion: {init}")
        new = client.request(
            "session/new",
            {
                "cwd": str(acp_cwd),
                "mcpServers": [],
                "_meta": {"yoloMode": True},
            },
            deadline,
        )
        session_id = new.get("sessionId")
        if not session_id:
            raise RuntimeError(f"missing sessionId: {new}")
        print(f"fifo={fifo_path}")
        print(f"log={log_path}")
        print(f"sessionId={session_id}")
        print("Status: serving")
        sys.stdout.flush()

        served = 0
        while True:
            if "\n" not in fifo_buf:
                ready, _, _ = select.select([read_fd], [], [], None)
                if not ready:
                    continue
                chunk = os.read(read_fd, 65536)
                if not chunk:
                    continue
                fifo_buf += chunk.decode("utf-8", "replace")
                continue
            line, fifo_buf = fifo_buf.split("\n", 1)
            prompt_in = line.rstrip("\r")
            if not prompt_in:
                continue
            prompt_text = build_prompt(prompt_in)
            started = time.monotonic()
            status = "ok"
            stop_reason = None
            err_note = ""
            updates_before = len(client.updates)
            try:
                result = client.request(
                    "session/prompt",
                    {
                        "sessionId": session_id,
                        "prompt": [{"type": "text", "text": prompt_text}],
                    },
                    time.monotonic() + cap,
                )
                stop_reason = result.get("stopReason")
            except TimeoutError as exc:
                status = "blocked E-acp"
                err_note = str(exc)
            except Exception as exc:
                status = "blocked E-acp"
                err_note = f"{type(exc).__name__}: {exc}"
            record = {
                "ts": now_utc(),
                "fifo": str(fifo_path),
                "sessionId": session_id,
                "prompt": prompt_in,
                "rules": True,
                "stopReason": stop_reason,
                "status": status,
                "elapsed_s": round(time.monotonic() - started, 3),
                "sessionUpdateCount": len(client.updates) - updates_before,
            }
            if err_note:
                record["error"] = err_note
            append_jsonl(log_path, record)
            print(json.dumps(record, ensure_ascii=False))
            sys.stdout.flush()
            served += 1
            if args.once and served >= 1:
                return 0 if status == "ok" else 2
    finally:
        os.close(read_fd)
        os.close(hold_fd)
        client.close()


def run_send(args: argparse.Namespace) -> int:
    fifo_path = Path(args.fifo)
    text = args.text
    if text is None:
        die("send requires --text", 2)
    if "\n" in text or "\r" in text:
        die("send requires single-line --text", 2)
    try:
        fd = os.open(fifo_path, os.O_WRONLY | os.O_NONBLOCK)
    except OSError as exc:
        if exc.errno == errno.ENXIO:
            print(f"no live listener on fifo: {fifo_path}", file=sys.stderr)
            return 2
        if exc.errno == errno.ENOENT:
            print(f"missing fifo: {fifo_path}", file=sys.stderr)
            return 2
        raise
    try:
        os.write(fd, (text + "\n").encode("utf-8"))
    finally:
        os.close(fd)
    print("sent")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd")

    serve = sub.add_parser("serve", help="run one live ACP session behind a FIFO")
    serve.add_argument("--fifo", default=str(default_fifo_path()))
    serve.add_argument("--log", default=str(default_log_path()))
    serve.add_argument("--cwd", default=str(ACP_CWD))
    serve.add_argument("--cap", type=float, default=PROMPT_BUDGET_S)
    serve.add_argument(
        "--rules",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    serve.add_argument("--once", action="store_true")

    send = sub.add_parser("send", help="send one prompt into a live FIFO")
    send.add_argument("--fifo", default=str(default_fifo_path()))
    send.add_argument("--text")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "serve":
        return run_serve(args)
    if args.cmd == "send":
        return run_send(args)
    return run_lead_probe()


if __name__ == "__main__":
    raise SystemExit(main())

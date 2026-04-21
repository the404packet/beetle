#!/usr/bin/env python3
"""
Beetle GUI Backend — FastAPI
Wraps the `beetle` CLI: runs `sudo beetle audit [folder] [severity]`
and `sudo beetle harden [folder] [severity]`, streams output as NDJSON.
"""

import re
import json
import asyncio
import subprocess
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Beetle GUI", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Serve frontend assets (beetle.png etc.) at /static ───────────────────────
FRONTEND_DIR = Path(__file__).parent
app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")

# ── Detect beetle_shell folder location ───────────────────────────────────────
BASE_DIR   = Path(__file__).parent.parent          # .../beetle/
SHELL_DIR  = BASE_DIR / "ubuntu" / "beetle_shell"
AUDIT_DIR  = SHELL_DIR / "audit"
HARDEN_DIR = SHELL_DIR / "harden"

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text).strip()

# ── Folder discovery  ─────────────────────────────────────────────────────────

def get_folders(base: Path) -> list[str]:
    """Return top-level category folder names (e.g. access_control, network…)."""
    if not base.exists():
        return []
    return sorted(d.name for d in base.iterdir() if d.is_dir())

# ── Output parser  ────────────────────────────────────────────────────────────
# Audit line:  [PASS] Name .....  HARDENED
#              [PASS] Name .....  NOT HARDENED
#              [FAIL] Name .....  ERROR
# Harden line: [DONE] Name .....  SUCCESS
#              [FAIL] Name .....  ERROR

AUDIT_LINE_RE  = re.compile(
    r"\[(PASS|FAIL)\]\s+(.+?)\s*\.{3,}\s*(NOT HARDENED|HARDENED|ERROR|.*?)\s*$",
    re.IGNORECASE,
)
HARDEN_LINE_RE = re.compile(
    r"\[(DONE|FAIL)\]\s+(.+?)\s*\.{3,}\s*(SUCCESS|FAILED|ERROR|.*?)\s*$",
    re.IGNORECASE,
)
SUMMARY_RE = re.compile(
    r"\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|"
)

def parse_audit_line(raw: str) -> dict | None:
    line = strip_ansi(raw)
    m = AUDIT_LINE_RE.match(line)
    if not m:
        return None
    status, name, state = m.group(1), m.group(2).strip(), m.group(3).strip()
    hardened = "HARDENED" in state.upper() and "NOT" not in state.upper()
    return {
        "type":     "check",
        "status":   status.upper(),   # PASS | FAIL
        "name":     name,
        "state":    state,
        "hardened": hardened,
        "raw":      line,
    }

def parse_harden_line(raw: str) -> dict | None:
    line = strip_ansi(raw)
    m = HARDEN_LINE_RE.match(line)
    if not m:
        return None
    status, name, state = m.group(1), m.group(2).strip(), m.group(3).strip()
    success = "SUCCESS" in state.upper()
    return {
        "type":    "check",
        "status":  status.upper(),    # DONE | FAIL
        "name":    name,
        "state":   state,
        "success": success,
        "raw":     line,
    }

def parse_summary(raw: str) -> dict | None:
    line = strip_ansi(raw)
    m = SUMMARY_RE.search(line)
    if not m:
        return None
    return {
        "type":        "summary",
        "executed":    int(m.group(1)),
        "failed_exec": int(m.group(2)),
        "hardened":    int(m.group(3)),
        "not_hardened":int(m.group(4)),
        "skipped":     int(m.group(5)),
    }

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/api/modules")
async def api_modules():
    """Return available audit and harden folder names."""
    return {
        "audit":    get_folders(AUDIT_DIR),
        "harden":   get_folders(HARDEN_DIR),
        "severities": ["basic", "moderate", "strong"],
    }


@app.post("/api/audit")
async def api_audit(request: Request):
    """
    Run `beetle audit [folder] [severity]` and stream parsed NDJSON.
    Body: { "folder": "access_control", "severity": "basic" }
    """
    body     = {}
    try: body = await request.json()
    except Exception: pass

    folder   = body.get("folder",   "").strip()
    severity = body.get("severity", "basic").strip()

    cmd = ["sudo", "beetle", "audit"]
    if folder:   cmd.append(folder)
    if severity: cmd.append(severity)

    async def generate():
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(SHELL_DIR),
        )
        summary_sent = False
        async for raw_bytes in proc.stdout:
            raw = raw_bytes.decode("utf-8", errors="replace")
            # Try audit check line
            parsed = parse_audit_line(raw)
            if parsed:
                yield json.dumps(parsed) + "\n"
                continue
            # Try summary data row (the numbers row)
            summ = parse_summary(raw)
            if summ and not summary_sent:
                yield json.dumps(summ) + "\n"
                summary_sent = True
                continue
            # Pass through other informational lines as log
            clean = strip_ansi(raw)
            if clean:
                yield json.dumps({"type": "log", "message": clean}) + "\n"

        await proc.wait()

    return StreamingResponse(generate(), media_type="application/x-ndjson")


@app.post("/api/harden")
async def api_harden(request: Request):
    """
    Run `beetle harden [folder] [severity]` and stream parsed NDJSON.
    Body: { "folder": "access_control", "severity": "basic" }
          folder = "" means harden all
    """
    body = {}
    try: body = await request.json()
    except Exception: pass

    folder   = body.get("folder",   "").strip()
    severity = body.get("severity", "basic").strip()

    cmd = ["sudo", "beetle", "harden"]
    if folder:   cmd.append(folder)
    if severity: cmd.append(severity)

    async def generate():
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(SHELL_DIR),
        )
        summary_sent = False
        async for raw_bytes in proc.stdout:
            raw = raw_bytes.decode("utf-8", errors="replace")
            parsed = parse_harden_line(raw)
            if parsed:
                yield json.dumps(parsed) + "\n"
                continue
            summ = parse_summary(raw)
            if summ and not summary_sent:
                # rename keys for harden context
                summ["succeeded"]   = summ.pop("hardened", 0)
                summ["failed_hard"] = summ.pop("not_hardened", 0)
                yield json.dumps(summ) + "\n"
                summary_sent = True
                continue
            clean = strip_ansi(raw)
            if clean:
                yield json.dumps({"type": "log", "message": clean}) + "\n"

        await proc.wait()

    return StreamingResponse(generate(), media_type="application/x-ndjson")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)

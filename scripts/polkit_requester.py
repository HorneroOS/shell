#!/usr/bin/env python3
"""Process-ancestry attribution for Polkit authentication prompts.

Zero-dependency helper that inspects ``/proc/<pid>/stat`` and
``/proc/<pid>/cmdline`` (with a configurable ``proc_root`` for deterministic
testing) to identify:

- Known coding agents in the requester's process ancestry
- Storage / drive unlock requests (``udisks2`` / ``udisksd``)
- A friendly two-line requester label and detail string plus badge metadata
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
from typing import Any

# Canonical agent key -> human-readable display name.
KNOWN_AGENTS: dict[str, str] = {
    "claude": "Claude Code",
    "gemini": "Gemini CLI",
    "codex": "Codex",
    "hermes": "Hermes",
    "aider": "Aider",
    "opencode": "OpenCode",
    "hornero-assistant": "Hornero Assistant",
}

STORAGE_PROCESSES: frozenset[str] = frozenset({"udisks2", "udisksd"})

# Wrapper/interpreter binaries whose subsequent argv tokens may name the
# actual agent entrypoint (e.g. `node /usr/bin/claude`, `python3 -m aider`).
_INTERPRETERS: frozenset[str] = frozenset(
    {
        "node",
        "nodejs",
        "bun",
        "deno",
        "tsx",
        "npx",
        "python",
        "python3",
        "uv",
        "uvx",
        "env",
        "sh",
        "bash",
        "zsh",
        "fish",
    }
)

_SCRIPT_SUFFIXES: tuple[str, ...] = (".js", ".mjs", ".cjs", ".ts", ".py", ".sh")


def _normalize_token(token: str) -> str:
    """Return a lowercased basename with common script extensions stripped."""
    if not token:
        return ""
    base = os.path.basename(token.strip()).lower()
    for suffix in _SCRIPT_SUFFIXES:
        if base.endswith(suffix) and len(base) > len(suffix):
            base = base[: -len(suffix)]
            break
    return base


def read_proc_stat(pid: int, proc_root: Path = Path("/proc")) -> tuple[str, int] | None:
    """Read ``(comm, ppid)`` from ``<proc_root>/<pid>/stat``.

    Handles process names containing spaces or parentheses by locating the
    first ``(`` and last ``)`` in the stat line.
    """
    stat_path = proc_root / str(pid) / "stat"
    try:
        raw = stat_path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None

    first_lparen = raw.find("(")
    last_rparen = raw.rfind(")")
    if first_lparen == -1 or last_rparen <= first_lparen:
        return None

    comm = raw[first_lparen + 1 : last_rparen]
    rest = raw[last_rparen + 1 :].strip().split()
    if len(rest) < 2:
        return None

    try:
        ppid = int(rest[1])
    except ValueError:
        return None

    return comm, ppid


def read_proc_cmdline(pid: int, proc_root: Path = Path("/proc")) -> list[str]:
    """Read NUL-separated argv from ``<proc_root>/<pid>/cmdline``."""
    cmdline_path = proc_root / str(pid) / "cmdline"
    try:
        raw = cmdline_path.read_bytes()
    except OSError:
        return []
    if not raw:
        return []
    return [part.decode("utf-8", errors="replace") for part in raw.split(b"\x00") if part]


def walk_ancestry(
    pid: int,
    proc_root: Path = Path("/proc"),
    max_depth: int = 64,
) -> list[dict[str, Any]]:
    """Walk process ancestry from ``pid`` upward through ``ppid``."""
    ancestry: list[dict[str, Any]] = []
    seen: set[int] = set()
    current = pid

    while current > 0 and current not in seen and len(ancestry) < max_depth:
        seen.add(current)
        stat = read_proc_stat(current, proc_root=proc_root)
        if stat is None:
            break
        comm, ppid = stat
        cmdline = read_proc_cmdline(current, proc_root=proc_root)
        ancestry.append(
            {
                "pid": current,
                "ppid": ppid,
                "comm": comm,
                "cmdline": cmdline,
            }
        )
        if ppid <= 1 or ppid == current:
            break
        current = ppid

    return ancestry


def _candidate_names_for_process(proc: dict[str, Any]) -> list[str]:
    """Extract normalized candidate executable/script names for a process."""
    candidates: list[str] = []
    comm = _normalize_token(proc.get("comm", ""))
    if comm:
        candidates.append(comm)

    cmdline: list[str] = proc.get("cmdline") or []
    if not cmdline:
        return candidates

    argv0 = _normalize_token(cmdline[0])
    if argv0 and argv0 not in candidates:
        candidates.append(argv0)

    # If launched via an interpreter/wrapper (node, python3, uv, env, ...),
    # inspect the first few non-flag arguments for a known agent entrypoint.
    if argv0 in _INTERPRETERS or comm in _INTERPRETERS:
        for arg in cmdline[1:6]:
            if not arg or arg.startswith("-"):
                continue
            norm = _normalize_token(arg)
            if norm and norm not in candidates:
                candidates.append(norm)
            # Also check path components for scoped package paths like
            # .../node_modules/@anthropic-ai/claude-code/cli.js
            for part in Path(arg).parts:
                part_norm = _normalize_token(part)
                if part_norm in KNOWN_AGENTS and part_norm not in candidates:
                    candidates.append(part_norm)

    return candidates


def detect_coding_agent(ancestry: list[dict[str, Any]]) -> tuple[str, str] | None:
    """Return ``(agent_key, display_name)`` for the nearest coding agent in ancestry."""
    for proc in ancestry:
        for name in _candidate_names_for_process(proc):
            if name in KNOWN_AGENTS:
                return name, KNOWN_AGENTS[name]
    return None


def is_storage_request(ancestry: list[dict[str, Any]], action_id: str = "") -> bool:
    """Return True if the request is a udisks2/udisksd storage or drive unlock."""
    if action_id.lower().startswith("org.freedesktop.udisks2."):
        return True
    for proc in ancestry:
        for name in _candidate_names_for_process(proc):
            if name in STORAGE_PROCESSES:
                return True
    return False


def discover_requester_pid(
    proc_root: Path = Path("/proc"),
    action_id: str = "",
) -> int | None:
    """Best-effort discovery of an active polkit requester PID in ``proc_root``."""
    want_storage = action_id.lower().startswith("org.freedesktop.udisks2.")
    matches: list[int] = []

    try:
        entries = list(proc_root.iterdir())
    except OSError:
        return None

    for entry in entries:
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        stat = read_proc_stat(pid, proc_root=proc_root)
        if stat is None:
            continue
        comm = _normalize_token(stat[0])
        if want_storage and comm in STORAGE_PROCESSES:
            matches.append(pid)
        elif not want_storage and comm == "pkexec":
            matches.append(pid)

    return max(matches) if matches else None


def _pkexec_target(cmdline: list[str]) -> str | None:
    """Extract the target binary name from a ``pkexec`` command line."""
    if not cmdline or _normalize_token(cmdline[0]) != "pkexec":
        return None
    skip_next = False
    for arg in cmdline[1:]:
        if skip_next:
            skip_next = False
            continue
        if arg in ("--user", "-u"):
            skip_next = True
            continue
        if arg.startswith("-"):
            continue
        return os.path.basename(arg)
    return None


def resolve_requester(
    pid: int | None = None,
    *,
    action_id: str = "",
    message: str = "",
    proc_root: str | Path = "/proc",
) -> dict[str, Any]:
    """Resolve requester attribution and badge metadata for a Polkit prompt."""
    root = Path(proc_root)
    resolved_pid = pid if pid is not None else discover_requester_pid(root, action_id=action_id)
    ancestry = walk_ancestry(resolved_pid, proc_root=root) if resolved_pid is not None else []

    agent_match = detect_coding_agent(ancestry)
    is_agent = agent_match is not None
    agent_name = agent_match[0] if agent_match is not None else None
    agent_label = agent_match[1] if agent_match is not None else None

    storage = is_storage_request(ancestry, action_id=action_id)

    requester_comm = ancestry[0]["comm"] if ancestry else ""
    requester_cmdline = ancestry[0]["cmdline"] if ancestry else []
    target_bin = _pkexec_target(requester_cmdline)

    if is_agent and agent_label is not None:
        label = f"{agent_label} · Drive unlock" if storage else agent_label
        detail_parts = ["Coding agent"]
        if target_bin:
            detail_parts.append(f"running {target_bin}")
        elif requester_comm:
            detail_parts.append(f"via {requester_comm}")
        if resolved_pid is not None:
            detail_parts.append(f"PID {resolved_pid}")
        elif action_id:
            detail_parts.append(action_id)
        detail = " · ".join(detail_parts)
    elif storage:
        label = "Drive unlock (udisks2)"
        detail_parts = []
        if action_id:
            detail_parts.append(action_id)
        else:
            detail_parts.append("Storage volume authentication")
        if resolved_pid is not None:
            detail_parts.append(f"PID {resolved_pid}")
        detail = " · ".join(detail_parts)
    elif requester_comm:
        label = target_bin if target_bin else requester_comm
        detail_parts = []
        if target_bin:
            detail_parts.append(f"via {requester_comm}")
        if resolved_pid is not None:
            detail_parts.append(f"PID {resolved_pid}")
        if action_id:
            detail_parts.append(action_id)
        detail = " · ".join(detail_parts)
    else:
        label = action_id.rsplit(".", 1)[-1] if action_id else "System authentication"
        detail = action_id or message

    return {
        "label": label,
        "detail": detail,
        "is_agent": is_agent,
        "agent_name": agent_name,
        "agent_label": agent_label,
        "is_storage": storage,
        "pid": resolved_pid,
        "ancestry": [proc["comm"] for proc in ancestry],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Resolve Polkit requester process ancestry and coding-agent attribution."
    )
    parser.add_argument("--pid", type=int, default=None, help="Requester process ID")
    parser.add_argument("--action-id", default="", help="Polkit action ID")
    parser.add_argument("--message", default="", help="Polkit prompt message")
    parser.add_argument("--proc-root", default="/proc", help="Override /proc mount path")
    args = parser.parse_args(argv)

    result = resolve_requester(
        pid=args.pid,
        action_id=args.action_id,
        message=args.message,
        proc_root=args.proc_root,
    )
    json.dump(result, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

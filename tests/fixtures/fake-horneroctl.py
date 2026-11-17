#!/usr/bin/env python3
"""Scripted stand-in for `horneroctl assistant ...` (test/VM harness only).

Never talks to a gateway, never reads real config or keys. The scenario is
chosen by the first line of $FAKE_HORNEROCTL_DIR/scenario (default dir:
$XDG_STATE_HOME/fake-horneroctl) so a running shell can be driven from
outside. Scenarios (ask/events):

  stream          run, thinking, tool, deltas, final ok
  approval        run, tool, approval frame, then BLOCKS (stream open) until
                  `approve`/`stop` writes $DIR/decision; then finishes
  approval-closed run, tool, approval frame, final pending result, exit
  clarify         run, clarify frame, final pending result, exit
  blocked         final result pending=denied-by-mode
  fail            final result ok=false
  death           run, partial delta, then dies with no final line
  slow            deltas every 0.4 s for 60 s (cancel target)

Gateway view ($DIR/gateway): connected (default) | disconnected | disabled |
unsandboxed | incompatible.
"""
import json
import os
import signal
import sys
import time
from pathlib import Path

D = Path(os.environ.get("FAKE_HORNEROCTL_DIR") or Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "fake-horneroctl")
D.mkdir(parents=True, exist_ok=True)


def read(name, default):
    f = D / name
    return f.read_text().strip().splitlines()[0] if f.exists() and f.read_text().strip() else default


def out(obj):
    print(json.dumps(obj, ensure_ascii=False), flush=True)


def final(ok, message, **data):
    out({"command": "assistant ask", "ok": ok, "message": message, "data": {k: str(v) for k, v in data.items()}})
    return 0 if ok else 1


def log(line):
    with (D / "calls.log").open("a") as fh:
        fh.write(line + "\n")


def gateway_status():
    g = read("gateway", "connected")
    base = {"enabled": "true", "endpoint": "http://127.0.0.1:8642", "workspace": "/home/user/.local/share/hornero/javi-workspaces/default"}
    if g == "disabled":
        out({"command": "assistant status", "ok": True, "message": "Assistant is disabled (default). Enable it explicitly: horneroctl assistant enable --yes", "data": {"enabled": "false"}})
        return 0
    if g == "disconnected":
        base.update({"gateway": "unreachable", "gatewayDetail": "unreachable: connection refused"})
        out({"command": "assistant status", "ok": False, "message": "Assistant is enabled but the Hermes gateway is not answering. Start Hermes, then retry.", "data": base})
        return 1
    base.update({"gateway": "reachable", "protocol": "incompatible" if g == "incompatible" else "compatible",
                 "isolation": "systemd-only (not sandboxed)" if g == "unsandboxed" else "bubblewrap"})
    out({"command": "assistant status", "ok": g != "incompatible", "message": "Assistant enabled; Hermes gateway reachable and protocol-compatible.", "data": base})
    return 0


def wait_decision(limit=120):
    f = D / "decision"
    f.unlink(missing_ok=True)
    end = time.time() + limit
    while time.time() < end:
        if f.exists():
            return f.read_text().strip()
        time.sleep(0.2)
    return "timeout"


def play(scn, run_id):
    if scn == "stream":
        out({"type": "run", "text": run_id})
        out({"type": "thinking", "text": "checking what is installed"})
        out({"type": "tool", "text": "▸ system_info"})
        time.sleep(0.4)
        out({"type": "tool", "text": "✓ system_info"})
        for part in ["Hola. ", "Tenes **3 updates** ", "pendientes.\n\n", "```sh\nsudo pacman -Syu\n```\n"]:
            out({"type": "delta", "text": part})
            time.sleep(0.35)
        return final(True, "ok", runId=run_id, pending="none")
    if scn == "slow":
        out({"type": "run", "text": run_id})
        for i in range(150):
            out({"type": "delta", "text": f"word{i} "})
            time.sleep(0.4)
        return final(True, "ok", runId=run_id)
    if scn == "approval":
        out({"type": "run", "text": run_id})
        out({"type": "tool", "text": "▸ terminal: pacman -S --noconfirm htop"})
        out({"type": "approval", "text": "pacman -S --noconfirm htop"})
        decision = wait_decision()
        if decision == "stop":
            return 143
        if decision == "deny":
            out({"type": "tool", "text": "✗ terminal"})
            out({"type": "delta", "text": "Understood, I did not install it."})
        else:
            out({"type": "tool", "text": "✓ terminal"})
            out({"type": "delta", "text": "Installed htop."})
        return final(True, "ok", runId=run_id)
    if scn == "approval-closed":
        out({"type": "run", "text": run_id})
        out({"type": "tool", "text": "▸ terminal: rm -r ./build"})
        out({"type": "approval", "text": "rm -r ./build"})
        return final(False, f"Hermes is waiting for approval on run {run_id}: rm -r ./build. Nothing is auto-approved.", runId=run_id, pending="approval", detail="rm -r ./build", choices="once,deny", mode="agent")
    if scn == "clarify":
        out({"type": "run", "text": run_id})
        out({"type": "clarify", "text": "Which theme should I use?"})
        return final(False, f"Hermes is asking on run {run_id}", runId=run_id, pending="clarify", detail="Which theme should I use?")
    if scn == "blocked":
        out({"type": "run", "text": run_id})
        return final(False, f"Tool execution denied by ask mode on run {run_id}: terminal. ask mode never executes tools; switch to an Agent session to act.", runId=run_id, pending="denied-by-mode", detail="terminal", mode="ask")
    if scn == "fail":
        return final(False, "Cannot reach the Hermes gateway at http://127.0.0.1:8642: connection refused. Start Hermes, then retry.")
    if scn == "death":
        out({"type": "run", "text": run_id})
        out({"type": "tool", "text": "▸ terminal: sleep 99"})
        out({"type": "delta", "text": "Working on it, first part of the ans"})
        sys.stdout.flush()
        os.kill(os.getpid(), signal.SIGKILL)
    return final(True, "ok", runId=run_id)


def main(argv):
    args = argv[1:]
    log(" ".join(args))
    if not args or args[0] != "assistant":
        print(json.dumps({"ok": False, "message": "fake-horneroctl: unsupported"}))
        return 2
    verb = args[1] if len(args) > 1 else ""
    if verb == "status":
        return gateway_status()
    if verb == "sessions":
        out({"command": "assistant sessions", "ok": True, "message": "s1 — Default (since now)", "data": {"current": "", "ids": "s1"}})
        return 0
    if verb == "model":
        sub = args[2] if len(args) > 2 else "list"
        if sub == "show":
            out({"command": "assistant model", "ok": True, "message": "Current model: fake-model-1 (provider fake)", "data": {"model": "fake-model-1", "provider": "fake"}})
        elif sub == "list":
            out({"command": "assistant model", "ok": True, "message": "Available models: fake-model-1, fake-model-2", "data": {"models": "fake-model-1,fake-model-2", "model": "fake-model-1"}})
        else:
            out({"command": "assistant model set", "ok": True, "message": "model set", "data": {}})
        return 0
    if verb in ("ask", "events"):
        if "--mode" in args and args[args.index("--mode") + 1] not in ("ask", "agent", "chat"):
            return final(False, "--mode must be ask, agent or chat")
        scn = read("scenario", "stream")
        # events follows an existing run: only the tail of the scenario.
        run_id = args[2] if verb == "events" and len(args) > 2 else "run_fake_%d" % int(time.time())
        if verb == "events":
            if scn in ("approval-closed", "approval"):
                out({"type": "delta", "text": "Done after your decision."})
                return final(True, "ok", runId=run_id, pending="none")
            if scn == "clarify":
                out({"type": "delta", "text": "Thanks, using that."})
                return final(True, "ok", runId=run_id)
            if "--stream" not in args and scn == "approval-closed":
                return final(False, "waiting", runId=run_id, pending="approval", detail="rm -r ./build")
        signal.signal(signal.SIGTERM, lambda *_: os._exit(143))
        return play(scn, run_id)
    if verb == "approve":
        (D / "decision").write_text("deny" if args[3:4] == ["deny"] else "approve")
        out({"command": "assistant approve", "ok": True, "message": f"Decision recorded for run {args[2]}: {args[3]}.", "data": {"runId": args[2], "decision": args[3]}})
        return 0
    if verb == "clarify":
        out({"command": "assistant clarify", "ok": True, "message": "Answer sent.", "data": {}})
        return 0
    if verb == "stop":
        (D / "decision").write_text("stop")
        out({"command": "assistant stop", "ok": True, "message": f"Stop requested for run {args[2]}.", "data": {"runId": args[2]}})
        return 0
    out({"command": "assistant " + verb, "ok": True, "message": "fake", "data": {}})
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

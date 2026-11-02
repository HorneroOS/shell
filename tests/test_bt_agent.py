"""Protocol tests for scripts/hornero-bt-agent.py (RequestBridge).

D-Bus/BlueZ registration is not exercised (no Bluetooth hardware or
system bus in CI); the file bridge that carries every pairing
decision is tested end to end: explicit confirm answers, silence and
malformed answers reject, and request files are cleaned up.
"""

import importlib.util
import json
import threading
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "hornero_bt_agent", ROOT / "scripts/hornero-bt-agent.py")
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


def _answer_after(bridge_dir: Path, payload: dict, delay: float = 0.2):
    def _write():
        time.sleep(delay)
        current = json.loads(
            (bridge_dir / "request-current.json").read_text(encoding="utf-8"))
        (bridge_dir / f"response-{current['id']}.json").write_text(
            json.dumps(payload | {"id": current["id"]}), encoding="utf-8")

    threading.Thread(target=_write, daemon=True).start()


def test_explicit_confirm_is_returned(tmp_path):
    bridge = agent.RequestBridge(tmp_path, timeout_s=5)
    _answer_after(tmp_path, {"action": "confirm"})
    resp = bridge.ask("confirmation", "Headphones", "AA:BB:CC:DD:EE:FF", "123456")
    assert resp["action"] == "confirm"
    # Request/response files are cleaned up after the answer.
    assert list(tmp_path.iterdir()) == []


def test_silence_rejects_on_timeout(tmp_path):
    bridge = agent.RequestBridge(tmp_path, timeout_s=0.4)
    with pytest.raises(agent.Rejected):
        bridge.ask("confirmation", "Headphones", "AA:BB", "123456")


def test_malformed_response_rejects(tmp_path):
    bridge = agent.RequestBridge(tmp_path, timeout_s=5)

    def _write_bad():
        time.sleep(0.2)
        current = json.loads(
            (tmp_path / "request-current.json").read_text(encoding="utf-8"))
        (tmp_path / f"response-{current['id']}.json").write_text(
            "not json", encoding="utf-8")

    threading.Thread(target=_write_bad, daemon=True).start()
    with pytest.raises(agent.Rejected):
        bridge.ask("pin", "Keyboard", "AA:BB")


def test_request_file_is_user_only_and_well_formed(tmp_path):
    bridge = agent.RequestBridge(tmp_path, timeout_s=0.4)
    seen = {}

    def _capture():
        time.sleep(0.15)
        seen.update(json.loads(
            (tmp_path / "request-current.json").read_text(encoding="utf-8")))

    threading.Thread(target=_capture, daemon=True).start()
    with pytest.raises(agent.Rejected):
        bridge.ask("passkey", "Phone", "AA:BB")
    assert seen["kind"] == "passkey"
    assert seen["deviceName"] == "Phone"
    assert seen["id"]

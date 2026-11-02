#!/usr/bin/env python3
"""Hornero Bluetooth pairing agent.

Registers an org.bluez.Agent1 agent (KeyboardDisplay capability) and
bridges every BlueZ pairing request to the Hornero Shell dialog
through files in $XDG_RUNTIME_DIR/hornero/bluetooth-agent/:

- the agent writes request-<id>.json (and a copy at
  request-current.json, which the Shell watches) with
  {id, kind, deviceName, deviceAddress, passkey};
- the Shell answers via `horneroctl hardware bluetooth agent-respond`,
  which writes response-<id>.json;
- the agent confirms ONLY on an explicit confirm/pin response.
  Timeout, cancellation, malformed responses and a missing Shell all
  reject the pairing. Nothing is ever auto-accepted, and the adapter
  is never made discoverable/pairable by this agent.

The request/response bridge (RequestBridge) is D-Bus-free so the
pairing protocol is unit-testable without Bluetooth hardware.
"""

from __future__ import annotations

import json
import os
import sys
import time
import uuid
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

AGENT_PATH = "/org/hornero/btagent"
CAPABILITY = "KeyboardDisplay"
DEFAULT_TIMEOUT_S = 90.0

AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg type="o" direction="in" name="device"/>
      <arg type="s" direction="out" name="pincode"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" direction="in" name="device"/>
      <arg type="s" direction="in" name="pincode"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" direction="in" name="device"/>
      <arg type="u" direction="out" name="passkey"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" direction="in" name="device"/>
      <arg type="u" direction="in" name="passkey"/>
      <arg type="q" direction="in" name="entered"/>
    </method>
    <method name="RequestConfirmation">
      <arg type="o" direction="in" name="device"/>
      <arg type="u" direction="in" name="passkey"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" direction="in" name="device"/>
      <arg type="s" direction="in" name="uuid"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" direction="in" name="device"/>
      <arg type="s" direction="in" name="uuid"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""


class Rejected(Exception):
    """Pairing rejected (by user, timeout, or protocol failure)."""


def agent_dir() -> Path:
    override = os.environ.get("HORNERO_BLUETOOTH_AGENT_DIR")
    if override:
        return Path(override)
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        return Path(runtime) / "hornero" / "bluetooth-agent"
    return Path(f"/run/user/{os.getuid()}") / "hornero" / "bluetooth-agent"


class RequestBridge:
    """File-based request/response bridge to the Shell dialog."""

    def __init__(self, directory: Path, timeout_s: float = DEFAULT_TIMEOUT_S):
        self.dir = Path(directory)
        self.timeout_s = timeout_s
        self.dir.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(self.dir, 0o700)
        except OSError:
            pass
        self._current_id: str | None = None

    def _write_atomic(self, path: Path, payload: dict) -> None:
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload), encoding="utf-8")
        try:
            os.chmod(tmp, 0o600)
        except OSError:
            pass
        tmp.replace(path)

    def ask(self, kind: str, device_name: str, device_address: str,
            passkey: str = "") -> dict:
        """Publish a request and wait for the Shell's response.

        Returns the response dict on an explicit answer; raises
        Rejected on timeout, cancellation or malformed data.
        """
        request_id = uuid.uuid4().hex[:16]
        self._current_id = request_id
        payload = {
            "id": request_id,
            "kind": kind,
            "deviceName": device_name or "Unknown device",
            "deviceAddress": device_address or "",
            "passkey": passkey or "",
        }
        request_path = self.dir / f"request-{request_id}.json"
        self._write_atomic(request_path, payload)
        self._write_atomic(self.dir / "request-current.json", payload)
        try:
            return self._wait_response(request_id)
        finally:
            self._cleanup(request_id)
            self._current_id = None

    def _wait_response(self, request_id: str) -> dict:
        response_path = self.dir / f"response-{request_id}.json"
        request_path = self.dir / f"request-{request_id}.json"
        deadline = time.monotonic() + self.timeout_s
        while time.monotonic() < deadline:
            if not request_path.exists():
                raise Rejected("pairing request cancelled")
            if response_path.exists():
                try:
                    data = json.loads(response_path.read_text(encoding="utf-8"))
                except (OSError, ValueError) as exc:
                    raise Rejected(f"malformed pairing response: {exc}") from exc
                if data.get("id") != request_id or "action" not in data:
                    raise Rejected("pairing response does not match request")
                return data
            time.sleep(0.1)
        raise Rejected("pairing request timed out")

    def cancel_current(self) -> None:
        if self._current_id:
            self._cleanup(self._current_id)
            self._current_id = None

    def _cleanup(self, request_id: str) -> None:
        for name in (f"request-{request_id}.json", f"response-{request_id}.json",
                     "request-current.json"):
            try:
                (self.dir / name).unlink()
            except OSError:
                pass


def _device_props(bus: Gio.DBusConnection, device_path: str) -> tuple[str, str]:
    """Best-effort (name, address) for a BlueZ device object path."""
    try:
        proxy = Gio.DBusProxy.new_sync(
            bus, Gio.DBusProxyFlags.NONE, None, "org.bluez", device_path,
            "org.bluez.Device1", None)
        name = proxy.get_cached_property("Name")
        alias = proxy.get_cached_property("Alias")
        address = proxy.get_cached_property("Address")
        label = (alias.unpack() if alias else None) or (
            name.unpack() if name else "") or ""
        addr = address.unpack() if address else ""
        return str(label), str(addr)
    except GLib.Error:
        return "", ""


class BluezAgent:
    def __init__(self, bus: Gio.DBusConnection, bridge: RequestBridge):
        self.bus = bus
        self.bridge = bridge
        self.node = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
        bus.register_object(AGENT_PATH, self.node.interfaces[0],
                            self._on_method, None, None)

    def _on_method(self, _conn, _sender, _path, _iface, method,
                   params, invocation):
        try:
            args = params.unpack()
            if method == "Release":
                invocation.return_value(None)
            elif method == "Cancel":
                self.bridge.cancel_current()
                invocation.return_value(None)
            elif method == "RequestConfirmation":
                device, passkey = args
                name, addr = _device_props(self.bus, device)
                resp = self.bridge.ask("confirmation", name, addr,
                                       f"{int(passkey):06d}")
                if resp.get("action") != "confirm":
                    raise Rejected("user rejected the passkey confirmation")
                invocation.return_value(None)
            elif method == "RequestPinCode":
                (device,) = args
                name, addr = _device_props(self.bus, device)
                resp = self.bridge.ask("pin", name, addr)
                if resp.get("action") != "pin" or not resp.get("pin"):
                    raise Rejected("user did not provide a PIN")
                invocation.return_value(GLib.Variant("(s)", (str(resp["pin"]),)))
            elif method == "RequestPasskey":
                (device,) = args
                name, addr = _device_props(self.bus, device)
                resp = self.bridge.ask("passkey", name, addr)
                if resp.get("action") != "pin" or not str(resp.get("pin", "")).isdigit():
                    raise Rejected("user did not provide a passkey")
                invocation.return_value(
                    GLib.Variant("(u)", (int(resp["pin"]),)))
            elif method == "DisplayPasskey":
                device, passkey, _entered = args
                name, addr = _device_props(self.bus, device)
                # Informational only: show it, never wait for input.
                payload = {
                    "id": uuid.uuid4().hex[:16], "kind": "display",
                    "deviceName": name or "Unknown device",
                    "deviceAddress": addr, "passkey": f"{int(passkey):06d}",
                }
                self.bridge._write_atomic(
                    self.bridge.dir / "request-current.json", payload)
                invocation.return_value(None)
            elif method == "DisplayPinCode":
                device, pincode = args
                name, addr = _device_props(self.bus, device)
                payload = {
                    "id": uuid.uuid4().hex[:16], "kind": "display",
                    "deviceName": name or "Unknown device",
                    "deviceAddress": addr, "passkey": str(pincode),
                }
                self.bridge._write_atomic(
                    self.bridge.dir / "request-current.json", payload)
                invocation.return_value(None)
            else:  # RequestAuthorization / AuthorizeService: never blanket-approve
                raise Rejected(f"{method} is not auto-authorized")
        except Rejected as exc:
            invocation.return_dbus_error("org.bluez.Error.Rejected", str(exc))
        except GLib.Error as exc:
            invocation.return_dbus_error("org.bluez.Error.Failed", str(exc))


def main() -> int:
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    bridge = RequestBridge(agent_dir())
    BluezAgent(bus, bridge)
    manager = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None, "org.bluez", "/org/bluez",
        "org.bluez.AgentManager1", None)
    manager.call_sync("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY)),
                      Gio.DBusCallFlags.NONE, -1, None)
    # Being the default agent only routes pairing requests here; every
    # request still needs an explicit user answer in the Shell dialog
    # and silence/timeout rejects (see RequestBridge).
    manager.call_sync("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)),
                      Gio.DBusCallFlags.NONE, -1, None)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            manager.call_sync("UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)),
                              Gio.DBusCallFlags.NONE, -1, None)
        except GLib.Error:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())

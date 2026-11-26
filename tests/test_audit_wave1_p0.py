"""Regression tests for Wave 1 P0 security & stability remediation (#730-#734)."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import validate_plugin as vp  # noqa: E402


# ---------------------------------------------------------------------------
# #730: Lockscreen passphrases + unauthenticated unlock
# ---------------------------------------------------------------------------


def test_pam_accepts_spaces_and_unicode_rejects_control_chars():
    pam = (ROOT / "modules" / "lock" / "Pam.qml").read_text(encoding="utf-8")
    assert "/^\\S$/" not in pam, "Pam.qml must not reject spaces or multi-code-unit characters"
    assert r"[\x00-\x1f\x7f-\x9f]" in pam

    # Verify the exact JS/PCRE-compatible control-character regex semantics
    ctrl_re = re.compile(r"[\x00-\x1f\x7f-\x9f]")
    for allowed in (" ", "a", "é", "ñ", "🔐", "a\u0301", "pass phrase"):
        assert len(allowed) > 0 and not ctrl_re.search(allowed), f"should accept {allowed!r}"
    for rejected in ("", "\x00", "\t", "\n", "\r", "\x1b", "\x7f", "\x85"):
        assert not (len(rejected) > 0 and not ctrl_re.search(rejected)), f"should reject {rejected!r}"


def test_idle_monitors_disallows_unauthenticated_unlock():
    src = (ROOT / "modules" / "IdleMonitors.qml").read_text(encoding="utf-8")
    assert "lock.lock.locked = false" not in src
    assert 'action !== "unlock"' not in src


# ---------------------------------------------------------------------------
# #731: systemd-logind sleep delay inhibitor
# ---------------------------------------------------------------------------


def test_logind_manager_acquires_and_releases_sleep_delay_inhibitor():
    hdr = (ROOT / "plugin" / "src" / "Hornero" / "Internal" / "logindmanager.hpp").read_text(encoding="utf-8")
    cpp = (ROOT / "plugin" / "src" / "Hornero" / "Internal" / "logindmanager.cpp").read_text(encoding="utf-8")
    idle = (ROOT / "modules" / "IdleMonitors.qml").read_text(encoding="utf-8")

    assert "QDBusUnixFileDescriptor" in hdr
    assert "releaseSleepInhibitor" in hdr
    assert '"Inhibit", "sleep"' in cpp
    assert '"delay"' in cpp
    assert "acquireSleepInhibitor()" in cpp
    assert "m_inhibitReleaseTimer" in cpp
    assert "releaseSleepInhibitor()" in idle
    assert "onSecureChanged" in idle


# ---------------------------------------------------------------------------
# #732: AudioCollector, HyprExtras, dead Qalculator/libqalculate
# ---------------------------------------------------------------------------


def test_audio_collector_triple_buffer_and_pipewire_safety():
    hdr = (ROOT / "plugin" / "src" / "Hornero" / "Services" / "audiocollector.hpp").read_text(encoding="utf-8")
    cpp = (ROOT / "plugin" / "src" / "Hornero" / "Services" / "audiocollector.cpp").read_text(encoding="utf-8")

    assert "m_buffers[3]" in hdr
    assert "pw_deinit" not in cpp
    # processStream must not return early before pw_stream_queue_buffer when data == nullptr
    proc_match = re.search(r"void PipeWireWorker::processStream\(\)\s*\{(.*?)\n\}", cpp, re.DOTALL)
    assert proc_match is not None
    proc_body = proc_match.group(1)
    assert "pw_stream_queue_buffer(m_stream, buffer);" in proc_body
    assert "if (samples == nullptr)" not in proc_body


def test_hyprextras_buffers_until_eof_and_sanitizes_semicolons():
    cpp = (ROOT / "plugin" / "src" / "Hornero" / "Internal" / "hyprextras.cpp").read_text(encoding="utf-8")
    assert "&QLocalSocket::disconnected" in cpp
    assert "PeerClosedError" in cpp
    assert "remove(';')" in cpp


def test_dead_qalculator_removed():
    assert not (ROOT / "plugin" / "src" / "Hornero" / "qalculator.hpp").exists()
    assert not (ROOT / "plugin" / "src" / "Hornero" / "qalculator.cpp").exists()
    assert "libqalculate" not in (ROOT / "plugin" / "src" / "Hornero" / "CMakeLists.txt").read_text(encoding="utf-8")
    assert "libqalculate" not in (ROOT / "packaging" / "PKGBUILD").read_text(encoding="utf-8")
    assert "libqalculate" not in (ROOT / "nix" / "default.nix").read_text(encoding="utf-8")
    assert "powered by Qalc" not in (ROOT / "config" / "LauncherConfig.qml").read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# #733: Unquoted sh -c fixes + validate_plugin.py hardening
# ---------------------------------------------------------------------------


def test_no_unquoted_sh_c_in_remediated_qml_files():
    picker = (ROOT / "modules" / "areapicker" / "Picker.qml").read_text(encoding="utf-8")
    assert '"wl-copy --type image/png < " + path' not in picker
    assert '"--", path' in picker

    pam = (ROOT / "modules" / "lock" / "Pam.qml").read_text(encoding="utf-8")
    assert '["fprintd-list", Quickshell.env("USER")]' in pam

    persist = (ROOT / "modules" / "companion" / "CompanionPersist.qml").read_text(encoding="utf-8")
    assert "'${path}'" not in persist
    assert "'${quoted}'" not in persist

    inst = (ROOT / "modules" / "companion" / "CompanionInstancesPersist.qml").read_text(encoding="utf-8")
    assert "'${path}'" not in inst
    assert "'${quoted}'" not in inst


def _make_plugin(tmp_path: Path, files: dict[str, str], commands: list[str] | None = None) -> Path:
    plugin_dir = tmp_path / "sample-plugin"
    plugin_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schemaVersion": 3,
        "pluginKit": 3,
        "id": "sample-plugin",
        "name": "Sample Plugin",
        "version": "1.0.0",
        "summary": "Sample plugin for validator tests",
        "author": "HorneroOS",
        "license": "GPL-3.0-only",
        "placement": "bar",
        "entrypoint": "Main.qml",
        "files": sorted(files.keys()),
        "capabilities": {
            "commands": commands or [],
            "networkHosts": [],
            "providers": [],
            "settings": {},
        },
    }
    (plugin_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    for rel, content in files.items():
        target = plugin_dir / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    return plugin_dir


@pytest.mark.parametrize(
    "snippet",
    [
        'Quickshell.execDetached(["id"])',
        'Qt.createQmlObject("import QtQuick; Item {}", root)',
        'Qt.createComponent("Evil.qml")',
        'eval("1+1")',
        'Function("return 1")()',
    ],
)
def test_validator_rejects_dangerous_patterns_in_qml_and_js(tmp_path: Path, snippet: str):
    qml_dir = _make_plugin(
        tmp_path / "qml",
        {"Main.qml": f"import QtQuick\nItem {{ Component.onCompleted: {{ {snippet} }} }}\n"},
    )
    with pytest.raises(vp.ValidationError):
        vp.validate_plugin(qml_dir)

    for ext in (".js", ".mjs"):
        js_dir = _make_plugin(
            tmp_path / f"js_{ext.lstrip('.')}",
            {
                "Main.qml": "import QtQuick\nItem {}\n",
                f"helper{ext}": f"function run() {{ {snippet}; }}\n",
            },
        )
        with pytest.raises(vp.ValidationError):
            vp.validate_plugin(js_dir)


def test_validator_rejects_single_quoted_process_command(tmp_path: Path):
    plugin_dir = _make_plugin(
        tmp_path,
        {"Main.qml": "import QtQuick\nimport Quickshell.Io\nItem { Process { command: ['date'] } }\n"},
        commands=["date"],
    )
    with pytest.raises(vp.ValidationError):
        vp.validate_plugin(plugin_dir)


@pytest.mark.parametrize("interp", ["python", "python3", "python3.12", "perl", "ruby", "node", "curl", "wget"])
def test_validator_rejects_script_interpreters_and_fetchers(tmp_path: Path, interp: str):
    plugin_dir = _make_plugin(
        tmp_path,
        {"Main.qml": f'import QtQuick\nimport Quickshell.Io\nItem {{ Process {{ command: ["{interp}"] }} }}\n'},
        commands=[interp],
    )
    with pytest.raises(vp.ValidationError):
        vp.validate_plugin(plugin_dir)


# ---------------------------------------------------------------------------
# #734: CMake asset excludes & PKGBUILD license
# ---------------------------------------------------------------------------


def test_cmake_excludes_companion_sources_and_preview():
    cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
    assert 'PATTERN "companion/sources" EXCLUDE' in cmake
    assert 'PATTERN "companion/preview" EXCLUDE' in cmake


def test_pkgbuild_license_is_gpl3_only():
    pkgbuild = (ROOT / "packaging" / "PKGBUILD").read_text(encoding="utf-8")
    assert "license=('GPL-3.0-only')" in pkgbuild

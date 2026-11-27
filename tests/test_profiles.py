"""Universal Profiles, Snapshots, Companion Apps & Studio Routing JS parser tests."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "profiles.js"


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/profiles.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_slugify_profile_id():
    out = run_js("""
        return {
            guitar: slugifyProfileId("Guitarra + Discord (Llamada)"),
            accents: slugifyProfileId("  Música & Café — Año 2026!  "),
            empty: slugifyProfileId("   ---   "),
            long: slugifyProfileId("a".repeat(80))
        };
    """)
    assert out["guitar"] == "guitarra-discord-llamada"
    assert out["accents"] == "musica-cafe-ano-2026"
    assert out["empty"] == ""
    assert len(out["long"]) == 64


def test_parse_profile_list_handles_json_strings_and_arrays():
    profiles_payload = [
        {
            "id": "baseline",
            "name": "Baseline",
            "description": "Default state",
            "domains": ["experience", "audio", "power", "extensions", "apps"],
            "is_baseline": True,
            "is_active": False,
            "hardware_ok": True,
            "companion_apps": [],
        },
        {
            "id": "guitarra-discord",
            "name": "Guitarra + Discord",
            "description": "Studio live bus",
            "domains": json.dumps(["experience", "audio", "apps"]),
            "is_baseline": False,
            "is_active": True,
            "hardware_ok": False,
            "hardware_missing": json.dumps(["Focusrite Scarlett 2i2"]),
            "companion_apps": ["reaper", "qpwgraph", "discord"],
            "running_apps": ["discord"],
            "missing_apps": ["reaper", "qpwgraph"],
        },
    ]
    env_string_encoded = {
        "command": "profile list",
        "ok": True,
        "message": "2 profiles",
        "data": {
            "active": "guitarra-discord",
            "has_baseline": "true",
            "has_previous": "true",
            "profiles": json.dumps(profiles_payload),
        },
    }
    env_array_encoded = {
        "command": "profile list",
        "ok": True,
        "message": "2 profiles",
        "data": {
            "active": "guitarra-discord",
            "has_baseline": True,
            "has_previous": False,
            "profiles": profiles_payload,
        },
    }
    out = run_js(f"""
        return {{
            strEnv: parseProfileList({json.dumps(json.dumps(env_string_encoded))}),
            arrEnv: parseProfileList({json.dumps(env_array_encoded)}),
            bad: parseProfileList("not json"),
            fail: parseProfileList({json.dumps({"ok": False, "message": "not initialized\ndetails", "data": {}})})
        }};
    """)
    s = out["strEnv"]
    assert s["available"] is True
    assert s["active"] == "guitarra-discord"
    assert s["hasBaseline"] is True
    assert s["hasPrevious"] is True
    assert len(s["profiles"]) == 2
    assert s["profiles"][0]["isBaseline"] is True
    assert s["profiles"][1]["hardwareOk"] is False
    assert s["profiles"][1]["hardwareMissing"] == ["Focusrite Scarlett 2i2"]
    assert s["profiles"][1]["appCount"] == 3
    assert s["profiles"][1]["runningAppCount"] == 1
    assert [a["id"] for a in s["profiles"][1]["missingApps"]] == ["reaper", "qpwgraph"]

    assert out["arrEnv"]["available"] is True
    assert out["arrEnv"]["hasPrevious"] is False
    assert len(out["arrEnv"]["profiles"]) == 2

    assert out["bad"]["available"] is False
    assert out["bad"]["profiles"] == []
    assert out["fail"]["available"] is False
    assert out["fail"]["error"] == "not initialized"


def test_parse_profile_show_and_diff_and_apply():
    show_env = {
        "command": "profile show",
        "ok": True,
        "message": "ok",
        "data": {
            "id": "guitarra-discord",
            "name": "Guitarra + Discord",
            "domains": json.dumps(["audio", "apps"]),
            "missing_apps": json.dumps([{"id": "reaper", "name": "REAPER"}]),
            "hardware_missing": json.dumps([]),
        },
    }
    diff_env = {
        "command": "profile diff",
        "ok": True,
        "message": "diff",
        "data": {
            "id": "guitarra-discord",
            "name": "Guitarra + Discord",
            "will_restart_pipewire": "true",
            "changes": json.dumps([
                {"domain": "audio", "key": "live-call", "from": "off", "to": "on"},
                "experience: everyday -> studio",
            ]),
            "hardware_missing": json.dumps(["USB Audio Interface"]),
            "missing_apps": json.dumps(["reaper", "qpwgraph"]),
            "warnings": json.dumps(["PipeWire will restart briefly"]),
        },
    }
    apply_env = {
        "command": "profile apply",
        "ok": True,
        "message": "Applied Guitarra + Discord",
        "data": {
            "id": "guitarra-discord",
            "pipewire_restarted": "true",
            "missing_apps": json.dumps(["reaper", "qpwgraph"]),
            "warnings": json.dumps(["USB Audio Interface disconnected"]),
        },
    }
    out = run_js(f"""
        return {{
            show: parseProfileShow({json.dumps(show_env)}),
            diff: parseProfileDiff({json.dumps(diff_env)}),
            apply: parseProfileApply({json.dumps(apply_env)})
        }};
    """)
    assert out["show"]["available"] is True
    assert out["show"]["id"] == "guitarra-discord"
    assert out["show"]["domains"] == ["audio", "apps"]
    assert out["show"]["missingApps"][0]["name"] == "REAPER"

    assert out["diff"]["available"] is True
    assert out["diff"]["willRestartPipewire"] is True
    assert len(out["diff"]["changes"]) == 2
    assert out["diff"]["changes"][0]["domain"] == "audio"
    assert out["diff"]["changes"][1]["summary"] == "experience: everyday -> studio"
    assert out["diff"]["hardwareMissing"] == ["USB Audio Interface"]
    assert len(out["diff"]["missingApps"]) == 2
    assert out["diff"]["warnings"] == ["PipeWire will restart briefly"]

    assert out["apply"]["ok"] is True
    assert out["apply"]["id"] == "guitarra-discord"
    assert out["apply"]["pipewireRestarted"] is True
    assert len(out["apply"]["missingApps"]) == 2
    assert out["apply"]["warnings"] == ["USB Audio Interface disconnected"]


def test_parse_routing_status_and_zero_volume_detection():
    routing_env = {
        "command": "studio routing status",
        "ok": True,
        "message": "ok",
        "data": {
            "kits": json.dumps([
                {"id": "live-call", "name": "Live Call", "active": True, "externally_managed": True},
                {"id": "browser-backing", "name": "Browser Backing", "active": False, "externally_managed": False},
                {"id": "reaper-low-latency", "name": "REAPER Low-Latency", "active": True, "externally_managed": False},
            ]),
            "streams": json.dumps([
                {"id": "42", "app_name": "WEBRTC VoiceEngine", "sink": "discord_call", "volume_pct": 0, "muted": False, "zero_volume_warning": True},
                {"id": "43", "app_name": "Zen Browser", "sink": "browser_backing", "volume_pct": 85, "muted": False, "zero_volume_warning": False},
                {"id": "44", "app_name": "Muted App", "sink": "alsa_output", "volume_pct": 0, "muted": True, "zero_volume_warning": False},
                {"id": "45", "app_name": "Silent Unmuted", "sink": "alsa_output", "volume_pct": 0, "muted": False},
            ]),
            "sinks": json.dumps([
                {"id": "10", "name": "alsa_output", "description": "Headphones", "is_default": True},
                {"id": "11", "name": "browser_backing", "description": "Browser Backing", "is_default": False},
                {"id": "12", "name": "discord_call", "description": "Discord Call", "is_default": False},
            ]),
        },
    }
    out = run_js(f"""
        const st = parseRoutingStatus({json.dumps(routing_env)});
        const direct = findZeroVolumeStreams(st.streams);
        return {{ st, direct }};
    """)
    st = out["st"]
    assert st["available"] is True
    assert len(st["kits"]) == 3
    assert st["kits"][0]["external"] is True
    assert st["kits"][1]["active"] is False
    assert len(st["sinks"]) == 3
    assert len(st["streams"]) == 4
    # Muted App (muted: true, zero_volume_warning: false) is excluded;
    # WEBRTC VoiceEngine and Silent Unmuted are detected.
    assert [s["id"] for s in st["zeroVolumeStreams"]] == ["42", "45"]
    assert [s["id"] for s in out["direct"]] == ["42", "45"]


def test_profiles_pane_registered_and_wired_cleanly():
    cc = ROOT / "modules" / "controlcenter"
    registry = (cc / "PaneRegistry.qml").read_text(encoding="utf-8")
    assert 'readonly property string id: "profiles"' in registry
    assert '"profiles/ProfilesPane.qml"' in registry
    assert 'category: "look"' in registry
    glyphs = set((ROOT / "assets" / "fonts" / "hornero-glyphs.names").read_text().split())
    assert "folders" in glyphs

    panes_qml = (cc / "Panes.qml").read_text(encoding="utf-8")
    assert 'import "profiles"' in panes_qml

    pane = (cc / "profiles" / "ProfilesPane.qml").read_text(encoding="utf-8")
    assert "required property Session session" in pane
    assert '"horneroctl", "--json", "profile", "list"' in pane
    assert '"horneroctl", "--json", "profile", "show"' in pane
    assert '"horneroctl", "--json", "profile", "diff"' in pane
    assert '"horneroctl", "--json", "profile", "apply"' in pane
    assert '"horneroctl", "--json", "profile", "revert", "--yes"' in pane
    assert '"horneroctl", "--json", "profile", "restore-baseline", "--yes"' in pane
    assert '"horneroctl", "--json", "profile", "capture"' in pane
    assert '"horneroctl", "--json", "profile", "launch-apps"' in pane
    assert '"horneroctl", "--json", "profile", "delete"' in pane
    assert "sh -c" not in pane


def test_studio_and_audio_panes_wire_routing_and_profiles():
    cc = ROOT / "modules" / "controlcenter"
    studio = (cc / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert '"horneroctl", "--json", "profile", "list"' in studio
    assert '"horneroctl", "--json", "studio", "routing", "status"' in studio
    for kit in ("live-call", "browser-backing", "reaper-low-latency"):
        assert kit in studio
    assert "Managed externally (read-only)" in studio
    assert "qpwgraph" in studio

    audio = (cc / "audio" / "AudioPane.qml").read_text(encoding="utf-8")
    assert '"horneroctl", "--json", "studio", "routing", "status"' in audio
    assert '"horneroctl", "--json", "studio", "routing", "fix-volume"' in audio
    assert '"horneroctl", "--json", "studio", "routing", "move-stream"' in audio
    assert "zeroVolumeStreams" in audio
    assert "Restore 100%" in audio


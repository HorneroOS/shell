"""Reload cover (reloadcover/): the stand-by slate `horneroctl shell restart`
shows on every screen while the main shell reloads.

Policy (reloadcover/cover.js) runs under node; dependency-freedom, the
watchdog and the motion budget are checked statically; the real
CoverState + Slate are rendered offscreen by tests/qml/reloadcover/
harness.qml when quickshell is installed (skipped, never faked,
otherwise). RC_SHOTS=<dir> keeps the renders.
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from signal_tokens import built_in_themes

ROOT = Path(__file__).resolve().parent.parent
COVER = ROOT / "reloadcover"
JS = COVER / "cover.js"
QS = shutil.which("qs")
NODE = shutil.which("node")
needs_node = pytest.mark.skipif(NODE is None, reason="node not installed")


def run_js(body: str):
    src = JS.read_text(encoding="utf-8").replace(".pragma library", "")
    out = subprocess.run(["node", "-e", src + "\n" + body], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def js_resolve(scheme: str, shell: str) -> dict:
    return run_js(f"console.log(JSON.stringify(resolve({json.dumps(scheme)}, {json.dumps(shell)})))")


def scheme_json(theme_id: str) -> str:
    t = built_in_themes()[theme_id]
    return json.dumps({"schemaVersion": 2, "id": theme_id, "mode": t["mode"], "palette": t["palette"],
                       "terminal": t["terminal"]})


# ---- static: the cover must load when the main config is broken ----

def test_cover_imports_nothing_from_the_shell():
    files = sorted(COVER.iterdir())
    assert {f.name for f in files} == {"shell.qml", "CoverState.qml", "Slate.qml", "HorneroMark.qml", "cover.js"}
    allowed = re.compile(r'^import (QtQuick(\.\w+)*|Quickshell(\.\w+)*|"cover\.js" as Cover)$')
    for f in files:
        if f.suffix != ".qml":
            continue
        for line in f.read_text().splitlines():
            if line.startswith("import "):
                assert allowed.match(line), f"{f.name}: {line}"
        assert "qs." not in f.read_text(), f.name
    js = JS.read_text()
    assert ".import" not in js and "require(" not in js


def test_watchdog_quits_after_60_seconds():
    src = (COVER / "shell.qml").read_text()
    m = re.search(r"Timer \{\s*interval: 60000\s*running: true\s*repeat: false\s*onTriggered: Qt\.quit\(\)", src)
    assert m, "the 60 s watchdog is gone"


def test_motion_budget_one_slow_clock_and_one_animation():
    shell = (COVER / "shell.qml").read_text()
    slate = (COVER / "Slate.qml").read_text()
    # shell.qml: the 1 s clock and the watchdog, nothing faster.
    intervals = [int(i) for i in re.findall(r"interval: (\d+)", shell)]
    assert sorted(intervals) == [1000, 60000]
    assert "Timer" not in slate and "Timer" not in (COVER / "CoverState.qml").read_text()
    # Slate: one sweep, only on the primary screen and only with motion on.
    assert slate.count("SequentialAnimation") == 1
    assert "running: root.primary && root.motion && root.visible" in slate
    assert all(int(d) >= 2000 for d in re.findall(r"duration: (\d+)", slate))
    # Javi's doze frames follow the 1 s clock, frozen when motion is off.
    assert "root.motion ? (root.elapsed % 4) + 1 : 1" in slate
    assert "motion: !live.cover.reducedMotion" in shell


def test_cover_reads_the_same_files_as_the_shell():
    state = (COVER / "CoverState.qml").read_text()
    assert "`${root.stateHome}/hornero/signal/scheme.json`" in state
    assert "`${root.configHome}/hornero/shell.json`" in state
    paths = (ROOT / "utils" / "Paths.qml").read_text()
    assert "signalScheme: `${state}/signal/scheme.json`" in paths
    assert 'Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`' in paths
    # Read-only: never written.
    assert "setText" not in state and "atomicWrites" not in state


def test_cover_and_its_art_are_installed_side_by_side():
    cmake = (ROOT / "CMakeLists.txt").read_text()
    assert 'install(DIRECTORY reloadcover DESTINATION "${INSTALL_QSCONFDIR}")' in cmake
    assert "foreach(dir assets components config modules services utils)" in cmake
    slate = (COVER / "Slate.qml").read_text()
    assert 'Qt.resolvedUrl("../assets/companion/frames/default-sleep-0")' in slate
    for n in range(1, 5):
        assert (ROOT / f"assets/companion/frames/default-sleep-0{n}.png").is_file()
    # Missing art degrades to no sprite, never a broken image.
    assert "visible: root.cover.mascot && status === Image.Ready" in slate


@needs_node
def test_builtin_tables_match_signal():
    themes = built_in_themes()
    tables = run_js("console.log(JSON.stringify({roles: ROLES, night: NIGHT, day: DAY, contrast: CONTRAST}))")
    for key, theme in (("night", "hornero-signal-night"), ("day", "hornero-signal-day"),
                       ("contrast", "hornero-signal-contrast")):
        for role in tables["roles"]:
            assert tables[key][role] == themes[theme]["palette"][role], (key, role)


# ---- policy ----

@needs_node
def test_missing_or_invalid_scheme_falls_back_to_signal_night():
    night = built_in_themes()["hornero-signal-night"]["palette"]
    good = json.loads(scheme_json("hornero-signal-day"))
    missing_role = json.loads(json.dumps(good))
    del missing_role["palette"]["inkFaint"]
    bad_hex = json.loads(json.dumps(good))
    bad_hex["palette"]["signal"] = "orange"
    for scheme in ("", "{not json", "[]", "null", json.dumps({"palette": None}),
                   json.dumps(missing_role), json.dumps(bad_hex)):
        r = js_resolve(scheme, "")
        assert r["source"] == "fallback", scheme
        assert r["palette"]["ground"] == night["ground"] and r["light"] is False


@needs_node
def test_live_scheme_wins_including_light_and_chromatic():
    r = js_resolve(scheme_json("hornero-signal-day"), "")
    assert r["source"] == "scheme" and r["light"] is True
    assert r["palette"]["ground"] == built_in_themes()["hornero-signal-day"]["palette"]["ground"]
    chroma = json.loads(scheme_json("hornero-signal-night"))
    chroma.update({"id": "chromatic-wallpaper", "mode": "dark"})
    chroma["palette"]["signal"] = "#C08AF0"
    chroma["chromatic"] = {"variant": "vibrant"}
    r = js_resolve(json.dumps(chroma), "")
    assert r["source"] == "scheme" and r["palette"]["signal"] == "#C08AF0"


@needs_node
def test_high_contrast_overrides_the_theme_and_builtin_id_without_scheme():
    contrast = built_in_themes()["hornero-signal-contrast"]["palette"]
    shell = json.dumps({"appearance": {"highContrast": True}})
    r = js_resolve(scheme_json("hornero-signal-day"), shell)
    assert r["source"] == "contrast" and r["highContrast"] is True and r["light"] is False
    assert r["palette"]["ink"] == contrast["ink"]
    r = js_resolve("", json.dumps({"appearance": {"theme": "hornero-signal-day"}}))
    assert r["source"] == "builtin" and r["light"] is True


@needs_node
def test_settings_from_shell_json():
    r = js_resolve("", "")
    assert r["reducedMotion"] is False and r["mascot"] is True
    assert (r["sans"], r["mono"], r["display"]) == ("IBM Plex Sans", "IBM Plex Mono", "IBM Plex Sans Condensed")
    shell = {"appearance": {"reducedMotion": True, "atmosphere": {"mascot": False},
                            "font": {"family": {"sans": "Inter", "mono": "", "display": 7}}}}
    r = js_resolve("", json.dumps(shell))
    assert r["reducedMotion"] is True and r["mascot"] is False
    assert (r["sans"], r["mono"], r["display"]) == ("Inter", "IBM Plex Mono", "IBM Plex Sans Condensed")
    # Defaults match the shipped shell defaults.
    defaults = json.loads((ROOT / "config/shell.default.json").read_text())["appearance"]
    assert defaults["reducedMotion"] is False and defaults["atmosphere"]["mascot"] is True
    assert defaults["font"]["family"]["display"] == "IBM Plex Sans Condensed"


@needs_node
def test_language_copy_screen_and_timecode():
    r = run_js("""console.log(JSON.stringify([
        language(["", "", "", "es_AR.UTF-8", "en_US"]), language(["es:en", "", "", "en_US.UTF-8", ""]),
        language(["", "C.UTF-8", "", "es_ES.UTF-8", ""]), language(["", "", "", "", "de_DE"]),
        language(["", "", "", "", ""]), language(["POSIX", "", "", "", "es_MX"]),
        text("es", "status"), text("en", "status"), text("fr", "title"),
        primaryScreen('[{"name":"DP-1","focused":false},{"name":"HDMI-A-1","focused":true}]', ["DP-1", "HDMI-A-1"]),
        primaryScreen("garbage", ["DP-1"]), primaryScreen('[{"name":"X","focused":true}]', ["DP-1"]),
        primaryScreen("[]", []),
        timecode(0), timecode(7.9), timecode(65), timecode(-3)]))""")
    assert r[:6] == ["es", "es", "es", "en", "en", "es"]
    assert r[6] == "Reiniciando el shell · tus ventanas siguen intactas"
    assert r[7] == "Restarting the shell · your windows are untouched"
    assert r[8] == "STAND BY"
    assert r[9:13] == ["HDMI-A-1", "DP-1", "DP-1", ""]
    assert r[13:] == ["T+00:00", "T+00:07", "T+01:05", "T+00:00"]


@needs_node
def test_every_copy_key_exists_in_both_languages():
    r = run_js("console.log(JSON.stringify([Object.keys(COPY.es).sort(), Object.keys(COPY.en).sort()]))")
    assert r[0] == r[1]
    slate = (COVER / "Slate.qml").read_text()
    for key in re.findall(r'root\.t\("(\w+)"\)', slate):
        assert key in r[0], key


# ---- offscreen renders ----

SCENES = [
    # name, scheme theme (None = no file, "invalid" = junk), shell.json, env, size, primary, elapsed
    ("night-es-1920x1080", "hornero-signal-night", {}, {"LANG": "es_AR.UTF-8"}, (1920, 1080), True, 3),
    ("night-en-2560x1440", "hornero-signal-night", {}, {"LANG": "en_US.UTF-8"}, (2560, 1440), True, 3),
    ("day-es-1920x1080", "hornero-signal-day", {}, {"LANG": "es_AR.UTF-8"}, (1920, 1080), True, 3),
    ("day-en-2560x1440", "hornero-signal-day", {}, {"LANG": "en_US.UTF-8"}, (2560, 1440), True, 3),
    ("contrast-es-1920x1080", "hornero-signal-day", {"appearance": {"highContrast": True}},
     {"LANG": "es_AR.UTF-8"}, (1920, 1080), True, 3),
    ("fallback-invalid-es-1920x1080", "invalid", {}, {"LANG": "es_AR.UTF-8"}, (1920, 1080), True, 3),
    ("slow-hint-es-1920x1080", "hornero-signal-night", {}, {"LANG": "es_AR.UTF-8"}, (1920, 1080), True, 21),
    ("quiet-secondary-es-1920x1080", "hornero-signal-night", {}, {"LANG": "es_AR.UTF-8"}, (1920, 1080), False, 3),
    ("reduced-nomascot-en-1920x1080", "hornero-signal-night",
     {"appearance": {"reducedMotion": True, "atmosphere": {"mascot": False}}},
     {"LANG": "en_US.UTF-8"}, (1920, 1080), True, 3),
]


def _render(tmp: Path, shots: Path, scene) -> dict:
    name, theme, shell, extra, (w, h), primary, elapsed = scene
    root = tmp / name / "root"
    root.mkdir(parents=True)
    shutil.copytree(COVER, root / "reloadcover")
    os.symlink(ROOT / "assets", root / "assets")
    shutil.copy(ROOT / "tests/qml/reloadcover/harness.qml", root / "shell.qml")
    xdg = tmp / name / "xdg"
    for sub in ("config/hornero", "state/hornero/signal", "data", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    if theme == "invalid":
        (xdg / "state/hornero/signal/scheme.json").write_text("{\"palette\": {\"ground\": \"#zz\"")
    elif theme:
        (xdg / "state/hornero/signal/scheme.json").write_text(scheme_json(theme))
    if shell:
        (xdg / "config/hornero/shell.json").write_text(json.dumps(shell))
    out = shots / f"{name}.png"
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
        "RC_OUT": str(out), "RC_W": str(w), "RC_H": str(h),
        "RC_PRIMARY": "1" if primary else "0", "RC_ELAPSED": str(elapsed), **extra,
    }
    # One retry: software-GL offscreen quickshell very rarely dies before
    # the first frame (seen once in ~40 local runs). Both attempts are
    # logged, and a second failure fails the test.
    log = ""
    for attempt in (1, 2):
        proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root / "shell.qml"), "--no-duplicate"],
                              capture_output=True, text=True, timeout=120, env=env, cwd=tmp)
        log += f"--- attempt {attempt} rc={proc.returncode}\n" + re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
        if "COVER " in log:
            break
    (shots / f"{name}.log").write_text(log)
    lines = [ln for ln in log.splitlines() if "COVER " in ln]
    assert lines, f"{name}: harness never reported:\n{log[-3000:]}"
    assert "ReferenceError" not in log and "TypeError" not in log, log[-3000:]
    return json.loads(lines[-1].split("COVER ", 1)[1])


@pytest.fixture(scope="module")
def renders(tmp_path_factory):
    if not QS or shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: quickshell (qs) or dbus-run-session is not installed")
    base = tmp_path_factory.mktemp("reloadcover")
    shots = Path(os.environ["RC_SHOTS"]) if os.environ.get("RC_SHOTS") else base / "shots"
    shots.mkdir(parents=True, exist_ok=True)
    return {s[0]: _render(base, shots, s) for s in SCENES}, shots


def _px(shots: Path, name: str, xy):
    Image = pytest.importorskip("PIL.Image")
    return "#{:02X}{:02X}{:02X}".format(*Image.open(shots / f"{name}.png").convert("RGB").getpixel(xy))


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_renders_resolve_the_live_palette(renders):
    report, shots = renders
    themes = built_in_themes()
    assert report["night-es-1920x1080"]["source"] == "scheme"
    assert report["day-es-1920x1080"]["light"] is True
    assert report["contrast-es-1920x1080"]["source"] == "contrast"
    assert report["fallback-invalid-es-1920x1080"]["source"] == "fallback"
    # The screen ground really is the theme's ground (corner pixel).
    assert _px(shots, "night-es-1920x1080", (5, 5)) == themes["hornero-signal-night"]["palette"]["ground"]
    assert _px(shots, "day-en-2560x1440", (5, 5)) == themes["hornero-signal-day"]["palette"]["ground"]
    assert _px(shots, "contrast-es-1920x1080", (5, 5)) == themes["hornero-signal-contrast"]["palette"]["ground"]
    assert _px(shots, "fallback-invalid-es-1920x1080", (5, 5)) == themes["hornero-signal-night"]["palette"]["ground"]
    # Card panel in the middle of the slate, left of the title.
    assert _px(shots, "day-es-1920x1080", (960 - 300, 540)) == themes["hornero-signal-day"]["palette"]["panel"]


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_renders_sizes_language_mascot_and_motion(renders):
    report, _ = renders
    assert (report["night-en-2560x1440"]["w"], report["night-en-2560x1440"]["h"]) == (2560, 1440)
    assert report["night-es-1920x1080"]["lang"] == "es" and report["night-en-2560x1440"]["lang"] == "en"
    assert report["night-es-1920x1080"]["javi"] is True
    assert report["quiet-secondary-es-1920x1080"]["javi"] is False
    r = report["reduced-nomascot-en-1920x1080"]
    assert r["reducedMotion"] is True and r["mascot"] is False and r["javi"] is False
    assert not any(v["sweeping"] for v in report.values())

"""Experience modes (RFC 0001 §5a, Signal Visual Language §13).

The profile model, customisation rules, state parsing, legacy migration
and automatic-switch decisions are a pure JS module
(services/experience.js) executed under node. Static contracts pin how
services/Experience.qml persists state, exposes IPC, and how the shell
consumes the derived behaviour (motion, notifications, telemetry,
desktop layer, Hyprland tuning).
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "experience.js"
QML = (ROOT / "services" / "Experience.qml").read_text()
IPC_DOC = (ROOT / "docs" / "IPC.md").read_text()
MODES = ["focus", "everyday", "signal", "gaming", "studio"]


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/experience.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


# --- Factory profiles ------------------------------------------------------

def test_modes_and_default():
    out = run_js("return {ids: MODE_IDS, def: DEFAULT_MODE, layout: FACTORY_LAYOUT, theme: FACTORY_THEME};")
    assert out["ids"] == MODES
    assert out["def"] == "everyday"
    assert out["layout"] == "cockpit"
    assert out["theme"] == "hornero-signal-night"


def test_every_factory_profile_sets_every_field_with_a_valid_value():
    out = run_js("""
        const bad = [];
        for (const m of MODE_IDS) {
            const f = FACTORY[m].fields;
            for (const k of Object.keys(FIELDS)) {
                if (!(k in f)) bad.push(m + ':missing:' + k);
                else if (validateField(k, f[k]) !== f[k]) bad.push(m + ':invalid:' + k);
            }
            for (const k of Object.keys(f)) if (!(k in FIELDS)) bad.push(m + ':unknown:' + k);
        }
        return bad;
    """)
    assert out == []


def test_factory_profiles_follow_the_visual_language():
    p = run_js("const o = {}; for (const m of MODE_IDS) o[m] = resolve(m, {}).fields; return o;")
    # Focus: maximum space, quiet motion, notifications held.
    assert p["focus"]["motion"] == "reduced"
    assert p["focus"]["density"] == "icons"
    assert p["focus"]["notifications.hold"] is True
    assert p["focus"]["desktopWidgets"] == "none"
    assert p["focus"]["layout.preset"] == "minimal-top"
    assert p["focus"]["glow"] is False
    # Everyday: balanced default on Cockpit.
    assert p["everyday"]["motion"] == "standard"
    assert p["everyday"]["density"] == "values"
    assert p["everyday"]["layout.preset"] == "cockpit"
    assert p["everyday"]["glow"] is False
    assert p["everyday"]["telemetry.rateHz"] == 1
    # Signal: richest telemetry and motion.
    assert p["signal"]["motion"] == "full"
    assert p["signal"]["density"] == "labels"
    assert p["signal"]["glow"] is True and p["signal"]["scanlines"] is True
    assert p["signal"]["telemetry.rateHz"] == 2
    assert p["signal"]["desktopWidgets"] == "instruments"
    # Gaming: out of the way, never polls at a cost.
    g = p["gaming"]
    assert g["motion"] == "off" and g["glow"] is False and g["scanlines"] is False
    assert g["notifications.hold"] is True
    assert g["telemetry.pauseWhenHidden"] is True
    assert g["desktopWidgets"] == "none"
    assert g["hooks.hyprlandTuning"] is True
    assert g["layout.preset"] == "gaming"
    # Studio: stable canvas, no glow.
    assert p["studio"]["motion"] == "standard"
    assert p["studio"]["glow"] is False
    assert p["studio"]["layout.preset"] == "studio"
    # Layouts are only suggested by default: presets rewrite the bars.
    assert all(p[m]["layout.apply"] is False for m in MODES)
    # Only gaming touches Hyprland; nobody changes studio audio unasked.
    assert [m for m in MODES if p[m]["hooks.hyprlandTuning"]] == ["gaming"]
    # Only a deliberate switch into studio applies the audio profile.
    assert [m for m in MODES if p[m]["hooks.studioAudio"]] == ["studio"]


def test_signal_is_strictly_richer_than_everyday():
    p = run_js("return {e: resolve('everyday', {}).fields, s: resolve('signal', {}).fields};")
    order = {"icons": 0, "values": 1, "labels": 2}
    motion = {"off": 0, "reduced": 1, "standard": 2, "full": 3}
    assert order[p["s"]["density"]] > order[p["e"]["density"]]
    assert motion[p["s"]["motion"]] > motion[p["e"]["motion"]]
    assert p["s"]["telemetry.rateHz"] > p["e"]["telemetry.rateHz"]
    assert p["s"]["glow"] and not p["e"]["glow"]
    assert p["s"]["desktopWidgets"] == "instruments" and p["e"]["desktopWidgets"] == "user"


def test_profile_glyphs_are_hornero_glyphs():
    names = set((ROOT / "assets" / "fonts" / "hornero-glyphs.names").read_text().split())
    glyphs = run_js("return MODE_IDS.map(m => FACTORY[m].glyph);")
    assert set(glyphs) <= names, set(glyphs) - names


# --- Customisations --------------------------------------------------------

def test_overrides_apply_and_are_reported():
    out = run_js("""
        const r = resolve('everyday', {everyday: {'motion': 'full', 'telemetry.rateHz': 2}});
        return {f: r.fields, c: r.customised};
    """)
    assert out["f"]["motion"] == "full"
    assert out["f"]["telemetry.rateHz"] == 2
    assert out["c"] == ["motion", "telemetry.rateHz"]


def test_locked_guardrails_ignore_overrides():
    out = run_js("""
        const g = resolve('gaming', {gaming: {glow: true, motion: 'full', scanlines: true}});
        const f = resolve('focus', {focus: {glow: true}});
        const set = setOverride({}, 'gaming', 'glow', true);
        return {g: g.fields, gc: g.customised, gl: g.locked, f: f.fields.glow, set: set};
    """)
    assert out["g"]["glow"] is False
    assert out["g"]["motion"] == "off"
    assert out["g"]["scanlines"] is False
    assert out["gc"] == []
    assert out["gl"] == ["glow", "motion", "scanlines"]
    assert out["f"] is False
    assert out["set"]["ok"] is False and "fixed" in out["set"]["error"]


def test_sanitize_drops_unknown_invalid_and_factory_equal_values():
    out = run_js("""
        return sanitizeOverrides({
            everyday: {motion: 'warp', density: 'labels', bogus: 1, glow: false,
                       'telemetry.rateHz': 99, 'layout.preset': '../../etc'},
            nonsense: {motion: 'off'},
            studio: 'not-an-object'
        });
    """)
    # motion invalid, bogus unknown, glow equals factory, preset unsafe;
    # the rate is clamped to the allowed maximum.
    assert out == {"everyday": {"density": "labels", "telemetry.rateHz": 4}}


def test_set_override_keeps_other_modes_and_clears_with_null():
    out = run_js("""
        let o = {focus: {'notifications.hold': false}};
        const a = setOverride(o, 'signal', 'desktopWidgets', 'user');
        const b = setOverride(a.overrides, 'signal', 'desktopWidgets', null);
        const c = setOverride(b.overrides, 'signal', 'motion', 'standard');
        const d = setOverride(c.overrides, 'signal', 'motion', 'full');
        const bad = setOverride(d.overrides, 'signal', 'motion', 'warp');
        const unk = setOverride(d.overrides, 'nope', 'motion', 'off');
        return {a: a.overrides, b: b.overrides, c: c.overrides, d: d.overrides,
                bad: bad.ok, unk: unk.ok, cleared: clearOverrides(c.overrides, 'signal')};
    """)
    assert out["a"] == {"focus": {"notifications.hold": False}, "signal": {"desktopWidgets": "user"}}
    assert out["b"] == {"focus": {"notifications.hold": False}}
    assert out["c"] == {"focus": {"notifications.hold": False}, "signal": {"motion": "standard"}}
    # Setting the factory value removes the override instead of storing it.
    assert out["d"] == {"focus": {"notifications.hold": False}}
    assert out["bad"] is False and out["unk"] is False
    assert out["cleared"] == {"focus": {"notifications.hold": False}}


# --- State file ------------------------------------------------------------

def test_state_parse_accepts_full_and_minimal_forms_and_fails_closed():
    out = run_js("""
        return {
            full: parseState(JSON.stringify({schemaVersion: 1, mode: 'signal', previous: 'focus',
                source: 'user', auto: false, changedAt: 'x', studioAudioRestore: 'balanced'})),
            minimal: parseState('{"schemaVersion":1,"mode":"focus"}'),
            badMode: parseState('{"schemaVersion":1,"mode":"party"}'),
            badSchema: parseState('{"schemaVersion":2,"mode":"focus"}'),
            notJson: parseState('{mode: focus'),
            array: parseState('[]'),
            badRestore: parseState('{"schemaVersion":1,"mode":"studio","studioAudioRestore":"rm -rf"}')
        };
    """)
    assert out["full"]["mode"] == "signal" and out["full"]["previous"] == "focus"
    assert out["full"]["studioAudioRestore"] == "balanced"
    assert out["minimal"] == {
        "schemaVersion": 1, "mode": "focus", "previous": "focus", "source": "cli",
        "auto": False, "changedAt": "", "studioAudioRestore": "",
    }
    assert out["badMode"] is None and out["badSchema"] is None
    assert out["notJson"] is None and out["array"] is None
    assert out["badRestore"]["studioAudioRestore"] == ""


def test_state_serialization_round_trips():
    out = run_js("""
        const st = transition(defaultState(), 'gaming', 'auto', '2026-01-01T00:00:00.000Z').state;
        const text = serializeState(st);
        return {text: text, back: parseState(text)};
    """)
    assert out["back"]["mode"] == "gaming"
    assert out["back"]["previous"] == "everyday"
    assert out["back"]["auto"] is True and out["back"]["source"] == "auto"
    assert json.loads(out["text"])["schemaVersion"] == 1
    assert out["text"].endswith("\n")


def test_transition_tracks_previous_and_rejects_unknown_modes():
    out = run_js("""
        let s = defaultState();
        const a = transition(s, 'focus', 'user', 't1').state;
        const b = transition(a, 'focus', 'cli', 't2');
        const c = transition(b.state, 'studio', 'cli', 't3').state;
        const bad = transition(c, 'disco', 'user', 't4');
        return {a: a, bChanged: b.changed, bPrev: b.state.previous, c: c, bad: bad.ok};
    """)
    assert out["a"]["previous"] == "everyday" and out["a"]["mode"] == "focus"
    # Re-selecting the active mode keeps the previous mode for revert.
    assert out["bChanged"] is False and out["bPrev"] == "everyday"
    assert out["c"]["previous"] == "focus" and out["c"]["source"] == "cli"
    assert out["bad"] is False


# --- Retired preset migration ----------------------------------------------

def test_restored_presets_keep_the_persisted_selection():
    out = run_js(
        'return {'
        'a: sanitizeOverrides({everyday: {"layout.preset": "floating-island"}}),'
        'b: sanitizeOverrides({focus: {"layout.preset": "productivity"}}),'
        'c: sanitizeOverrides({studio: {"layout.preset": "classic-top"}}),'
        'retired: RETIRED_PRESETS}'
    )
    # Floating Island and Productivity are supported presets again: no
    # one-shot migration may move users off them.
    assert out["a"] == {"everyday": {"layout.preset": "floating-island"}}
    assert out["b"] == {"focus": {"layout.preset": "productivity"}}
    assert out["c"] == {"studio": {"layout.preset": "classic-top"}}
    assert out["retired"] == {}
    assert "Model.sanitizeOverrides(Config.experience.modes)" in QML


# --- Legacy migration ------------------------------------------------------

def test_active_legacy_game_mode_becomes_gaming_once():
    out = run_js("""
        return {
            on: migrateLegacy({gameModeEnabled: true, hasState: false}),
            off: migrateLegacy({gameModeEnabled: false, hasState: false}),
            existing: migrateLegacy({gameModeEnabled: true, hasState: true}),
            none: migrateLegacy(null)
        };
    """)
    assert out["on"]["state"]["mode"] == "gaming"
    assert out["on"]["state"]["source"] == "migration"
    assert out["on"]["state"]["previous"] == "everyday"
    assert out["off"]["state"] is None and out["off"]["changed"] is False
    assert out["existing"]["state"] is None
    assert out["none"]["changed"] is False


def test_legacy_toast_switch_moves_to_experience_toasts():
    out = run_js("""
        return [
            toastsFromLegacy({utilities: {toasts: {gameModeChanged: false}}}),
            toastsFromLegacy({utilities: {toasts: {gameModeChanged: true}}, experience: {toasts: false}}),
            toastsFromLegacy({utilities: {toasts: {}}}) === undefined
        ];
    """)
    assert out == [False, None, True]
    config = (ROOT / "config" / "Config.qml").read_text()
    body = config[config.index("function migrateLegacyExperience"):]
    body = body[: body.index("\n    }\n")]
    assert "data?.utilities?.toasts?.gameModeChanged" in body
    assert "data?.experience?.toasts === undefined" in body
    assert "adapter.experience.toasts = legacy" in body
    assert "root.migrateLegacyExperience(text())" in config
    # The retired key is gone from the schema, serializer and defaults.
    assert "gameModeChanged" not in (ROOT / "config" / "UtilitiesConfig.qml").read_text()
    assert "gameModeChanged: utilities.toasts.gameModeChanged" not in config
    defaults = json.loads((ROOT / "config" / "shell.default.json").read_text())
    assert "gameModeChanged" not in defaults["utilities"]["toasts"]
    assert defaults["experience"] == {
        "modes": {}, "deck": {}, "toasts": True, "auto": {"fullscreenGaming": False, "gamePatterns": []},
    }


# --- Automatic switching ---------------------------------------------------

@pytest.mark.parametrize("app_id,game", [
    ("steam_app_570", True),
    ("gamescope", True),
    ("Game.exe", True),
    ("kitty", False),
    ("firefox", False),
    ("", False),
])
def test_default_game_patterns(app_id, game):
    assert run_js(f"return isGameWindow({json.dumps(app_id)}, []);") is game


def test_auto_switch_is_off_by_default_and_never_overrides_the_user():
    out = run_js("""
        const st = defaultState();
        const game = {fullscreen: true, appId: 'steam_app_1', patterns: []};
        const userGaming = transition(st, 'gaming', 'user', '').state;
        const autoGaming = transition(st, 'gaming', 'auto', '').state;
        return {
            disabled: autoDecision(st, Object.assign({enabled: false}, game)),
            enter: autoDecision(st, Object.assign({enabled: true}, game)),
            notFullscreen: autoDecision(st, {enabled: true, fullscreen: false, appId: 'steam_app_1'}),
            nonGame: autoDecision(st, {enabled: true, fullscreen: true, appId: 'mpv'}),
            leaveAuto: autoDecision(autoGaming, {enabled: true, fullscreen: false, appId: 'kitty'}),
            keepUser: autoDecision(userGaming, {enabled: true, fullscreen: false, appId: 'kitty'}),
            badPattern: isGameWindow('x', ['(']),
            custom: isGameWindow('retroarch', ['^retroarch$'])
        };
    """)
    assert out["disabled"] == ""
    assert out["enter"] == "enter"
    assert out["notFullscreen"] == "" and out["nonGame"] == ""
    assert out["leaveAuto"] == "leave"
    assert out["keepUser"] == ""
    assert out["badPattern"] is False and out["custom"] is True


def test_telemetry_interval_and_bar_density_mapping():
    out = run_js("""
        return {
            everyday: telemetryInterval(resolve('everyday', {}).fields, 3000),
            signal: telemetryInterval(resolve('signal', {}).fields, 3000),
            none: telemetryInterval({}, 3000),
            focusBar: barDensity(resolve('focus', {}).fields, 'values'),
            everydayBar: barDensity(resolve('everyday', {}).fields, 'values'),
            everydayGlyphBar: barDensity(resolve('everyday', {}).fields, 'glyphs'),
            signalBar: barDensity(resolve('signal', {}).fields, 'glyphs')
        };
    """)
    assert out["everyday"] == 1000 and out["signal"] == 500 and out["none"] == 3000
    assert out["focusBar"] == "glyphs"
    assert out["everydayBar"] == "values" and out["everydayGlyphBar"] == "glyphs"
    assert out["signalBar"] == "values"


# --- Service contracts (static) --------------------------------------------

def _ipc_functions(src, target):
    block = src[src.index(f'target: "{target}"'):]
    return set(re.findall(r"function\s+(\w+)\s*\(", block))


def test_ipc_surface_matches_the_documented_contract():
    funcs = _ipc_functions(QML, "experience")
    required = {"get", "set", "list", "reset", "revert", "toggle", "status", "profile",
                "customise", "resetCustomisations", "setAuto"}
    assert required <= funcs, required - funcs
    for fn in required:
        assert f"`experience {fn}" in IPC_DOC or f"`{fn}(" in IPC_DOC, fn
    # IPC switches are recorded as CLI-sourced.
    assert 'return root.set(mode, "cli");' in QML


def test_state_file_is_written_atomically_and_watched():
    paths = (ROOT / "utils" / "Paths.qml").read_text()
    assert "experienceState: `${state}/experience.json`" in paths
    assert "path: root.statePath" in QML and "Paths.experienceState" in QML
    assert "watchChanges: true" in QML
    assert 'mv -f "$tmp" "$HORNERO_EXPERIENCE_STATE"' in QML
    # The payload travels in the environment, never interpolated into sh -c.
    assert '"HORNERO_EXPERIENCE_PAYLOAD": writeProc.payload' in QML
    assert "Model.parseState(text())" in QML
    for key in ("schemaVersion", "mode", "previous", "source", "auto", "changedAt", "studioAudioRestore"):
        assert f'"{key}"' in IPC_DOC, key
    assert "${XDG_STATE_HOME:-~/.local/state}/hornero/experience.json" in IPC_DOC


def test_reset_returns_to_factory_mode_layout_and_theme():
    body = QML[QML.index("function reset(): string"):]
    body = body[: body.index("\n    }\n")]
    assert "Model.DEFAULT_MODE" in body and '"reset"' in body
    assert '["horneroctl", "shell", "preset", "apply", Model.FACTORY_LAYOUT, "--yes"]' in body
    assert "ThemePipeline.applyTheme(Model.FACTORY_THEME" in body
    # Customisations are never dropped by a reset.
    assert "Config.experience.modes" not in body


def test_customisations_persist_in_shell_json():
    config = (ROOT / "config" / "Config.qml").read_text()
    assert "property ExperienceConfig experience: ExperienceConfig {}" in config
    assert "experience: serializeExperience()" in config
    ser = config[config.index("function serializeExperience"):]
    ser = ser[: ser.index("\n    }\n")]
    for key in ("modes: experience.modes", "toasts: experience.toasts",
                "fullscreenGaming: experience.auto.fullscreenGaming",
                "gamePatterns: experience.auto.gamePatterns"):
        assert key in ser
    assert "Config.experience.modes = res.overrides;" in QML
    assert "Config.save();" in QML


def test_game_mode_is_the_gaming_hook_not_a_second_toggle():
    game = (ROOT / "services" / "GameMode.qml").read_text()
    assert "readonly property bool enabled: Experience.hyprlandTuning" in game
    assert "IpcHandler" not in game
    assert 'reloadableId: "gameMode"' in game  # read once for migration
    assert "GameMode.legacyEnabled" in QML
    for rel in ("modules/utilities/cards/Toggles.qml", "modules/dashboard/dash/QuickToggles.qml",
                "modules/controlcenter/gaming/GamingPane.qml"):
        src = (ROOT / rel).read_text()
        assert 'Experience.toggle("gaming")' in src, rel
        assert "GameMode.enabled =" not in src and "GameMode.toggle" not in src, rel


def test_motion_level_drives_appearance_tokens():
    appearance = (ROOT / "config" / "Appearance.qml").read_text()
    assert 'property string level: "standard"' in appearance
    assert '(Config.appearance.reducedMotion || SystemMotion.reduced) ? "off"' in appearance
    assert 'readonly property bool reduced: effectiveLevel === "off"' in appearance
    assert 'effectiveLevel === "reduced" ? _scale * 0.5' in appearance
    assert 'readonly property bool spatial: effectiveLevel === "full" || effectiveLevel === "standard"' in appearance
    assert "Appearance.anim.level = Qt.binding(() => root.motionLevel)" in QML


def test_glow_is_never_on_in_day_high_contrast_or_low_motion():
    line = next(l for l in QML.splitlines() if "readonly property bool glow:" in l)
    assert 'fields["glow"]' in line and "!Signal.light" in line
    assert "!Config.appearance.highContrast" in line
    assert 'motionLevel === "full" || motionLevel === "standard"' in line


def test_notification_policy_holds_non_critical_popups_only():
    notifs = (ROOT / "services" / "Notifs.qml").read_text()
    assert "ExperienceModel.notificationDisposition(Experience.holdPopups, critical, props.dnd)" in notifs
    assert "popup: route.popup" in notifs
    assert "Experience.noteHeld()" in notifs
    hold = next(l for l in QML.splitlines() if "readonly property bool holdPopups:" in l)
    assert "policy.holdPopups" in hold
    assert "_toastHeld()" in QML


def test_telemetry_rate_and_pause_follow_the_mode():
    for rel in ("services/SystemUsage.qml", "services/NetworkUsage.qml"):
        src = (ROOT / rel).read_text()
        assert "interval: Experience.telemetryIntervalMs" in src, rel
        assert "root.refCount > 0 && !Experience.telemetryPaused" in src, rel
    assert "readonly property bool telemetryPaused: policy.telemetryPaused" in QML


def test_gaming_hides_the_desktop_layer_under_fullscreen():
    line = next(l for l in QML.splitlines() if "readonly property bool desktopWidgetsVisible:" in l)
    assert "policy.desktopWidgetsVisible" in line
    background = (ROOT / "modules" / "background" / "Background.qml").read_text()
    assert "Config.background.desktopClock.enabled && Experience.desktopWidgetsVisible" in background
    assert "opacity: Experience.desktopWidgetsVisible ? 1 : 0" in background


def test_studio_audio_hook_uses_the_reversible_horneroctl_profile():
    assert '["horneroctl", "--json", "studio", "audio", "apply", "--yes"]' in QML
    assert '["horneroctl", "--json", "studio", "audio", "revert", "--yes"]' in QML
    assert '["horneroctl", "--json", "studio", "audio", "status"]' in QML
    assert "Model.studioAudioAction(root.studioAudioWanted, root.studioAudioRestore !== \"\", src)" in QML
    # Reconciling at start is never an apply.
    assert 'root._syncStudioAudio("startup")' in QML
    # The old intent-only path is gone.
    assert '"studio", "mode", "audio"' not in QML


@pytest.mark.parametrize("wanted,applied,source,expected", [
    (True, False, "user", "apply"),
    (True, False, "cli", "apply"),
    (True, False, "auto", "none"),
    (True, False, "startup", "none"),
    (True, False, "reset", "none"),
    (True, False, "migration", "none"),
    (True, True, "user", "none"),
    (False, True, "user", "revert"),
    (False, True, "auto", "revert"),
    (False, True, "reset", "revert"),
    (False, True, "startup", "revert"),
    (False, False, "user", "none"),
])
def test_studio_audio_action_table(wanted, applied, source, expected):
    out = run_js(f"return studioAudioAction({json.dumps(wanted)}, {json.dumps(applied)}, {json.dumps(source)});")
    assert out == expected


def test_studio_profile_applies_audio_but_no_other_mode_does():
    assert policy_fields("studio")["hooks.studioAudio"] is True
    for mode in ("focus", "everyday", "signal", "gaming"):
        assert policy_fields(mode)["hooks.studioAudio"] is False


def policy_fields(mode):
    return run_js(f"return resolve({json.dumps(mode)}, {{}}).fields;")


def test_studio_audio_status_is_parsed_honestly():
    ok = json.dumps({"ok": True, "data": {"runtime": "readable", "clock.quantum": "128", "clock.rate": "48000",
                                            "xruns": "3", "dsp_load_max_b_q": "0.04", "dropin": "applied"}})
    out = run_js(f"return parseStudioAudioStatus({json.dumps(ok)});")
    assert out["available"] is True
    assert out["summary"] == "quantum 128 at 48000 Hz, 3 xruns, DSP load 4%, drop-in applied"
    down = json.dumps({"ok": True, "data": {"runtime": "unavailable", "xruns": "unavailable",
                                              "dsp_load_max_b_q": "unavailable", "dropin": "absent"}})
    out = run_js(f"return parseStudioAudioStatus({json.dumps(down)});")
    assert out["summary"] == "PipeWire runtime unavailable, xruns unavailable, DSP load unavailable, drop-in absent"
    for bad in ("", "not json", json.dumps({"ok": False, "message": "unknown studio subcommand: audio\nExample"})):
        out = run_js(f"return parseStudioAudioStatus({json.dumps(bad)});")
        assert out["available"] is False and out["summary"].startswith("unavailable")


def test_launcher_exposes_every_mode_and_revert():
    defaults = json.loads((ROOT / "config" / "shell.default.json").read_text())
    commands = [a["command"] for a in defaults["launcher"]["actions"]]
    for mode in MODES + ["revert"]:
        assert ["mode", mode] in commands
    launcher = (ROOT / "config" / "LauncherConfig.qml").read_text()
    for mode in MODES + ["revert"]:
        assert f'command: ["mode", "{mode}"]' in launcher
    actions = (ROOT / "modules" / "launcher" / "services" / "Actions.qml").read_text()
    assert 'command[0] === "mode"' in actions
    assert "Experience.set(command[1], \"user\")" in actions
    assert "Experience.revert()" in actions


def test_bars_follow_the_mode_density():
    bar = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
    assert "density: root.spec.density" not in bar
    assert bar.count("density: Experience.barDensity(root.spec.density)") == 3


# --- Runtime policy under a fullscreen window (behaviour, executed) --------

def policy(mode: str, fullscreen: bool, overrides: dict | None = None):
    return run_js(
        f"const p = resolve({json.dumps(mode)}, {json.dumps(overrides or {})});"
        f"return policy(p.fields, {{mode: {json.dumps(mode)}, fullscreen: {json.dumps(fullscreen)}}});"
    )


@pytest.mark.parametrize("value,expected", [
    (0, False), (1, False), (2, True), (3, True), (None, False), ("2", False),
])
def test_fullscreen_state_is_a_bit_test(value, expected):
    assert run_js(f"return isFullscreenState({json.dumps(value)});") is expected


def test_gaming_policy_while_a_window_is_fullscreen():
    p = policy("gaming", True)
    assert p == {
        "holdPopups": True,
        "telemetryPaused": True,
        "desktopWidgetsVisible": False,
        "idleInhibit": True,
    }


def test_gaming_policy_holds_notifications_and_pauses_nothing_else_off_fullscreen():
    p = policy("gaming", False)
    # Queued even when nothing is fullscreen: that is the mode's point.
    assert p["holdPopups"] is True
    # Polling continues and idle is not inhibited without a covering window.
    assert p["telemetryPaused"] is False
    assert p["idleInhibit"] is False
    # Gaming has no desktop layer at all (desktopWidgets: none).
    assert p["desktopWidgetsVisible"] is False


def test_everyday_is_untouched_by_fullscreen():
    p = policy("everyday", True)
    assert p == {
        "holdPopups": False,
        "telemetryPaused": False,
        "desktopWidgetsVisible": True,
        "idleInhibit": False,
    }


def test_studio_suppresses_popups_only_under_fullscreen():
    assert policy("studio", False)["holdPopups"] is False
    assert policy("studio", True)["holdPopups"] is True


def test_gaming_guardrails_cannot_be_overridden_into_motion_or_glow():
    over = {"gaming": {"motion": "full", "glow": True, "scanlines": True}}
    p = run_js(f"return resolve('gaming', {json.dumps(over)}).fields;")
    assert p["motion"] == "off"
    assert p["glow"] is False
    assert p["scanlines"] is False


def test_user_can_opt_gaming_out_of_the_hold_and_the_policy_follows():
    over = {"gaming": {"notifications.hold": False, "notifications.suppressFullscreen": False}}
    assert policy("gaming", True, over)["holdPopups"] is False


@pytest.mark.parametrize("hold,critical,dnd,held,popup", [
    (True, False, False, True, False),   # queued: filed, no popup
    (True, True, False, False, True),    # critical always reaches the person
    (True, False, True, False, False),   # Do Not Disturb: silent
    (True, True, True, False, True),     # critical beats DND by design
    (False, False, False, False, True),  # no policy: normal popup
    (False, False, True, False, False),
])
def test_notification_disposition(hold, critical, dnd, held, popup):
    out = run_js(
        f"return notificationDisposition({json.dumps(hold)}, {json.dumps(critical)}, {json.dumps(dnd)});"
    )
    assert out == {"held": held, "popup": popup}


def test_compositor_uses_the_bit_test_for_fullscreen_windows():
    comp = (ROOT / "services" / "Compositor.qml").read_text()
    assert "lastIpcObject.fullscreen === 2" not in comp
    assert comp.count("ExperienceModel.isFullscreenState(window.lastIpcObject.fullscreen)") == 2


def test_hyprland_tuning_reaches_lua_only_hyprland_and_mirrors_the_legacy_keywords():
    """Hyprland 0.55+ answers `keyword` with "unknown request"; the tuning must
    also go through `eval hl.config(...)` and carry exactly the same values."""
    game = (ROOT / "services" / "GameMode.qml").read_text()
    lua = re.search(r'luaTuning: "(hl\.config\(.*\))"', game).group(1)
    legacy = dict(re.findall(r'"([a-z_:]+)": (\d)', game))
    assert 'Hypr.extras.message("eval " + luaTuning);' in game
    assert "Hypr.extras.applyOptions({" in game  # pre-Lua Hyprland still works
    expected = {
        "animations:enabled": ("animations", "enabled", "false"),
        "decoration:shadow:enabled": ("shadow", "enabled", "false"),
        "decoration:blur:enabled": ("blur", "enabled", "false"),
        "general:gaps_in": ("general", "gaps_in", "0"),
        "general:gaps_out": ("general", "gaps_out", "0"),
        "general:border_size": ("general", "border_size", "1"),
        "decoration:rounding": ("decoration", "rounding", "0"),
        "general:allow_tearing": ("general", "allow_tearing", "true"),
    }
    assert set(legacy) == set(expected)
    for _key, (_group, name, value) in expected.items():
        assert f"{name} = {value}" in lua, name
    # Leaving gaming reloads the user's own config, which restores everything.
    assert 'Hypr.extras.message("reload");' in game

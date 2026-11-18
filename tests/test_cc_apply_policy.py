"""Control Center apply policy (docs/CONTROL-CENTER-APPLY.md).

One rule for every pane: a setting takes effect the moment it is chosen.
There is no Apply/Save/Confirm button for settings; risky or slow changes
offer "Applied · Undo" through the shared services/Undo.qml. Static checks
pin the absence of Apply-style controls and the wiring of the shared strip;
the offscreen scenes run the REAL Undo service and the Chromatic auto-apply
path against the test doubles in tests/fixtures/chromatic.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402

CC = ROOT / "modules" / "controlcenter"
UNDO = (ROOT / "services" / "Undo.qml").read_text()
STRIP = (CC / "components" / "UndoStrip.qml").read_text()
DOC = (ROOT / "docs" / "CONTROL-CENTER-APPLY.md").read_text()
PRESET = (ROOT / "services" / "PresetApply.qml").read_text()

LABEL = re.compile(r'\btext:\s*(?:\w+\s*\?\s*)?qsTr\("([^"]*)"')


def _qml_files():
    return sorted(CC.rglob("*.qml"))


def _labels():
    for path in _qml_files():
        text = path.read_text()
        for m in LABEL.finditer(text):
            yield path.relative_to(CC).as_posix(), m.group(1)


# ---- no Apply-style controls -------------------------------------------

# Labels that used to stage a value behind a button. None may come back.
RETIRED_LABELS = {
    "Apply", "Apply layouts", "Apply model", "Apply %1 now", "Save prompt",
    "Set schedule", "Clear schedule", "Preview on desktop", "Stop previewing",
    "Keep current", "Yes, reset all", "Confirm reset all", "Reset all to defaults…",
    "Really delete?",
}
RETIRED_SOURCE_TOKENS = (
    "confirmAll", "confirmResetAll", "confirmingDelete", "armedProfile",
    "armedRestore", "followAsking", "applyAsked", "keepCurrent",
)


def test_no_apply_style_button_remains():
    offenders = [(f, label) for f, label in _labels() if label in RETIRED_LABELS]
    assert not offenders, offenders
    for label_file, label in _labels():
        assert not re.match(r"^Apply\b", label) or label.startswith("Applying"), (label_file, label)


def test_staging_state_is_gone():
    for path in _qml_files():
        text = path.read_text()
        for token in RETIRED_SOURCE_TOKENS:
            assert token not in text, (path.name, token)


def test_chromatic_has_no_apply_preview_cancel_buttons():
    section = (CC / "appearance" / "sections" / "ChromaticSection.qml").read_text()
    for gone in ("ChromaticPreview.apply(", "ChromaticPreview.cancel()", "ChromaticPreview.previewLive(!"):
        assert gone not in section, gone
    # Hover/focus remains a transient preview; Escape ends it.
    assert "ChromaticPreview.endHover" in section
    assert "ChromaticPreview.enable()" in section and "ChromaticPreview.turnOff()" in section


# Save/Create verbs that remain are forms that NAME a new object (a palette,
# a preset, a VPN provider) or author a document; they are not settings.
CREATE_FORMS = {
    "appearance/sections/ChromaticSection.qml",     # Save palette
    "appearance/sections/ThemeEditorSection.qml",   # Save as new / Save changes (authoring)
    "experience/DeckManager.qml",                   # Save preset
    "network/VpnDetails.qml",                       # VPN provider dialog
    "network/VpnList.qml",                          # VPN provider dialog
    "layout/LayoutTweaksRow.qml",                   # Save my tweaks (a per-layout record)
}


def test_save_verbs_are_only_create_forms():
    for f, label in _labels():
        if re.match(r"^Save\b", label):
            assert f in CREATE_FORMS, (f, label)


# Commands that cannot be undone from the shell keep a deliberate two-step
# guard. Settings never do.
GUARDED = {
    "power/PowerPane.qml", "updates/UpdatesPane.qml", "components/CtlCard.qml",
    "studio/StudioPane.qml", "keybinds/KeybindsPane.qml", "experience/ExperiencePane.qml", "bluetooth/PairingDialog.qml",
    "extensions/ExtensionsPane.qml",
}


def test_two_step_guards_are_only_on_commands_without_an_inverse():
    for path in _qml_files():
        rel = path.relative_to(CC).as_posix()
        text = path.read_text()
        guarded = bool(re.search(r'Click again|qsTr\("Confirm |\barmed(Action|RunId)?\b', text))
        if guarded:
            assert rel in GUARDED, rel


# ---- the shared Undo service --------------------------------------------

def test_undo_service_contract():
    assert "pragma Singleton" in UNDO
    for fn in ("function offer(", "function report(", "function undo(", "function dismiss(", "function restorer("):
        assert fn in UNDO, fn
    # Coalescing keeps the first restore point; pause on hover/focus.
    assert "Same change continuing: keep the first restore point." in UNDO
    assert "if (root.paused)" in UNDO and "readonly property bool paused: holds > 0" in UNDO
    # Duration is a user setting, never hard-coded.
    assert "Config.controlCenter.undoSeconds" in UNDO


def test_undo_strip_is_accessible_and_motion_aware():
    assert "Accessible.name" in STRIP and "Accessible.AlertMessage" in STRIP
    assert 'sequence: "Ctrl+Z"' in STRIP
    assert 'typeof focused.selectAll === "function"' in STRIP  # text fields keep Ctrl+Z
    assert "Appearance.anim.reduced" in STRIP
    assert "Undo.hold()" in STRIP and "Undo.release()" in STRIP
    # Both buttons are real controls with keyboard focus (TextButton -> Interactive).
    assert STRIP.count("TextButton {") == 2
    assert "qsTr(" in STRIP and "Microcopy.line(" in STRIP


def test_strip_is_mounted_once_in_the_control_center():
    cc = (CC / "ControlCenter.qml").read_text()
    assert cc.count("UndoStrip {") == 1


def test_undo_duration_is_a_documented_validated_setting():
    cfg = (ROOT / "config" / "ControlCenterConfig.qml").read_text()
    assert "property real undoSeconds: 10" in cfg
    import json
    ranges = json.loads((ROOT / "config" / "ranges.json").read_text())["ranges"]
    assert ranges["controlCenter.undoSeconds"] == {"min": 3, "max": 60, "step": 1, "default": 10}
    factory = json.loads((ROOT / "config" / "shell.default.json").read_text())
    assert factory["controlCenter"]["undoSeconds"] == 10
    assert "Config.controlCenter.undoSeconds" in (ROOT / "config" / "Config.qml").read_text() or "controlCenter.undoSeconds" in (ROOT / "config" / "Config.qml").read_text()


def test_risky_changes_offer_undo():
    expect = {
        "appearance/AppearancePane.qml": 'Undo.offerCalls("appearance"',
        "appearance/sections/LookSection.qml": 'Undo.offerValues("look"',
        "appearance/sections/AtmosphereSection.qml": 'Undo.offerValues("atmosphere-reset"',
        "customisation/CustomisationPane.qml": 'Undo.offerPaths("customisation-reset"',
        "input/InputPane.qml": 'Undo.offerCommand("input-layout"',
        "keybinds/KeybindsPane.qml": 'Undo.offerCommand("keybind"',
        "displays/DisplaysPane.qml": 'Undo.offerCommand("displays"',
        "gaming/GamingPane.qml": 'Undo.offerCommand("power-profile"',
        "nightlight/NightLightPane.qml": 'Undo.offerCommand("night-light"',
        "companion/CompanionPane.qml": 'Undo.offerCommand(u.key',
        "experience/ExperiencePane.qml": 'Undo.offerCalls("experience-mode"',
        "taskbar/BarGeometryEditor.qml": 'Undo.offerValues("bar-reset"',
    }
    for rel, needle in expect.items():
        assert needle in (CC / rel).read_text(), (rel, needle)
    grid = (ROOT / "modules" / "layoutpicker" / "PresetGrid.qml").read_text()
    assert "PresetApply.apply(" in grid and "offerUndo" in grid
    assert 'Undo.offer("layout"' in PRESET
    assert "offerUndo: true" in (CC / "layout" / "LayoutPane.qml").read_text()
    assert 'Undo.offer("chromatic"' in (ROOT / "services" / "ChromaticPreview.qml").read_text()


def test_failures_say_why_through_the_same_service():
    for rel in ("input/InputPane.qml", "displays/DisplaysPane.qml", "nightlight/NightLightPane.qml",
                "companion/CompanionPane.qml", "gaming/GamingPane.qml"):
        assert "Undo.report(" in (CC / rel).read_text(), rel
    assert "Undo.report(" in PRESET
    assert "Undo.report(" in (ROOT / "services" / "ChromaticPreview.qml").read_text()


def test_layout_apply_is_snapshotted_and_restored_atomically():
    # Copy aside first; restore by temp file + rename (atomic on one filesystem).
    assert 'cp -p "$2" "$d/shell.json"' in PRESET
    assert 'mv -f "$2.undo.tmp" "$2"' in PRESET
    assert "_queued" in PRESET, "a newer choice made while busy must win, not be dropped"


def test_wallpaper_follow_does_not_replace_the_wallpaper_undo():
    service = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    assert 'Undo.key === "appearance"' in service and 'Undo.kind === "undone"' in service


def test_layout_burst_keeps_the_first_snapshot():
    assert "continuing" in PRESET and "root._next(true)" in PRESET


def test_policy_doc_lists_every_pane():
    for path in sorted(p for p in CC.iterdir() if p.is_dir() and p.name not in ("components", "state", "windows")):
        assert path.name in DOC, f"docs/CONTROL-CENTER-APPLY.md must classify the {path.name} pane"
    assert "windows" in DOC and "components" in DOC


# ---- offscreen: the real services ----------------------------------------

@requires_qs
def test_undo_service_restores_values_and_says_why_it_failed(tmp_path):
    r, _, _ = run_scene(tmp_path, "undo")
    assert r["defaultSeconds"] == 10
    assert r["offered"] == ["applied", "a", True]
    assert r["coalescedTitle"] == "A2"
    assert r["callsAfterFirst"] == ["a1"], "the first restore point wins when changes coalesce"
    assert r["afterUndo"] == ["undone", False]
    assert r["callsAfterReplace"] == ["a1", "c"], "a different key replaces the offer"
    assert r["failFalse"] == ["failed", True, False]
    assert r["failString"] == ["failed", "disk full"]
    assert r["failThrow"] == ["failed", True]
    assert r["report"] == ["failed", "because", False]
    assert r["dismissed"] is False
    assert r["restorer"] == 10
    assert r["pausedStillActive"] is True, "the countdown waits while the strip is hovered or focused"
    assert r["expired"] is True


@requires_qs
def test_chromatic_choices_apply_once_without_a_button(tmp_path):
    r, before, after = run_scene(tmp_path, "service", HACTION="auto", HTRANSITION="instant")
    log = [ln for ln in (tmp_path / "ctl.log").read_text().splitlines() if ln.startswith("appearance chromatic apply")]
    assert len(log) == 1, "three quick changes are one apply of the newest request"
    assert "--contrast maximum" in log[0] and "--hue-shift 10" in log[0]
    assert r["applyError"] == ""
    assert r["undoKind"] == "applied" and r["undoKey"] == "chromatic" and r["canUndo"] is True


@requires_qs
def test_failed_chromatic_apply_reports_why_and_offers_no_undo(tmp_path):
    r, _, _ = run_scene(tmp_path, "service", HACTION="auto", FAKE_CTL_EXIT=1, HTRANSITION="instant")
    assert "gates failed" in r["applyError"]
    assert r["undoKind"] == "failed" and "gates failed" in r["undoReason"]
    assert r["canUndo"] is False


# ---- review fixes (B1-B5, S1-S5) -------------------------------------------

PANE_FILES = [p for p in CC.rglob("*.qml")]


def test_b2_no_pane_owns_a_restore_closure():
    """Panes unload on navigation and die with the window: their Undo must be
    data run by a singleton (offerCommand/offerValues/offerPaths/offerCalls)."""
    for path in PANE_FILES:
        text = path.read_text()
        assert "Undo.offer(" not in text, f"{path.relative_to(CC)} hands Undo a pane closure"
    for singleton in ("services/ChromaticPreview.qml", "services/PresetApply.qml", "modules/companion/CompanionStore.qml"):
        assert "pragma Singleton" in (ROOT / singleton).read_text(), singleton


def test_b1_holds_are_counted_and_freed_when_the_window_goes():
    assert "function releaseAll()" in UNDO and "root.holds = 0" in UNDO
    assert "Component.onDestruction: root.windowGone()" in STRIP
    assert "onVisibleChanged" in STRIP and "Undo.dismiss()" in STRIP and "Undo.releaseAll()" in STRIP
    assert "Undo.paused =" not in STRIP


def test_b3_undo_and_turn_off_cancel_pending_chromatic_applies():
    svc = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    cancel = svc[svc.index("function _cancelPending()"):svc.index("function _restoreSnapshot")]
    for needle in ("applyQuiet.stop()", "_applyWanted = false", "_applyAgain = false"):
        assert needle in cancel, needle
    restore = svc[svc.index("function _restoreSnapshot"):svc.index("// Persist through horneroctl.")]
    assert "_cancelPending()" in restore and "request = snap.request" in restore
    assert "return Undo.busy" in restore
    off = svc[svc.index("function turnOff()"):svc.index("// `undoWith`")]
    assert "_cancelPending()" in off and "_offQueued = true" in off


def test_b5_tweaks_reapply_only_after_a_successful_apply():
    apply_exit = PRESET[PRESET.index("id: applyProc"):PRESET.index("id: settle")]
    assert "Layouts.reapplyAfterPreset(root._target)" in apply_exit
    assert apply_exit.index("exitCode !== 0") < apply_exit.index("Layouts.reapplyAfterPreset")
    restore_exit = PRESET[PRESET.index("id: restoreProc"):]
    assert "reapplyAfterPreset" not in restore_exit


def test_s2_experience_preferred_layout_goes_through_the_undo_path():
    pane = (CC / "experience" / "ExperiencePane.qml").read_text()
    assert "PresetApply.apply(v, v, true)" in pane
    assert "Experience.applyPreferredLayout()" not in pane


def test_s3_busy_restores_wait_instead_of_failing():
    assert "return root.busy;" in UNDO and "id: retry" in UNDO
    svc = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    assert "? true : Undo.busy" in svc  # rollback via runCtl
    assert "return Undo.busy" in PRESET
    assert "restoreProc.running" in PRESET.split("readonly property bool applying:")[1].split("\n")[0]


def test_s5_display_restore_keeps_transform_and_mirror_names():
    pane = (CC / "displays" / "DisplaysPane.qml").read_text()
    assert ",transform," in pane and "o.name === String(m.mirrorOf)" in pane
    assert "arrangeStarted" in pane


# ---- the preset snapshot / restore scripts, run for real -----------------

import shutil
import subprocess


def _script(name):
    """The sh program PresetApply.qml builds for `<name>.command`."""
    start = PRESET.index(f"{name}.command = [\"sh\", \"-c\", ")
    seg = PRESET[start:PRESET.index(",\n            \"sh\",", start)]
    return "".join(re.findall(r"'((?:[^'\\]|\\.)*)'", seg))


def _run(script, *args):
    return subprocess.run(["sh", "-c", script, "sh", *args], capture_output=True, text=True)


def _sha(path):
    import hashlib
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else "absent"


def test_b4_fresh_account_without_shell_json_can_apply_and_undo(tmp_path):
    snap, restore = _script("snapProc"), _script("restoreProc")
    cfg, ptr, root = tmp_path / "shell.json", tmp_path / "current-shell-preset", tmp_path / "undo"
    d = root / "1"
    r = _run(snap, str(d), str(cfg), str(ptr), "-")
    assert r.returncode == 0, r.stderr
    assert (d / "shell.json.absent").exists() and (d / "current-shell-preset.absent").exists()
    # horneroctl then creates both files; Undo removes them again.
    cfg.write_text("{\"bar\": 1}\n")
    ptr.write_text("cockpit\n")
    r = _run(restore, str(d), str(cfg), str(ptr), _sha(cfg))
    assert r.returncode == 0, r.stderr
    assert not cfg.exists() and not ptr.exists()


def test_s1_layout_undo_refuses_when_shell_json_changed_since(tmp_path):
    snap, restore = _script("snapProc"), _script("restoreProc")
    cfg, ptr, d = tmp_path / "shell.json", tmp_path / "ptr", tmp_path / "undo" / "1"
    cfg.write_text("before\n")
    ptr.write_text("hornero-left\n")
    assert _run(snap, str(d), str(cfg), str(ptr), "-").returncode == 0
    cfg.write_text("after preset\n")
    expect = _sha(cfg)
    cfg.write_text("after preset + another setting\n")
    r = _run(restore, str(d), str(cfg), str(ptr), expect)
    assert r.returncode == 3, "a later change must make Undo refuse, not roll it back"
    assert cfg.read_text() == "after preset + another setting\n"
    cfg.write_text("after preset\n")
    r = _run(restore, str(d), str(cfg), str(ptr), expect)
    assert r.returncode == 0 and cfg.read_text() == "before\n" and ptr.read_text() == "hornero-left\n"
    assert not list(tmp_path.glob("*.undo.tmp"))


def test_s4_pruning_never_removes_the_snapshot_the_offer_points_to(tmp_path):
    snap = _script("snapProc")
    cfg, ptr, root = tmp_path / "shell.json", tmp_path / "ptr", tmp_path / "undo"
    cfg.write_text("x\n")
    import time
    _run(snap, str(root / "100"), str(cfg), str(ptr), "-")
    for n in range(101, 107):
        time.sleep(0.02)
        assert _run(snap, str(root / str(n)), str(cfg), str(ptr), str(root / "100")).returncode == 0
    left = sorted(p.name for p in root.iterdir())
    assert "100" in left, "the live offer's copy was pruned"
    assert "106" in left and len(left) <= 4


def test_s4_snapshot_failure_starts_the_next_choice_fresh():
    snap_exit = PRESET[PRESET.index("id: snapProc"):PRESET.index("id: applyProc")]
    assert "root._next(false)" in snap_exit and 'root._snapDir = ""' in snap_exit
    assert "root._snapDir !== \"\"" in PRESET  # continuing only with a real copy


@requires_qs
def test_undo_service_holds_busy_retry_and_commands(tmp_path):
    r, _, _ = run_scene(tmp_path, "undo")
    assert r["paths"] == ["undone", 10]
    assert r["callsOk"] == "undone"
    assert r["callsError"] == "failed", "a singleton call that answers error: fails the undo"
    assert r["withdrawOther"] is True and r["withdrawSame"] is False
    assert r["holdsAfterReleaseAll"] == 0
    assert r["whileBusy"] == "undoing"
    assert r["afterBusy"] == ["undone", -1], "a busy restore is retried, not failed"
    assert r["cmdFail"][0] == "failed" and "nope" in r["cmdFail"][1]
    assert r["cmdOk"][0] == "undone" and "k:true" in r["cmdOk"][1]

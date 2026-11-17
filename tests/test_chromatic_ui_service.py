"""ChromaticPreview service: preview through the helper, apply only through
horneroctl, honest failures (RFC 0002 §13, contract §7.2)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402

SERVICE = (ROOT / "services" / "ChromaticPreview.qml").read_text()
SECTION = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ChromaticSection.qml").read_text()


def test_service_never_writes_the_scheme_or_shell_json():
    for forbidden in ("persistScheme", "persistBuiltInTheme", "writeSchemeProc", "scheme.json", "sh\", \"-c"):
        assert forbidden not in SERVICE, forbidden
    # The one shell-side write: Undo putting the saved preferences back when
    # Chromatic had been off. Never the scheme, never anywhere else.
    assert SERVICE.count("Config.save") == 1
    restore = SERVICE[SERVICE.index("function _restoreSnapshot"):SERVICE.index("// Persist through horneroctl.")]
    assert "Config.save()" in restore
    # Every Process command is the helper or horneroctl.
    assert "Cli.applyArgs" in SERVICE and "root.helperPath" in SERVICE


def test_section_only_talks_to_the_service():
    for forbidden in ("Process {", "persistScheme", '"horneroctl"', "Quickshell.execDetached"):
        assert forbidden not in SECTION, forbidden
    # No Apply button (docs/CONTROL-CENTER-APPLY.md): choices call the
    # service, which applies the newest candidate itself.
    assert "ChromaticPreview.apply(" not in SECTION
    assert "ChromaticPreview.set(" in SECTION and "ChromaticPreview.setSource(" in SECTION
    assert "Keys.onEscapePressed" in SECTION and "ChromaticPreview.endHover" in SECTION


def _chromatic_calls(tmp_path):
    log = tmp_path / "ctl.log"
    lines = log.read_text().splitlines() if log.exists() else []
    return [ln for ln in lines if ln.startswith("appearance chromatic")]


@requires_qs
def test_helper_missing_is_reported_honestly(tmp_path):
    r, before, after = run_scene(tmp_path, "service", HORNERO_CHROMATIC_BIN=str(tmp_path / "nope"))
    assert r["helper"] is False and r["errorCode"] == "engine-missing"
    assert before == after


@requires_qs
def test_generate_fills_the_candidate_without_touching_the_live_theme(tmp_path):
    r, before, after = run_scene(tmp_path, "service", HTRANSITION="instant")
    assert r["helper"] is True and r["hasResult"] is True and r["errorCode"] == ""
    assert r["fingerprint"].startswith("sha256:") and r["rows"] > 0 and r["mode"] == "dark"
    assert before == after


@requires_qs
def test_unreadable_source_is_an_honest_state(tmp_path):
    r, _, _ = run_scene(tmp_path, "service", FAKE_EXIT=3)
    assert r["hasResult"] is False and r["errorCode"] == "source-unreadable"


@requires_qs
def test_preview_on_desktop_then_cancel_writes_nothing(tmp_path):
    r, before, after = run_scene(tmp_path, "service", HACTION="preview", HTRANSITION="instant")
    assert r["live"] is True and r["themeDuring"] == "hornero-chromatic"
    assert r["liveAfterCancel"] is False and r["themeAfter"] == r["themeBefore"]
    assert before == after
    assert not _chromatic_calls(tmp_path), "preview must not run horneroctl chromatic"


@requires_qs
def test_apply_goes_through_horneroctl_and_commits(tmp_path):
    r, _, _ = run_scene(tmp_path, "service", HACTION="apply", HTRANSITION="instant")
    log = _chromatic_calls(tmp_path)
    assert len(log) == 1
    argv = log[0].split()
    assert argv[:3] == ["appearance", "chromatic", "apply"]
    assert argv[-2:] == ["--json", "--yes"]
    assert "--source" in argv and "house" in argv
    assert r["applyError"] == "" and r["liveAfterApply"] is False
    assert r["themeAfterApply"] == "hornero-chromatic", "commit keeps the candidate until the file arrives"


@requires_qs
def test_failed_apply_restores_the_previous_palette(tmp_path):
    r, _, _ = run_scene(tmp_path, "service", HACTION="apply", FAKE_CTL_EXIT=1, HTRANSITION="instant")
    assert "gates failed" in r["applyError"]
    assert r["liveAfterApply"] is False
    assert r["themeAfterApply"] == r["themeBefore"]


def test_in_process_engine_is_optional_and_never_writes():
    bridge = (ROOT / "services" / "ChromaticInProcess.qml").read_text()
    assert "import Hornero.Chromatic" in bridge and "ChromaticEngine.generate" in bridge
    for forbidden in ("Process", "persistScheme", "FileView", "Config.save"):
        assert forbidden not in bridge, forbidden
    # The service loads it at runtime so a missing module only means fallback.
    assert "Qt.createComponent(Qt.resolvedUrl(\"ChromaticInProcess.qml\"))" in SERVICE
    assert "import Hornero.Chromatic" not in SERVICE

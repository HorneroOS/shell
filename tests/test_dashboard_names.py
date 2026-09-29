"""Dashboard component-name contract: no QML component file may shadow a
Qt built-in attached-only type (QtQuick.Keys is the classic case: a
sibling Keys.qml is silently ignored and `Keys {}` fails at load with
"only available via attached properties", which qmllint does not catch
and which takes the whole shell down). Every bare component reference
in the dashboard Content must resolve to a same-directory file whose
name is not on the shadow denylist."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "modules" / "dashboard"
CONTENT = DASH / "Content.qml"

# Qt built-in attached-only (non-instantiable) type names that must never
# be reused as component file names anywhere under modules/.
SHADOW_DENYLIST = {
    "Keys",  # QtQuick.Keys attached type; broke the shell in #51.
    "LayoutMirroring",  # QtQuick.LayoutMirroring attached type.
}


def _qml_component_names():
    return [p.stem for p in ROOT.glob("modules/**/*.qml")]


def test_no_component_shadows_builtin_attached_type():
    hits = sorted(set(_qml_component_names()) & SHADOW_DENYLIST)
    assert not hits, f"component names shadow Qt attached types: {hits}"


def test_dashboard_content_references_resolve_to_files():
    text = CONTENT.read_text()
    refs = re.findall(r"sourceComponent:\s*(\w+)\s*\{", text)
    assert refs, "expected sourceComponent references in dashboard Content"
    siblings = {p.stem for p in DASH.glob("*.qml")}
    missing = sorted(set(refs) - siblings)
    assert not missing, f"dashboard references without a same-dir file: {missing}"


def test_dash_media_empty_state_says_no_media_once():
    # Empty players must read as one deliberate placeholder, not three
    # repeated "No media" lines (website showroom caught the triple).
    # Mirrors the Media tab pattern: title keeps the single fallback,
    # album hides when inactive, artist shows the friendly hint.
    text = (DASH / "dash" / "Media.qml").read_text()
    assert text.count("No media") == 1, \
        "dash media must fall back to 'No media' exactly once"
    assert "visible: !!Players.active" in text, \
        "dash media album line must hide when no player is active"
    assert "Play some music for stuff to show up here!" in text, \
        "dash media artist line must show the friendly empty hint"

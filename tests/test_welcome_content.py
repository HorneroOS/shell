"""Welcome Center 3-mode, 9-scene content, allowlisted actions, and shortcut badges."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WELCOME = ROOT / "modules" / "welcome"
SCENES = WELCOME / "scenes"
VIEWS = WELCOME / "views"

SCENE_FILES = sorted(SCENES.glob("*Scene.qml"))
VIEW_FILES = sorted(VIEWS.glob("*View.qml"))
CONTENT_FILES = SCENE_FILES + VIEW_FILES

EXPECTED_SCENES = [
    "ArrivalScene",
    "CompanionScene",
    "ExtensionsScene",
    "PersonalizeScene",
    "PracticeScene",
    "ReadyScene",
    "ShowcaseScene",
    "TrustScene",
    "WorkstationScene",
]

EXPECTED_VIEWS = [
    "ExploreView",
    "ShortcutsView",
    "WhatsNewView",
]

BANNED_PAGE_TOKENS = (
    "execDetached",
    "Process {",
    "horneroctl",
    "openUrlExternally",
    "XMLHttpRequest",
)

ALLOWED_CALLABLE_ROOTS = {
    "Accessible.", "Actions.", "ShortcutHints.", "Welcome.", "WelcomeModule.",
    "PreviewTransaction.", "State.", "TrustDiagnostics.", "Appearance.", "Signal.", "Choreography.", "Component.",
    "Compositor.", "Experience.", "Companion.", "CompanionStore.",
    "AssistantRun.", "Config.", "Language.", "Keybinds.", "Visibilities.", "Wallpapers.", "WindowFactory.",
    "Qt.", "WelcomeModel.", "WhatsNew.", "Text.", "Image.", "Flickable.",
    "Gradient.", "TextButton.", "IconButton.", "StyledScrollBar.", "Layout.",
    "Math.", "JSON.", "Object.", "Array.", "String.", "Number.", "Date.",
}


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"(^|\s)//.*$", r"\1", text, flags=re.MULTILINE)


def _curated_ids() -> list[str]:
    text = _read(WELCOME / "ShortcutHints.qml")
    m = re.search(r"readonly property var curatedIds:\s*\[(.*?)\]", text, re.DOTALL)
    assert m, "ShortcutHints.qml must define curatedIds"
    return re.findall(r'"([^"]+)"', m.group(1))


def test_scenes_and_views_use_allowlisted_callables_only():
    for doc in CONTENT_FILES:
        code = _strip_comments(_read(doc))
        code = re.sub(r"^\s*import\s+.*$", "", code, flags=re.MULTILINE)
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code)
        for token in BANNED_PAGE_TOKENS:
            assert token not in code, f"{doc.name}: banned token {token!r}"
        for callee in set(re.findall(r"\b([A-Z][A-Za-z0-9]*)\.[a-zA-Z]", code)):
            root = f"{callee}."
            assert root in ALLOWED_CALLABLE_ROOTS, (
                f"{doc.name}: callable root {callee}.* is not allowlisted"
            )


def test_shortcut_ids_single_sourced():
    curated = _curated_ids()
    assert len(curated) == len(set(curated)), "curatedIds must not repeat"
    for cid in curated:
        assert re.fullmatch(r"[a-z0-9][a-z0-9:._-]*", cid), f"bad id shape: {cid!r}"
    for doc in CONTENT_FILES:
        used = re.findall(r'(?:shortcutId:\s*|ShortcutHints\.badge\()"([^"]+)"', _read(doc))
        for cid in used:
            assert cid in curated, f"{doc.name}: {cid!r} not in ShortcutHints.curatedIds"


def test_actions_allowlist_shape():
    text = _strip_comments(_read(WELCOME / "Actions.qml"))
    funcs = re.findall(r"function\s+([a-zA-Z]+)\s*\(", text)
    for required in ("openLauncher", "openDashboard", "openSessionMenu",
                     "openUtilities", "openLayoutPicker", "openControlCenter",
                     "shellQuote", "openTerminal", "openWelcome", "openApps",
                     "ensureAppProfiles", "refreshAppProfiles", "queueAppIds",
                     "executeTypedAction"):
        assert required in funcs, f"Actions.qml missing {required}"
    for token in ("horneroctl", "Process {", "openUrlExternally", "XMLHttpRequest"):
        assert token not in text, f"Actions.qml: banned token {token!r}"
    assert text.count("execDetached") == 1, "only openTerminal may spawn (app2unit shape)"
    assert "app2unit" in text and "Config.general.apps.terminal" in text
    assert "PaneRegistry." in text
    assert "Visibilities.getForActive" in text
    assert "WelcomeModule.Welcome.open" in text


def test_badge_gating_shape():
    card = _read(WELCOME / "ActionCard.qml")
    assert "ShortcutHints.has(root.shortcutId)" in card
    assert "ShortcutHints.badge(root.shortcutId)" in card
    assert 'shortcutId !== ""' in card
    hints = _read(WELCOME / "ShortcutHints.qml")
    assert "schemaVersion === 1" in hints
    assert 'return label !== undefined ? label : ""' in hints


def test_scenes_and_views_are_translatable():
    for doc in CONTENT_FILES:
        text = _read(doc)
        assert len(re.findall(r"qsTr\(", text)) >= 1, f"{doc.name}: needs qsTr copy"


def test_scene_and_view_inventory_complete():
    assert sorted(p.stem for p in SCENE_FILES) == sorted(EXPECTED_SCENES)
    assert sorted(p.stem for p in VIEW_FILES) == sorted(EXPECTED_VIEWS)
    window = _read(WELCOME / "Window.qml")
    for scene in EXPECTED_SCENES:
        assert f"scenes/{scene}.qml" in window
    for view in ("ExploreView.qml", "WhatsNewView.qml"):
        assert f"views/{view}" in window

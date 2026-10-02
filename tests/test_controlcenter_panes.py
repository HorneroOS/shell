"""Control-center pane contract: PaneRegistry entries must resolve to real
pane files, every registered pane must accept the shared Session, and no
pane may invoke a retired dots-* wrapper (all of them are retired now —
appearance included — every call goes through horneroctl)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"
REGISTRY = CC / "PaneRegistry.qml"
WINDOW_FACTORY = CC / "WindowFactory.qml"

# Every dots-* wrapper the shell ever invoked, all superseded by horneroctl
# verbs (see docs/MIGRATION.md). None may appear in pane QML.
DEAD_WRAPPERS = [
    "dots-quickshell",
    "dots-launcher",
    "dots-power-menu",
    "dots-clipboard",
    "dots-snappy-switcher",
    "dots-hypr-layout",
    "dots-hyprland-plugins",
    "dots-battery-monitor",
    "dots-keyboard-help",
    "dots-keyboard-layout",
    "dots-lockscreen",
    "dots-screenshooter",
    "dots-sysupdate",
    "dots-theme-selector",
    "dots-gtk-theme",
    "dots-m3-colors",
    "dots-color-scheme",
    "dots-appearance",
    "dots-accent-override",
    "dots-night-mode",
    "dots-wallpaper-current",
    "dots-wallpaper-set",
    "dots-recorder",
    "dots-settings-gui",
    "dots-hyprlock-theme",
]


def _registry_entries():
    text = REGISTRY.read_text()
    entries = []
    for block in re.findall(r"QtObject\s*\{([^{}]*)\}", text, re.DOTALL):
        if 'readonly property string component:' not in block:
            continue
        values = {}
        for key in ("id", "label", "icon", "component", "title", "category", "description"):
            match = re.search(rf'readonly property string {key}:\s*(?:qsTr\()?"([^"]+)"\)?', block)
            if match:
                values[key] = match.group(1)
        values["keywords"] = re.search(r"readonly property list<string> keywords:\s*\[([^]]*)\]", block, re.DOTALL)
        entries.append(values)
    return entries


def test_registry_components_exist():
    entries = _registry_entries()
    assert entries, "no panes parsed from PaneRegistry.qml"
    for entry in entries:
        assert (CC / entry["component"]).is_file(), f"pane {entry['id']}: missing {entry['component']}"


def test_registry_ids_unique_and_labels_sane():
    entries = _registry_entries()
    ids = [e["id"] for e in entries]
    assert len(ids) == len(set(ids)), f"duplicate pane ids: {ids}"
    for entry in entries:
        label = entry["label"]
        assert re.fullmatch(r"[a-z]+", label), f"bad pane label: {label}"


def test_registry_discovery_metadata_is_complete_and_categories_resolve():
    text = REGISTRY.read_text()
    categories = set(re.findall(r'property string id:\s*"([^"]+)";\s*readonly property string title:', text))
    for entry in _registry_entries():
        assert entry.get("title"), f"pane {entry['id']}: missing title"
        assert entry.get("description"), f"pane {entry['id']}: missing description"
        assert entry.get("keywords") and entry["keywords"].group(1).strip(), f"pane {entry['id']}: missing search keywords"
        assert entry.get("category") in categories, f"pane {entry['id']}: unknown category {entry.get('category')}"


def test_registry_categories_are_unique_nonempty_and_grouped():
    text = REGISTRY.read_text()
    category_block = text.split("readonly property list<QtObject> categories:", 1)[1].split(
        "readonly property list<QtObject> panes:", 1
    )[0]
    categories = re.findall(
        r'property string id:\s*"([^"]+)";\s*readonly property string title:',
        category_block,
    )
    entries = _registry_entries()
    pane_categories = [entry["category"] for entry in entries]

    assert len(categories) == len(set(categories)), f"duplicate categories: {categories}"
    assert set(categories) == set(pane_categories), "every category must have panes and every pane must have a category"
    assert all(pane_categories.count(category) > 0 for category in categories)

    seen = set()
    previous = None
    for category in pane_categories:
        if category != previous:
            assert category not in seen, f"category {category} is split across navigation groups"
            seen.add(category)
            previous = category


def test_search_targets_resolve_to_registered_panes_and_appearance_sections():
    text = REGISTRY.read_text()
    target_block = text.split("readonly property list<QtObject> searchTargets:", 1)[1].split("]", 1)[0]
    targets = re.findall(r"QtObject\s*\{([^{}]*)\}", target_block, re.DOTALL)
    ids = set()
    panes = {entry["id"] for entry in _registry_entries()}
    appearance = (CC / "appearance" / "AppearancePane.qml").read_text()
    for block in targets:
        values = {}
        for key in ("id", "title", "pane", "section", "keywords"):
            match = re.search(rf'readonly property string {key}:\s*(?:qsTr\()?"([^"]*)"', block)
            assert match, f"search target missing {key}: {block}"
            values[key] = match.group(1)
        assert values["id"] not in ids, f"duplicate search target id: {values['id']}"
        ids.add(values["id"])
        assert values["title"], f"search target {values['id']}: missing title"
        assert values["keywords"], f"search target {values['id']}: missing keywords"
        assert values["pane"] in panes, f"search target {values['id']}: unknown pane"
        if values["pane"] == "appearance":
            assert re.search(rf'"{re.escape(values["section"])}"', appearance), (
                f"search target {values['id']}: unknown Appearance section"
            )


def test_settings_search_has_keyboard_entry_and_layered_escape():
    search = (CC / "SettingsSearch.qml").read_text()
    factory = WINDOW_FACTORY.read_text()
    assert 'sequences: ["Ctrl+,"]' in factory
    assert "Qt.Key_Down" in search and "Qt.Key_Up" in search
    assert "Qt.Key_Return" in search and "Qt.Key_Escape" in search
    assert "searchQuery.length > 0" in factory


def test_appearance_section_routes_use_the_sidebar_component_scope():
    appearance = (CC / "appearance" / "AppearancePane.qml").read_text()
    keys = re.search(r"readonly property var _sectionKeys:\s*\[([^]]*)\]", appearance)
    assert keys, "Appearance section ids must remain explicit"
    section_ids = re.findall(r'"([A-Za-z]+)"', keys.group(1))
    sidebar_map = re.search(r"readonly property var sections:\s*\(\{(.*?)\}\)", appearance, re.DOTALL)
    assert sidebar_map, "sidebar component must expose its scoped section items"
    for section_id in section_ids:
        assert re.search(rf"\b{re.escape(section_id)}:\s*{re.escape(section_id)}Section\b", sidebar_map.group(1)), (
            f"sidebar section map is missing {section_id}"
        )
    assert "root.sectionItems[key]" in appearance
    assert "root.sectionScroll = sidebarFlickable" in appearance
    assert "flickable.contentY = Math.max" in appearance

def test_registered_panes_take_shared_session():
    for entry in _registry_entries():
        text = (CC / entry["component"]).read_text()
        assert ("required property Session session" in text
                or "required property CC.Session session" in text), (
            f"pane {entry['id']}: must declare `required property [CC.]Session session`"
        )


def test_session_type_never_shadowed():
    # `import qs.modules.welcome` brings a second `Session` name (its
    # singleton) into scope. A pane that imports it must qualify the
    # session property (`CC.Session`); unqualified, the loader's session
    # value fails assignment and the pane renders blank (system pane).
    for entry in _registry_entries():
        text = (CC / entry["component"]).read_text()
        if "import qs.modules.welcome" in text:
            assert "required property CC.Session session" in text, (
                f"pane {entry['id']}: imports qs.modules.welcome, so the session "
                "property must be qualified as `CC.Session`"
            )


def test_no_dead_wrappers_in_panes():
    hits = []
    for path in CC.rglob("*.qml"):
        text = path.read_text()
        for dead in DEAD_WRAPPERS:
            if dead in text:
                hits.append(f"{path.relative_to(ROOT)}: {dead}")
    assert not hits, f"retired wrappers invoked by panes:\n" + "\n".join(hits)


def test_dynamic_settings_window_is_visible_on_creation():
    text = WINDOW_FACTORY.read_text()
    window = text[text.index("FloatingWindow {"):]
    assert "visible: true" in window, (
        "QWindow starts hidden by default; without visible: true the close "
        "handler immediately destroys Settings after creation"
    )

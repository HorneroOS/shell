"""Control Center pane load contracts (black-pane regression).

Two load-fatal defect classes shipped because no test instantiated a
pane or checked shared-component contracts:

1. Studio/Gaming assigned `session:` to SplitPaneLayout, which does
   not declare it. Assigning a non-existent property fails the whole
   component creation; the Panes Loader keeps item=null and the pane
   renders completely black (pelicano, Preview 30).
2. ExtensionsPane uses sibling types (CommunityRegistrySection,
   DesktopWidgetPosition) that are only registered when the
   "extensions" directory is imported by Panes.qml; without that
   import the Loader fails with "is not a type" and the same black
   pane results.

These tests pin both contracts for every registered pane, and pin
that Panes.qml surfaces Loader errors instead of swallowing them.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"


def _registered_pane_files():
    registry = (CC / "PaneRegistry.qml").read_text()
    components = re.findall(r'component:\s*"([^"]+)"', registry)
    assert components, "no panes registered in PaneRegistry.qml"
    return [CC / name for name in components]


def _split_pane_layout_properties():
    layout = (CC / "components" / "SplitPaneLayout.qml").read_text()
    declared = set(re.findall(r"^\s*property\s+\w+\s+(\w+)", layout, re.M))
    declared |= set(re.findall(r"^\s*property\s+alias\s+(\w+)", layout, re.M))
    # QML built-ins every Item accepts.
    declared |= {
        "id", "anchors", "width", "height", "x", "y", "visible", "opacity",
        "clip", "layer", "state", "states", "transitions", "transform",
        "focus", "enabled", "parent", "children", "resources", "data",
    }
    return declared


def test_panes_assign_only_declared_split_pane_layout_properties():
    declared = _split_pane_layout_properties()
    for pane_file in _registered_pane_files():
        src = pane_file.read_text()
        for block in re.finditer(r"SplitPaneLayout\s*\{(.*?)\n    \}", src, re.S):
            for prop in re.findall(r"^\s{8}(\w+):", block.group(1), re.M):
                assert prop in declared, (
                    f"{pane_file.name}: SplitPaneLayout has no property "
                    f"'{prop}' (declared: {sorted(declared)}); assigning "
                    "it fails the whole pane load (black pane)"
                )


def test_sibling_types_of_every_pane_are_imported():
    panes = (CC / "Panes.qml").read_text()
    panes_imports = set(re.findall(r'^import\s+"([^"]+)"', panes, re.M))
    for pane_file in _registered_pane_files():
        src = pane_file.read_text()
        own_imports = set(re.findall(r'^import\s+"([^"]+)"', src, re.M))
        siblings = {
            path.stem
            for path in pane_file.parent.glob("*.qml")
            if path != pane_file
        }
        used = {name for name in siblings if re.search(rf"\b{name}\b", src)}
        # Sibling types resolve only when the pane's directory is
        # imported by Panes.qml or by the pane itself ("." / dir name).
        directory = pane_file.parent.name
        registered = (
            directory in panes_imports
            or "." in own_imports
            or directory in own_imports
        )
        assert not used or registered, (
            f"{pane_file.name} uses sibling types {sorted(used)} but "
            f"neither Panes.qml nor the pane imports \"{directory}\"; "
            "they fail with 'is not a type' and the pane renders black"
        )


def test_extensions_sibling_types_exist_next_to_pane():
    extensions = CC / "extensions"
    src = (extensions / "ExtensionsPane.qml").read_text()
    for type_name in ("CommunityRegistrySection", "DesktopWidgetPosition"):
        assert type_name in src
        assert (extensions / f"{type_name}.qml").is_file()


def test_panes_loader_surfaces_errors_visibly():
    panes = (CC / "Panes.qml").read_text()
    assert "onStatusChanged" in panes
    assert "Loader.Error" in panes
    assert "console.error" in panes
    # A visible, localized fallback instead of a silent black area.
    assert 'qsTr("This panel failed to load.' in panes

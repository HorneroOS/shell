"""Multi-compositor Niri / Wayland parity contracts (HorneroOS/shell#736):
compositor-neutral shared modules route through services/Compositor.qml with
zero direct Quickshell.Hyprland or Hypr. leakage, Niri output metadata is
read without polling, and DisplaysPane guards Hyprland-only probes.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

COMPOSITOR_NEUTRAL_FILES = [
    "services/Brightness.qml",
    "modules/bar/Bar.qml",
    "modules/bar/components/PinnedApps.qml",
    "modules/bar/components/workspaces/Workspaces.qml",
    "modules/bar/components/workspaces/Workspace.qml",
    "modules/bar/popouts/LockStatus.qml",
    "modules/bar/popouts/ActiveWindow.qml",
    "modules/bar/popouts/Wrapper.qml",
    "modules/launcher/services/Windows.qml",
    "modules/dashboard/Workspaces.qml",
    "modules/dashboard/dash/WorkspacePreview.qml",
    "modules/dashboard/dash/WsActionsBar.qml",
    "modules/windowinfo/WindowInfo.qml",
    "modules/windowinfo/Details.qml",
    "modules/windowinfo/Buttons.qml",
    "modules/windowinfo/Preview.qml",
    "modules/areapicker/Picker.qml",
    "modules/controlcenter/displays/DisplaysPane.qml",
]


def test_compositor_neutral_modules_have_no_direct_hypr_references():
    leaks = []
    for rel in COMPOSITOR_NEUTRAL_FILES:
        src = (ROOT / rel).read_text(encoding="utf-8")
        if "Hypr." in src:
            leaks.append(f"{rel}: direct Hypr. reference")
    assert not leaks, "Direct Hypr. leakage found:\n" + "\n".join(leaks)


def test_compositor_neutral_windows_and_dashboard_drop_hyprland_import():
    for rel in (
        "modules/dashboard/dash/WorkspacePreview.qml",
        "modules/dashboard/dash/WsActionsBar.qml",
        "modules/windowinfo/WindowInfo.qml",
        "modules/windowinfo/Details.qml",
        "modules/windowinfo/Preview.qml",
    ):
        src = (ROOT / rel).read_text(encoding="utf-8")
        assert "import Quickshell.Hyprland" not in src, f"{rel} must not import Quickshell.Hyprland"


def test_compositor_facade_exposes_multi_compositor_primitives():
    comp = (ROOT / "services/Compositor.qml").read_text(encoding="utf-8")
    for needle in (
        "import Quickshell.Wayland as Wayland",
        "function allWindowSummaries(): var",
        "function scrollWorkspace(",
        "function outputMetadataFor(",
        "function windowDetails(",
        "function moveWindowToWorkspace(",
        "function isScreenFocused(",
        "function pickerClientsForScreen(",
        "ToplevelManager",
    ):
        assert needle in comp, f"Compositor.qml missing: {needle}"


def test_niri_reads_output_metadata_on_demand_without_polling():
    niri = (ROOT / "services/Niri.qml").read_text(encoding="utf-8")
    assert '["niri", "msg", "--json", "outputs"]' in niri
    assert "function outputMetadata(name: string)" in niri
    assert "function refreshOutputs(): void" in niri
    outputs_block = niri.split("id: outputsProcess", 1)[1]
    assert "running: false" in outputs_block


def test_displays_pane_guards_hyprland_probes_off_hyprland():
    pane = (ROOT / "modules/controlcenter/displays/DisplaysPane.qml").read_text(encoding="utf-8")
    assert "Compositor.outputMetadataFor(s)" in pane
    assert pane.count("Compositor.isHyprland") >= 3

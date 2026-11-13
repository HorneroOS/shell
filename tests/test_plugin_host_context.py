"""Responsive plugin host context (#372): static QML contract tests.

The host exposes orientation/edge/available-space context to every
visible placement by injecting it into entrypoint properties the
plugin opted into. Injection must stay guarded (additive: plugins
declaring none of the properties are untouched), caps must be the
same numbers the host reports, and PluginKit must not leak shell
internals. Compositor evidence (real edges/scales/monitors) is not
available to these unit tests; they pin the host contract only.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BAR_WIDGETS = (ROOT / "modules/plugins/PluginBarWidgets.qml").read_text()
CARDS = (ROOT / "modules/plugins/PluginDashboardCards.qml").read_text()
DESKTOP = (ROOT / "modules/plugins/PluginDesktopWidgets.qml").read_text()
BAR = (ROOT / "modules/bar/Bar.qml").read_text()
KIT = ROOT / "plugin/qml/Hornero/PluginKit"
DOCS = (ROOT / "docs/PLUGINS.md").read_text()

HOST_PROPERTIES = [
    "hostOrientation",
    "hostEdge",
    "hostSurface",
    "hostAvailableWidth",
    "hostAvailableHeight",
    "hostCompact",
    "hostScreenName",
]

HOSTS = {"bar": BAR_WIDGETS, "dashboard": CARDS, "desktop": DESKTOP}


def test_every_visible_host_injects_full_context_guarded():
    # Additive contract: each host binds every context property only
    # when the loaded entrypoint declares it, so the 33 shipped
    # plugins that declare none load exactly as before.
    for surface, src in HOSTS.items():
        for prop in HOST_PROPERTIES:
            assert f'property: "{prop}"' in src, (surface, prop)
            assert f'"{prop}" in pluginLoader.item' in src, (surface, prop)
        assert src.count("RestoreNone") >= len(HOST_PROPERTIES), surface
        assert f'value: "{surface}"' in src, surface


def test_bar_context_covers_all_four_edges_and_real_geometry():
    # All four edges: the bar passes its spec edge through untouched;
    # orientation derives from it via the existing vertical flag.
    assert "edge: root.edge" in BAR
    assert 'edge === "left" || edge === "right"' in BAR
    for edge in ("top", "bottom", "left", "right"):
        assert f'"{edge}"' in BAR_WIDGETS or f'"{edge}"' in BAR
    assert 'vertical ? "vertical" : "horizontal"' in BAR_WIDGETS
    # Available space is real surface geometry, not plugin guesswork:
    # cross-axis from spec.thickness, compact from the bar width
    # breakpoint, screen from this bar instance (multi-monitor).
    assert "thickness: root.spec.thickness" in BAR
    assert "compact: root.compact" in BAR
    assert "screenName: root.screen.name" in BAR
    assert "hostCompact: vertical || compact" in BAR_WIDGETS


def test_reported_available_space_equals_enforced_caps():
    # No clipping surprises: the numbers plugins read are exactly the
    # Layout caps the host enforces on the same Loader.
    assert "Layout.maximumWidth: root.availableWidth" in BAR_WIDGETS
    assert "value: root.availableWidth" in BAR_WIDGETS
    assert "Layout.maximumHeight: root.availableHeight" in BAR_WIDGETS
    assert "value: root.availableHeight" in BAR_WIDGETS
    for src in (CARDS, DESKTOP):
        assert "Layout.maximumWidth: hostAvailableWidth" in src
        assert "value: pluginLoader.hostAvailableWidth" in src
        # Scrolling/card surfaces do not cap height; 0 says so.
        assert "hostAvailableHeight: 0" in src


def test_desktop_context_names_its_screen():
    assert "value: root.screenName" in DESKTOP


def test_uistack_stacks_instead_of_forcing_rows_into_rails():
    src = (KIT / "UiStack.qml").read_text(encoding="utf-8")
    qmldir = (KIT / "qmldir").read_text(encoding="utf-8")
    assert "UiStack 1.0 UiStack.qml" in qmldir
    assert 'property string orientation: "horizontal"' in src
    assert "property bool compact: false" in src
    assert 'orientation === "vertical" || compact' in src
    assert "GridLayout.TopToBottom" in src
    assert "Theme." in src
    # PluginKit facades never leak shell internals.
    assert "qs." not in src and "import qs" not in src
    imports = re.findall(r"^\s*import\s+([A-Za-z0-9_.]+)", src, re.MULTILINE)
    assert set(imports) <= {"QtQuick", "QtQuick.Controls", "QtQuick.Layouts"}


def test_example_clock_opts_in_with_safe_defaults():
    src = (ROOT / "examples/plugins/example-clock/Main.qml").read_text()
    assert 'property string hostOrientation: "horizontal"' in src
    assert "property bool hostCompact: false" in src
    assert "root.hostCompact" in src


def test_docs_document_host_context_and_evidence_limits():
    assert "## Host context" in DOCS
    for prop in HOST_PROPERTIES:
        assert f"`{prop}`" in DOCS, prop
    assert "UiStack" in DOCS
    # Honest evidence label: unit/host contract tests, no compositor.
    assert "compositor" in DOCS

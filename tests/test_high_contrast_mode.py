"""High-contrast mode swaps in Signal High Contrast, opaque and WCAG AA legible."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from signal_tokens import ROOT, SIGNAL, SURFACES, built_in_themes, contrast  # noqa: E402

CONFIG = ROOT / "config" / "AppearanceConfig.qml"
CONFIG_ADAPTER = ROOT / "config" / "Config.qml"
PANE = ROOT / "modules" / "controlcenter" / "accessibility" / "AccessibilityPane.qml"
BAR = ROOT / "modules" / "bar" / "Bar.qml"

TEXT_PAIRS = (
    ("onSignal", "signal"),
    ("onSignalWell", "signalWell"),
    ("onCue", "cue"),
    ("onCueWell", "cueWell"),
    ("onPhosphor", "phosphor"),
    ("onPhosphorWell", "phosphorWell"),
    ("onAlert", "alert"),
    ("onAlertWell", "alertWell"),
    ("onInverse", "inverse"),
)


def high_contrast_tokens() -> dict:
    return built_in_themes()["hornero-signal-contrast"]["palette"]


def test_high_contrast_text_roles_meet_wcag_aa() -> None:
    tokens = high_contrast_tokens()
    for foreground, background in TEXT_PAIRS:
        assert contrast(tokens[foreground], tokens[background]) >= 4.5, (
            f"{foreground} on {background} misses 4.5:1"
        )
    for foreground in ("ink", "inkMuted", "signal", "cue", "phosphor", "alert"):
        for background in SURFACES:
            assert contrast(tokens[foreground], tokens[background]) >= 4.5, (
                f"{foreground} on {background} misses 4.5:1"
            )


def test_high_contrast_boundaries_and_focus_are_visible() -> None:
    tokens = high_contrast_tokens()
    for edge in ("ruleStrong", "rule", "focus"):
        for surface in SURFACES:
            assert contrast(tokens[edge], tokens[surface]) >= 3.0, (
                f"{edge} against {surface} misses 3:1"
            )


def test_high_contrast_is_persisted_and_disables_transparency() -> None:
    signal = SIGNAL.read_text(encoding="utf-8")
    appearance_config = CONFIG.read_text(encoding="utf-8")
    adapter = CONFIG_ADAPTER.read_text(encoding="utf-8")
    pane = PANE.read_text(encoding="utf-8")

    assert "property bool highContrast: false" in appearance_config
    assert "highContrast: appearance.highContrast" in adapter
    assert "Config.appearance.highContrast ? contrastPalette : current" in signal
    assert "Appearance.transparency.enabled && !Config.appearance.highContrast" in signal
    assert 'label: qsTr("High contrast")' in pane
    assert "Config.appearance.highContrast = checked" in pane
    assert "Config.save()" in pane


def test_high_contrast_disclosure_limits_scope_to_shell() -> None:
    pane = PANE.read_text(encoding="utf-8")
    assert "opaque high-contrast palette across Hornero Shell" in pane
    assert "Other applications keep their current theme." in pane


def test_high_contrast_keeps_clear_bars_opaque() -> None:
    bar = BAR.read_text(encoding="utf-8")
    assert 'opacity: Config.appearance.highContrast ? 1 :' in bar
    assert 'Config.appearance.highContrast || scrim.fromStart ? Signal.palette.base : "transparent"' in bar
    assert 'Config.appearance.highContrast || !scrim.fromStart ? Signal.palette.base : "transparent"' in bar
    pane = PANE.read_text(encoding="utf-8")
    assert "enabled: !Config.appearance.highContrast" in pane
    assert "Transparency is disabled while high contrast is on." in pane

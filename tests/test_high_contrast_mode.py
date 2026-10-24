"""High-contrast mode keeps the shell palette opaque and WCAG AA legible."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COLOURS = ROOT / "services" / "Colours.qml"
CONFIG = ROOT / "config" / "AppearanceConfig.qml"
CONFIG_ADAPTER = ROOT / "config" / "Config.qml"
PANE = ROOT / "modules" / "controlcenter" / "accessibility" / "AccessibilityPane.qml"
BAR = ROOT / "modules" / "bar" / "Bar.qml"

TEXT_PAIRS = (
    ("m3onBackground", "m3background"),
    ("m3onSurface", "m3surface"),
    ("m3onSurfaceVariant", "m3surfaceVariant"),
    ("m3inverseOnSurface", "m3inverseSurface"),
    ("m3onPrimary", "m3primary"),
    ("m3onPrimaryContainer", "m3primaryContainer"),
    ("m3onSecondary", "m3secondary"),
    ("m3onSecondaryContainer", "m3secondaryContainer"),
    ("m3onTertiary", "m3tertiary"),
    ("m3onTertiaryContainer", "m3tertiaryContainer"),
    ("m3onError", "m3error"),
    ("m3onErrorContainer", "m3errorContainer"),
    ("m3onSuccess", "m3success"),
    ("m3onSuccessContainer", "m3successContainer"),
    ("m3onPrimaryFixed", "m3primaryFixed"),
    ("m3onPrimaryFixed", "m3primaryFixedDim"),
    ("m3onPrimaryFixedVariant", "m3primaryFixed"),
    ("m3onPrimaryFixedVariant", "m3primaryFixedDim"),
    ("m3onSecondaryFixed", "m3secondaryFixed"),
    ("m3onSecondaryFixed", "m3secondaryFixedDim"),
    ("m3onSecondaryFixedVariant", "m3secondaryFixed"),
    ("m3onSecondaryFixedVariant", "m3secondaryFixedDim"),
    ("m3onTertiaryFixed", "m3tertiaryFixed"),
    ("m3onTertiaryFixed", "m3tertiaryFixedDim"),
    ("m3onTertiaryFixedVariant", "m3tertiaryFixed"),
    ("m3onTertiaryFixedVariant", "m3tertiaryFixedDim"),
)
SURFACES = (
    "m3background",
    "m3surface",
    "m3surfaceDim",
    "m3surfaceBright",
    "m3surfaceVariant",
    "m3surfaceContainerLowest",
    "m3surfaceContainerLow",
    "m3surfaceContainer",
    "m3surfaceContainerHigh",
    "m3surfaceContainerHighest",
)


def high_contrast_tokens() -> dict[str, str]:
    text = COLOURS.read_text(encoding="utf-8")
    region = text.split("readonly property M3Palette highContrastPalette: M3Palette {", 1)[1]
    region = region.split("\n    }", 1)[0]
    return dict(re.findall(r'\b(m3\w+|term\d+):\s*"(#[0-9a-fA-F]{6})"', region))


def luminance(value: str) -> float:
    channels = [int(value[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
              for channel in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(foreground: str, background: str) -> float:
    high, low = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def test_high_contrast_text_roles_meet_wcag_aa() -> None:
    tokens = high_contrast_tokens()
    for foreground, background in TEXT_PAIRS:
        assert contrast(tokens[foreground], tokens[background]) >= 4.5, (
            f"{foreground} on {background} misses 4.5:1"
        )
    for foreground in ("m3onSurface", "m3onSurfaceVariant"):
        for background in SURFACES:
            assert contrast(tokens[foreground], tokens[background]) >= 4.5, (
                f"{foreground} on {background} misses 4.5:1"
            )


def test_high_contrast_boundaries_and_focus_are_visible() -> None:
    tokens = high_contrast_tokens()
    for edge in ("m3outline", "m3outlineVariant"):
        for surface in SURFACES:
            assert contrast(tokens[edge], tokens[surface]) >= 3.0, (
                f"{edge} against {surface} misses 3:1"
            )
    assert "readonly property color focusRing: palette.m3primary" in COLOURS.read_text(encoding="utf-8")
    for surface in SURFACES:
        assert contrast(tokens["m3primary"], tokens[surface]) >= 3.0, (
            f"focus ring against {surface} misses 3:1"
        )


def test_high_contrast_overrides_every_palette_role() -> None:
    text = COLOURS.read_text(encoding="utf-8")
    default_table = text.split("component M3Palette: QtObject {", 1)[1]
    default_table = default_table.split("\n    }", 1)[0]
    defaults = set(re.findall(r"property color (m3\w+|term\d+):", default_table))
    assert defaults == set(high_contrast_tokens())


def test_high_contrast_is_persisted_and_disables_transparency() -> None:
    colours = COLOURS.read_text(encoding="utf-8")
    appearance_config = CONFIG.read_text(encoding="utf-8")
    adapter = CONFIG_ADAPTER.read_text(encoding="utf-8")
    pane = PANE.read_text(encoding="utf-8")

    assert "property bool highContrast: false" in appearance_config
    assert "highContrast: appearance.highContrast" in adapter
    assert "Config.appearance.highContrast ? highContrastPalette" in colours
    assert "Appearance.transparency.enabled && !Config.appearance.highContrast" in colours
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
    assert 'Config.appearance.highContrast || scrim.fromStart ? Colours.palette.m3surface : "transparent"' in bar
    assert 'Config.appearance.highContrast || !scrim.fromStart ? Colours.palette.m3surface : "transparent"' in bar
    pane = PANE.read_text(encoding="utf-8")
    assert "enabled: !Config.appearance.highContrast" in pane
    assert "Transparency is disabled while high contrast is on." in pane

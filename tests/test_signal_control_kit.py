"""Signal Bezel control kit (signal-visual-language §6.2, §8, §15).

The shared primitives exist, interaction states are flat fills (no
ripple, no pill morphs), and the segmented meter follows the
real-data/threshold rules. Genuinely circular elements (radio dots)
keep `rounding.full`; everything else in the control kit is a
rectangular channel cell.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / "components"
CONTROLS = COMPONENTS / "controls"

PRIMITIVES = (
    "Eyebrow.qml",
    "Hairline.qml",
    "OnAirBar.qml",
    "OnAirChip.qml",
    "RegistrationTick.qml",
    "SegmentMeter.qml",
    "Well.qml",
)


def _src(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_bezel_primitives_exist():
    for name in PRIMITIVES:
        assert (COMPONENTS / name).is_file(), name
    assert (CONTROLS / "SegmentedControl.qml").is_file()


def test_well_is_sunken_with_rule_border():
    src = _src(COMPONENTS / "Well.qml")
    assert "Signal.palette.sunken" in src
    assert "border.width: 1" in src
    assert "Appearance.rounding.small" in src
    # Cockpit Clear: outline only, no fill (§12.1).
    assert '"transparent"' in src


def test_on_air_chip_is_signal_fill():
    src = _src(COMPONENTS / "OnAirChip.qml")
    assert "color: Signal.palette.signal" in src
    assert "Signal.palette.onSignal" in src


def test_eyebrow_is_tracked_mono_uppercase():
    src = _src(COMPONENTS / "Eyebrow.qml")
    assert "mono: true" in src
    assert "Font.AllUppercase" in src
    assert "0.08" in src  # +8 % tracking
    assert "Signal.palette.inkMuted" in src


def test_segment_meter_thresholds_and_unavailable_state():
    src = _src(COMPONENTS / "SegmentMeter.qml")
    assert "property real threshold: 0.85" in src
    # `alert` only above a caller-supplied critical threshold (§6.2).
    assert "root.critical >= 0" in src
    assert "Signal.palette.alert" in src
    # Unavailable source: every segment off (§6.1).
    assert "root.available" in src
    assert "Signal.palette.rule" in src  # off segments
    # Vertical VU meters use phosphor; horizontal meters use ink.
    assert "Signal.palette.phosphor" in src
    # No tweening of sampled values (§6.5/§11.2).
    assert "Behavior on value" not in src
    assert "Animation" not in src


def test_segmented_control_uses_selected_well():
    src = _src(CONTROLS / "SegmentedControl.qml")
    assert "Signal.palette.signalWell" in src
    assert "Signal.palette.onSignalWell" in src
    assert "Accessible.role: Accessible.RadioButton" in src
    assert "signal activated(int index)" in src


def test_state_layer_has_no_ripple():
    src = _src(COMPONENTS / "StateLayer.qml")
    assert "rippleAnim" not in src
    assert "SequentialAnimation" not in src
    # Flat hover/pressed washes stay (§8).
    assert "0.08" in src and "0.12" in src


def test_controls_are_not_pills():
    # Radio dots are genuinely circular and keep `rounding.full`
    # (AppearanceConfig rounding contract); no other control may.
    for path in sorted(CONTROLS.glob("*.qml")):
        if path.name == "StyledRadioButton.qml":
            continue
        src = _src(path)
        assert "rounding.full" not in src, path.name
        assert "implicitHeight / 2 * Math.min(1, Appearance.rounding.scale)" not in src, path.name

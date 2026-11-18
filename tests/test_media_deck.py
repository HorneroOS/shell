"""Media deck (Caelestia-recovery item 5, Hornero adaptation): cover well
flanked by stereo L/R spectrum columns with amber peak-hold ticks, a tape
counter over the seek meter, and NO SIGNAL with Javi dozing when idle.

Static contracts; the offscreen renders live in tests/test_media_deck_render.py.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECK = ROOT / "modules/dashboard/dash/Media.qml"
SECTION = ROOT / "modules/controlcenter/dashboard/MediaDeckSection.qml"
FACTORY = json.loads((ROOT / "config/shell.default.json").read_text())


def test_factory_defaults_and_serializer():
    media = FACTORY["dashboard"]["media"]
    assert media == {"spectrum": True, "peakHold": True, "bands": 12, "javi": True}
    cfg = (ROOT / "config/DashboardConfig.qml").read_text()
    for line in ("property bool spectrum: true", "property bool peakHold: true", "property int bands: 12", "property bool javi: true"):
        assert line in cfg
    ser = (ROOT / "config/Config.qml").read_text()
    for key in ("spectrum", "peakHold", "bands", "javi"):
        assert f"{key}: dashboard.media.{key}" in ser
    ranges = json.loads((ROOT / "config/ranges.json").read_text())["ranges"]
    assert ranges["dashboard.media.bands"] == {"min": 8, "max": 24, "step": 1, "default": 12}


def test_deck_reads_real_stereo_left_then_right():
    deck = DECK.read_text()
    audio = (ROOT / "services/Audio.qml").read_text()
    assert "cavaStereo.channels = 2" in audio and "id: cavaStereo" in audio
    assert deck.count("values: Audio.cavaStereo.values") == 2
    assert "sliceStart: 0" in deck and "sliceStart: root.bands" in deck
    assert "direction: SpectrumMeter.Left" in deck and "direction: SpectrumMeter.Right" in deck
    collector = (ROOT / "plugin/src/Hornero/Services/audiocollector.cpp").read_text()
    assert "info.channels = ac::CHANNELS" in collector and "SPA_AUDIO_CHANNEL_FR" in collector
    cava = (ROOT / "plugin/src/Hornero/Services/cavaprovider.cpp").read_text()
    assert "readStereoChunk" in cava and "cava_init(m_bars, ac::SAMPLE_RATE, m_channels" in cava


def test_deck_is_signal_not_material():
    deck = DECK.read_text()
    # No radial bars, no arc around the cover, no gifs, no pills.
    for banned in ("Shape", "PathArc", "AnimatedImage", ".gif", "rounding.full", "Material"):
        assert banned not in deck, banned
    assert "peakHold: root.media.peakHold" in deck
    assert "offColor: Signal.palette.rule" in deck
    assert "Instruments.Well" in deck and "TapeCounter" in deck and '"tnum": 1' in deck


def test_idle_deck_says_no_signal_and_javi_dozes():
    deck = DECK.read_text()
    assert 'qsTr("NO SIGNAL")' in deck
    assert 'Companion.resolve(CompanionStore.effectiveSkin, "sleep")' in deck
    assert "dozing: !hasPlayer && media.javi && Atmosphere.mascot" in deck
    assert deck.count("Nothing playing") == 1


def test_idle_deck_costs_nothing_and_respects_motion():
    deck = DECK.read_text()
    assert "spectrumOn: media.spectrum && Choreography.animated" in deck
    assert "service: root.playing && root.spectrumOn && root.visibilities.dashboard ? Audio.cavaStereo : null" in deck
    assert deck.count("active: root.playing") == 2
    assert deck.count("visible: root.spectrumOn") == 2


def test_accessible_names():
    deck = DECK.read_text()
    for name in ("Left channel spectrum", "Right channel spectrum", "Position %1 of %2", "Playback position",
                 "No signal: nothing is playing", "Previous track", "Next track"):
        assert f'qsTr("{name}")' in deck, name


def test_control_center_section_with_reset():
    text = SECTION.read_text()
    for key in ("spectrum", "peakHold", "javi"):
        assert f"root.media.{key} = checked" in text
    assert re.search(r'SizeSlider \{[^}]*key: "bands"[^}]*from: 8[^}]*to: 24[^}]*defaultValue: 12', text, re.S)
    assert "function resetAll()" in text and "Undo.offerValues" in text
    pane = (ROOT / "modules/controlcenter/dashboard/DashboardPane.qml").read_text()
    assert "MediaDeckSection {}" in pane
    registry = (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()
    assert 'id: "media-deck"' in registry

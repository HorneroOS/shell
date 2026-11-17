"""assets/logo.svg is the Hornero Signal mark (copy of HorneroOS/config
assets/brand/logo.svg), not the retired clay/terracotta artwork. It is shown
only as a 23-26 px identifier (Control Center title, Welcome header, bar OS
icon) so the mark never dominates workstation UI."""
from pathlib import Path

LOGO = (Path(__file__).resolve().parent.parent / "assets" / "logo.svg").read_text(encoding="utf-8").lower()

RETIRED = ("#e07856", "#b24827", "#f2b749", "#2b1a11", "#7c4a2c", "#fffdf7", "#e89a55")


def test_logo_uses_signal_colours_only():
    for colour in RETIRED:
        assert colour not in LOGO, colour
    for colour in ("#ffb650", "#f2a33a", "#8f4b00", "#1b1e22"):
        assert colour in LOGO, colour


def test_logo_is_vector_and_self_contained():
    assert "<image" not in LOGO and "data:image" not in LOGO

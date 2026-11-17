"""Experience-mode chrome (shell#511): the five modes must read as
different places, not only through the mode chip. Factory chrome fields are
validated headless; the QML wiring is pinned statically."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "experience.js"
EXP = (ROOT / "services" / "Experience.qml").read_text()
CHROME = (ROOT / "components" / "ModeChrome.qml").read_text()
BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
MODES = ["focus", "everyday", "signal", "gaming", "studio"]


def run_js(expr):
    src = JS.read_text().replace(".pragma library", "", 1)
    out = subprocess.run([shutil.which("node"), "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                         capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


def test_every_mode_has_a_distinct_chrome_signature():
    sig = run_js("""return MODE_IDS.map(m => { const f = FACTORY[m].fields;
        return [m, f['chrome.accent'], f['chrome.edge'], f['chrome.wash'], f.scanlines, f.glow, f.density, f.desktopWidgets].join('|'); });""")
    assert len(set(sig)) == len(MODES), sig


def test_signal_is_the_richest_and_everyday_is_plain():
    f = run_js("return {s: FACTORY.signal.fields, e: FACTORY.everyday.fields};")
    assert (f["s"]["chrome.accent"], f["s"]["chrome.edge"], f["s"]["scanlines"]) == ("signal", "glow", True)
    assert f["s"]["chrome.wash"] > 0
    assert (f["e"]["chrome.accent"], f["e"]["chrome.edge"], f["e"]["chrome.wash"]) == ("none", "off", 0)


def test_chrome_overrides_validate_and_clamp():
    r = run_js("""return [validateField('chrome.accent','phosphor'), validateField('chrome.accent','red'),
        validateField('chrome.edge','glow'), validateField('chrome.edge','neon'),
        validateField('chrome.wash', 5), validateField('chrome.wash', -1)];""")
    assert r == ["phosphor", None, "glow", None, 0.2, 0]


def test_glow_edge_degrades_and_high_contrast_drops_wash():
    assert 'e === "glow" && !root.glow ? "hairline"' in EXP
    assert "Config.appearance.highContrast ? 0" in EXP


def test_chrome_is_inert_reduced_motion_aware_and_on_bars():
    assert "enabled: false" in CHROME and "Accessible.ignored: true" in CHROME
    assert "Appearance.anim.reduced" in CHROME
    assert "Experience.acquireGlow" in CHROME
    assert "ModeChrome {" in BAR and "!root.clear" in BAR

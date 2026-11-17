"""Shell-wide glow budget (visual language §9: at most three glowing items
on a screen, static, 4 px, 40 %). Experience owns one budget shared by the
native instruments (on-air bar, scope traces) and PluginKit traces (the
Signal deck), so they can never exceed three together. Extensions leave a
slot to the shell.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPERIENCE = (ROOT / "services" / "Experience.qml").read_text()
KIT = ROOT / "plugin" / "qml" / "Hornero" / "PluginKit"
BUDGET = (KIT / "GlowBudget.qml").read_text()
BRIDGE = (KIT / "ExperienceBridge.qml").read_text()
SCOPE = (ROOT / "modules" / "instruments" / "ScopeTrace.qml").read_text()
ONAIR = (ROOT / "components" / "OnAirBar.qml").read_text()


def test_one_budget_of_three_lives_in_experience():
    assert "readonly property int glowLimit: 3" in EXPERIENCE
    assert "function acquireGlow(owner: var, reserve: int): bool" in EXPERIENCE
    assert "function releaseGlow(owner: var): void" in EXPERIENCE
    assert "root._glowHolders.length >= root.glowLimit - Math.max(0, reserve)" in EXPERIENCE


def test_pluginkit_delegates_and_leaves_a_slot_to_the_shell():
    assert "ExperienceBridge.acquireGlow(owner, root.reserved)" in BUDGET
    assert "readonly property int reserved: 1" in BUDGET
    assert "readonly property int limit: 3" in BUDGET
    assert "Experience.acquireGlow(owner, reserve)" in BRIDGE
    assert "_holders" not in BUDGET  # no second counter


def test_native_instruments_lease_before_glowing():
    for name, src in (("ScopeTrace", SCOPE), ("OnAirBar", ONAIR)):
        assert "Experience.acquireGlow(root, 0)" in src, name
        assert "Experience.releaseGlow(root)" in src, name
        assert "glowWanted && root._granted" in src, name
        assert "Component.onDestruction" in src, name
    # Static halo: no animation of the glow itself.
    assert not re.search(r"glow[^\n]*Animation|Animation[^\n]*glow", SCOPE + ONAIR, re.I)


def test_budget_semantics_under_node():
    import json
    import shutil
    import subprocess
    node = shutil.which("node")
    assert node
    js = """
    var holders = [], limit = 3;
    function acquire(o, r) {
      if (holders.indexOf(o) >= 0) return true;
      if (holders.length >= limit - Math.max(0, r)) return false;
      holders = holders.concat([o]); return true;
    }
    function release(o) { var i = holders.indexOf(o); if (i >= 0) holders.splice(i, 1); }
    var out = [];
    out.push(acquire("a", 1), acquire("b", 1), acquire("c", 1));  // extensions: 2 only
    out.push(acquire("bar", 0));                                    // shell takes the last slot
    out.push(acquire("scope", 0));                                  // fourth is refused
    release("a");
    out.push(acquire("c", 1));                                      // extension still refused (2 held + reserve)
    out.push(holders.length);
    console.log(JSON.stringify(out));
    """
    proc = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    assert json.loads(proc.stdout) == [True, True, False, True, False, False, 2]

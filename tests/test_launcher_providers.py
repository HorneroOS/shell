"""Launcher provider registry + calc/windows providers (shell#250 slice 1).

Static QML contracts in repo style, plus executable tests: the
calculator parser and the window filter are pure JS modules, so
they run under node against real inputs (malformed, div-zero,
fixture windows) instead of only being pattern-matched.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICES = ROOT / "modules" / "launcher" / "services"
PROVIDERS = (SERVICES / "Providers.qml").read_text()
APPLIST = (ROOT / "modules" / "launcher" / "AppList.qml").read_text()


def _run_js(module: Path, driver: str):
    node = shutil.which("node")
    assert node, "node is required to execute the pure-JS provider modules"
    src = module.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\n" + driver],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


# --- Registry contract -------------------------------------------------

def test_registry_declares_provider_contract():
    for field in ('"id"', '"prefix"', '"icon"', '"section"'):
        assert field in PROVIDERS, field
    assert "function registerProvider(spec" in PROVIDERS
    assert "function providerFor(text" in PROVIDERS
    assert "function query(text" in PROVIDERS
    assert "function activate(result" in PROVIDERS
    # Result shape is documented and produced by built-ins.
    for field in ('"providerId"', '"title"', '"subtitle"', '"payload"'):
        assert field in PROVIDERS, field


def test_registry_rejects_duplicates_and_malformed():
    assert "p.id === spec.id" in PROVIDERS, "duplicate id not rejected"
    assert "p.prefix === spec.prefix" in PROVIDERS, "duplicate prefix not rejected"
    assert "typeof spec.query !== \"function\"" in PROVIDERS


def test_registry_registers_built_ins_with_apps_default():
    for pid in ('"id": "apps"', '"id": "calc"', '"id": "win"'):
        assert pid in PROVIDERS, pid
    # Apps is the default provider: empty prefix.
    m = re.search(r'"id": "apps",\s*"prefix": ""', PROVIDERS)
    assert m, "apps provider must own the empty (default) prefix"


def test_applist_routes_via_registry_without_replacing_state_machine():
    assert "Providers.stateFor(text)" in APPLIST
    # The AppList state machine and its states all survive.
    for state in ('"apps"', '"actions"', '"calc"', '"win"', '"file"', '"ai"'):
        assert f"name: {state}" in APPLIST, state
    # Apps fallback is byte-identical: same state, same search call.
    assert "model.values: Apps.search(search.text)" in APPLIST
    assert 'return "apps";' in APPLIST


def test_plugin_providers_not_hosted_in_this_slice():
    assert "NOT hosted" in PROVIDERS and "surfaces.launcher" in PROVIDERS
    docs = (ROOT / "docs" / "LAUNCHER.md").read_text()
    assert "follow-up slice" in docs
    assert "unsandboxed" in docs, "plugin trust wording missing"
    host = (ROOT / "modules" / "plugins" / "PluginHost.qml").read_text()
    assert "no host yet" in host, "PluginHost must stay unload-only for launcher"


# --- Calculator provider ------------------------------------------------

def test_calc_uses_own_parser_no_eval_no_process():
    calc_item = (ROOT / "modules" / "launcher" / "items" / "CalcItem.qml").read_text()
    assert "Calc.evaluate" in calc_item
    assert "Qalculator" not in calc_item, "launcher calc must not use libqalculate"
    parser = (SERVICES / "calcparser.js").read_text()
    assert "eval(" not in parser and "Function(" not in parser
    assert "Process {" not in (SERVICES / "Calc.qml").read_text()


def test_calc_parser_arithmetic():
    out = _run_js(SERVICES / "calcparser.js", """
const cases = ["2+3*4", "(2+3)*4", "10%3", "-5+3", "0.1+0.2", "2*-3", "((8))", "7/2"];
console.log(JSON.stringify(cases.map(c => evaluate(c))));
""")
    assert [r["text"] for r in out] == ["14", "20", "1", "-2", "0.3", "-6", "8", "3.5"]
    assert all(r["ok"] for r in out)


def test_calc_parser_malformed_and_div_zero():
    out = _run_js(SERVICES / "calcparser.js", """
const cases = ["1/0", "1%0", "2+", "2..3", "abc", "", "((1)", "1 2", "sqrt(4)", "9".repeat(400)];
console.log(JSON.stringify(cases.map(c => evaluate(c).ok)));
""")
    assert out == [False] * 10, out


def test_calc_bare_expression_gate():
    out = _run_js(SERVICES / "calcparser.js", """
console.log(JSON.stringify(["2+3", "42", "firefox", "2+", "(1+2)"].map(c => looksLikeExpression(c))));
""")
    assert out == [True, False, False, False, True]
    # The gate exists but bare routing is deliberately off (docs).
    assert 'return "apps";' in APPLIST


# --- Windows provider ----------------------------------------------------

def test_windows_provider_fixture_data():
    out = _run_js(SERVICES / "windowfilter.js", """
const rows = [
  { title: "Terminal — fish", appClass: "kitty", workspaceName: "1", address: "a1" },
  { title: "GitHub — PRs", appClass: "firefox", workspaceName: "2", address: "b2" },
  { title: "Notes", appClass: "kitty", workspaceName: "1", address: "c3" }
];
console.log(JSON.stringify({
  all: filterWindows(rows, "").map(r => r.address),
  byTitle: filterWindows(rows, "git").map(r => r.address),
  byClass: filterWindows(rows, "KITTY").map(r => r.address),
  none: filterWindows(rows, "zzz")
}));
""")
    assert out == {
        "all": ["a1", "b2", "c3"],  # compositor order preserved
        "byTitle": ["b2"],
        "byClass": ["a1", "c3"],
        "none": [],
    }


def test_windows_activation_uses_existing_hypr_path():
    windows = (SERVICES / "Windows.qml").read_text()
    assert "Hypr.dispatch(`focuswindow address:0x${result.address}`)" in windows
    assert "horneroctl" not in windows and "Process {" not in windows
    item = (ROOT / "modules" / "launcher" / "items" / "WindowItem.qml").read_text()
    assert "Windows.activate(root.modelData)" in item


# --- Keyboard / focus regression ------------------------------------------

def test_keyboard_and_escape_contracts_untouched():
    content = (ROOT / "modules" / "launcher" / "Content.qml").read_text()
    assert "Keys.onUpPressed: list.currentList?.decrementCurrentIndex()" in content
    assert "Keys.onDownPressed: list.currentList?.incrementCurrentIndex()" in content
    assert "onAccepted" in content
    # No provider adds its own Escape handling; cascade stays central.
    for name in ("CalcItem.qml", "WindowItem.qml"):
        src = (ROOT / "modules" / "launcher" / "items" / name).read_text()
        assert "Escape" not in src, name

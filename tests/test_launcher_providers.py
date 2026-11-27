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
    assert "routeTokens(p).includes(token)" in PROVIDERS, "duplicate route token not rejected"
    assert "typeof spec.query !== \"function\"" in PROVIDERS


def test_registry_supports_alias_routes_and_bare_prefixes():
    assert "function normalizedAliases(spec" in PROVIDERS
    assert "function routeTokens(provider" in PROVIDERS
    assert "function routeFor(text" in PROVIDERS
    # A token matches before a space and at end-of-string, so the bare
    # route enters its state before the separator is typed.
    assert "text === route || text.startsWith(`${route} `)" in PROVIDERS
    # Query stripping uses the matched token, not the canonical prefix.
    assert "route.token.length" in PROVIDERS
    # Files answers to both singular and plural spellings.
    assert '\"aliases\": ["files"]' in PROVIDERS


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


def test_plugin_providers_hosted_by_launcher_host():
    # Superseded by the follow-up slice: PluginLauncherHost hosts
    # surfaces.launcher into this registry (see
    # test_plugin_launcher_providers.py for the full contract).
    assert "PluginLauncherHost" in PROVIDERS and "surfaces.launcher" in PROVIDERS
    docs = (ROOT / "docs" / "LAUNCHER.md").read_text()
    assert "Plugin-defined providers" in docs
    assert "unsandboxed" in docs, "plugin trust wording missing"
    host = (ROOT / "modules" / "plugins" / "PluginHost.qml").read_text()
    assert "PluginLauncherHost" in host, "PluginHost must point at the launcher host"


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
console.log(JSON.stringify(["2+3", "42", "firefox", "2+", "(1+2)", "10 km to mi"].map(c => looksLikeExpression(c))));
""")
    assert out == [True, False, False, False, True, True]
    # The gate exists but bare routing is deliberately off (docs).
    assert 'return "apps";' in APPLIST


def test_calc_parser_unit_conversions():
    out = _run_js(SERVICES / "calcparser.js", """
const cases = [
    "100 c to f",
    "32 f in c",
    "0 c to k",
    "2 gb to mb",
    "1024 mb to gb",
    "1 km to m",
    "1 kg to g",
    "2 h to min",
    "(1+1) gb to mb",
    "10 km to kg",
    "10 foo to bar"
];
console.log(JSON.stringify(cases.map(c => evaluate(c))));
""")
    assert out[0]["ok"] and out[0]["text"] == "212 °F"
    assert out[1]["ok"] and out[1]["text"] == "0 °C"
    assert out[2]["ok"] and out[2]["text"] == "273.15 K"
    assert out[3]["ok"] and out[3]["text"] == "2048 MB"
    assert out[4]["ok"] and out[4]["text"] == "1 GB"
    assert out[5]["ok"] and out[5]["text"] == "1000 m"
    assert out[6]["ok"] and out[6]["text"] == "1000 g"
    assert out[7]["ok"] and out[7]["text"] == "120 min"
    assert out[8]["ok"] and out[8]["text"] == "2048 MB"
    assert not out[9]["ok"], "cross-category conversion must fail"
    assert not out[10]["ok"], "unknown unit conversion must fail"


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


def test_windows_activation_uses_compositor_path():
    windows = (SERVICES / "Windows.qml").read_text()
    assert "Compositor.allWindowSummaries()" in windows
    assert "Compositor.focusWindow(" in windows
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

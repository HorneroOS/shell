"""Extension store in Control Center (competitive gap #4).

services/extensionstore.js is executed under node (argv per verb, consent,
guidance per horneroctl error code, permission lines, honest cost,
screenshot sources). The service and pane are checked as static source
contracts in the repo style: one verb at a time, every verb behind a
two-step guard, no Apply button, no network image fetch, user controls
persisted in the shell config.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "extensionstore.js"
STORE = (ROOT / "services" / "ExtensionStore.qml").read_text(encoding="utf-8")
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text(encoding="utf-8")
CONFIG = (ROOT / "config" / "PluginsConfig.qml").read_text(encoding="utf-8")
SERIALIZER = (ROOT / "config" / "Config.qml").read_text(encoding="utf-8")
FACTORY = json.loads((ROOT / "config" / "shell.default.json").read_text(encoding="utf-8"))
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text(encoding="utf-8")
SERVICE = (ROOT / "services/Plugins.qml").read_text(encoding="utf-8")
DOCS = (ROOT / "docs" / "PLUGINS.md").read_text(encoding="utf-8")
REV = "0123456789abcdef0123456789abcdef01234567"


def run_js(expr: str, data=None):
    node = shutil.which("node")
    if not node:
        pytest.skip("node is required to execute services/extensionstore.js")
    src = JS.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconst D=" + json.dumps(data or {}) + ";console.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)


# --- argv: the documented horneroctl verbs, nothing else ---------------

def test_catalogue_verbs_pin_the_displayed_revision():
    assert run_js(f'return commandFor("install", "hornero-pomodoro", "{REV}");') == [
        "horneroctl", "--json", "plugin", "catalog", "install", "hornero-pomodoro", "--revision", REV, "--yes"]
    assert run_js(f'return commandFor("update", "hornero-pomodoro", "{REV}");')[-3:] == ["--revision", REV, "--yes"]


def test_rollback_and_lifecycle_verbs_take_no_revision():
    assert run_js(f'return commandFor("rollback", "hornero-pomodoro", "{REV}");') == [
        "horneroctl", "--json", "plugin", "catalog", "rollback", "hornero-pomodoro", "--yes"]
    for verb in ("remove", "enable", "disable", "trust"):
        assert run_js(f'return commandFor("{verb}", "hornero-x", "{REV}");') == [
            "horneroctl", "--json", "plugin", verb, "hornero-x", "--yes"]


@pytest.mark.parametrize("verb,pid", [
    ("install-local", "hornero-x"), ("install", "Bad Id"), ("remove", "../x"),
    ("remove", "x-"), ("remove", ""), ("install", "a" * 49)])
def test_unknown_verbs_and_bad_ids_build_nothing(verb, pid):
    assert run_js(f"return commandFor({json.dumps(verb)}, {json.dumps(pid)}, '');") == []


def test_a_short_revision_is_never_passed():
    assert "--revision" not in run_js('return commandFor("install", "hornero-x", "abc");')


# --- envelopes and error codes -----------------------------------------

def test_envelope_parsing_uses_the_stable_error_code():
    env = run_js('return parseEnvelope(D.t, 1);', {"t": json.dumps({
        "command": "plugin catalog install", "ok": False,
        "message": "catalogue changed since it was displayed", "data": {"error": "catalogue-changed"}})})
    assert env == {"ok": False, "message": "catalogue changed since it was displayed",
                   "code": "catalogue-changed", "data": {"error": "catalogue-changed"}}
    assert "Refresh" in run_js('return guidance("catalogue-changed", false);')
    assert "Actualizalo" in run_js('return guidance("catalogue-changed", true);')


def test_garbage_or_nonzero_exit_is_a_failure():
    assert run_js('return parseEnvelope("not json", 0);')["code"] == "no-output"
    ok_but_failed = run_js('return parseEnvelope(D.t, 1);', {"t": json.dumps({"ok": True, "message": "x", "data": {}})})
    assert ok_but_failed["ok"] is False


def test_every_documented_code_has_guidance_in_both_languages():
    codes = ["catalogue-changed", "catalogue-unavailable", "hash-mismatch", "validation-failed",
             "already-installed", "not-installed", "locally-modified", "not-catalogue-source",
             "nothing-to-roll-back", "trust-required", "not-in-catalogue", "unsafe-path",
             "receipt-invalid", "payload-missing", "io-failed"]
    got = run_js("return D.c.map(c => [guidance(c, false), guidance(c, true)]);", {"c": codes})
    for code, (en, es) in zip(codes, got):
        assert en and es and en != es, code


# --- what a row says ----------------------------------------------------

def test_update_state_and_text():
    row = {"id": "x", "version": "2.0.0", "state": "installed", "installed_version": "1.0.0", "update_available": True}
    assert run_js("return rowState(D.r, null);", {"r": row}) == "update"
    assert run_js("return updateText(D.r, false);", {"r": row}) == "Update available: 1.0.0 → 2.0.0"
    assert run_js("return rowState(D.r, null);", {"r": {"state": "available"}}) == "available"
    assert run_js("return rowState(D.r, {});", {"r": {"state": "available"}}) == "installed"


def test_signer_text_is_specific():
    assert "HorneroOS/plugins" in run_js('return signerText({signer: "HorneroOS/plugins (official catalogue)"}, false);')
    assert "0807060504030201" in run_js('return signerText({signer: "author key 0807060504030201", trust: "signed"}, false);')
    assert "Nobody" in run_js('return signerText({trust: "untrusted"}, false);')
    assert "inválida" in run_js('return signerText({trust: "bad-signature"}, true);')


def test_permission_lines_prefer_curated_catalogue_text():
    entry = {"permissions": [{"kind": "program", "value": "gh", "en": "Runs gh.", "es": "Ejecuta gh."}],
             "capabilities": {"processCommands": ["gh"]}}
    assert run_js("return permissionLines(D.e, true);", {"e": entry}) == [{"kind": "program", "value": "gh", "text": "Ejecuta gh."}]
    derived = run_js("return permissionLines(D.e, false);", {"e": {"capabilities": {
        "processCommands": ["git"], "networkHosts": ["api.github.com"], "providers": ["system"],
        "settings": {"b": {}, "a": {}}}}})
    assert [l["kind"] for l in derived] == ["program", "network", "data", "settings"]
    assert derived[-1]["value"] == "a, b"
    assert run_js("return hasProgramsOrNetwork(D.e);", {"e": entry}) is True


def test_consent_text_states_what_each_verb_does():
    e = {"name": "Pomodoro"}
    install = run_js("return consentText('install', D.e, false);", {"e": e})
    assert "does not run them" in install and "no sandbox" in install
    assert "settings are kept" in run_js("return consentText('remove', D.e, false);", {"e": e})
    assert "sin sandbox" in run_js("return consentText('enable', D.e, true);", {"e": e})


# --- cost: measured or explicitly not measured --------------------------

def test_cost_uses_measured_provider_samples_and_splits_shared_leases():
    tele = {"system": {"leases": 2, "intervalMs": 2000, "samples": 10, "meanMs": 0.4},
            "time": {"leases": 3, "intervalMs": 0, "samples": 0, "meanMs": 0}}
    c = run_js("return costSummary(D.e, D.t);", {"e": {"loadMs": 42, "capabilities": {"providers": ["system", "time"]}}, "t": tele})
    assert c["loadMs"] == 42
    assert c["providers"][0]["corePercent"] == pytest.approx(0.4 / 2000 * 100 / 2)
    assert c["providers"][1]["measured"] is False
    assert c["memory"] is None
    text = run_js("return costText(D.e, D.t, false);", {"e": {"loadMs": 42, "capabilities": {"providers": ["system"]}}, "t": tele})
    assert "Load: 42 ms" in text and "shared by 2" in text
    assert "not measured per extension" in text


def test_cost_never_invents_numbers():
    c = run_js("return costSummary({}, {});")
    assert c == {"loadMs": None, "providers": [], "corePercent": None, "memory": None}
    assert "not measured" in run_js("return costText({}, {}, false);")


# --- screenshots: local verified files only ----------------------------

def test_screenshots_are_local_cached_files_never_urls():
    row = {"id": "x", "name": "X", "screenshot_files": [
        {"file": "/home/u/.cache/hornero/plugins/catalog-screenshots/ab.png", "alt": "X"},
        {"file": "https://evil.example/x.png"}, {"file": "/a/../b.png"}]}
    got = run_js("return screenshotSources(D.r, '/p', false);", {"r": row})
    assert got == [{"source": "file:///home/u/.cache/hornero/plugins/catalog-screenshots/ab.png", "alt": "X"}]
    packaged = {"id": "x", "marketplace": {"screenshots": [{"path": "previews/a.png"}, {"path": "../a.png"}]}}
    assert run_js("return screenshotSources(D.r, '/p', true);", {"r": packaged}) == [
        {"source": "file:///p/x/previews/a.png", "alt": "x"}]
    assert run_js("return screenshotSources(D.r, '/p', false);", {"r": packaged}) == []


def test_progress_line_names_real_steps_without_a_percentage():
    line = run_js("return progressText('install', 'Pomodoro', 3.7, false);")
    assert line.startswith("Installing Pomodoro…") and "verifying SHA-256" in line and line.endswith("3 s")
    assert "%" not in line


# --- service and pane contracts ----------------------------------------

def test_store_runs_one_verb_at_a_time_and_rereads_state():
    run = STORE.split("function run(", 1)[1].split("function progressText", 1)[0]
    assert "if (root.busy)\n            return false;" in run
    assert "root.catalogueRevision.length === 0" in run  # no unpinned install/update
    finished = STORE.split("id: jobProc", 1)[1]
    assert "Plugins.reload();" in finished and "root.refreshCatalogue();" in finished
    assert "StdioCollector" in STORE  # whole stdout, not line-split JSON


def test_every_mutating_verb_keeps_a_two_step_guard():
    for first, confirm in (("Install…", "Confirm install"), ("Update…", "Confirm update"),
                           ("Roll back…", "Confirm rollback"), ("Remove…", "Confirm remove"),
                           ("Enable…", "Confirm enable"), ("Trust…", "Confirm trust")):
        assert f'qsTr("{first}")' in PANE and f'qsTr("{confirm}")' in PANE, first
    # Runs only from the confirming click.
    for call in re.findall(r"root\.run(?:CatalogAction|Lifecycle)\(\"(\w+)\"", PANE):
        assert call in {"install", "update", "rollback", "remove", "enable", "disable", "trust"}
    assert 'qsTr("Apply' not in PANE


def test_consent_and_results_are_inline_on_the_card():
    assert PANE.count("Store.consentText(verb,") == 2
    assert PANE.count("root.outcomeText(") >= 4
    assert "StoreProgress {" in PANE and "Accessible.role: Accessible.StatusBar" in PANE
    assert "Store.signerText(row.entry, root.es)" in PANE and "Store.signerText(catRow.modelData, root.es)" in PANE
    assert "Store.costText(row.entry, Plugins.providerTelemetry, root.es)" in PANE
    assert "Store.changelog(catRow.modelData" in PANE and "Store.permissionLines(catRow.modelData" in PANE


def test_pane_never_fetches_images_or_runs_processes():
    assert "Process {" not in PANE
    assert "http" not in PANE.split("Store.screenshotSources", 1)[1].split("}", 1)[0]
    assert "AnimatedImage" not in PANE


def test_telemetry_is_only_sampled_while_the_pane_watches():
    assert "property int telemetryWatchers: 0" in SERVICE
    timer = HOST.split("running: Plugins.telemetryWatchers > 0", 1)[1][:300]
    assert "Plugins.providerTelemetry = root.providerTelemetry()" in timer
    assert "Plugins.telemetryWatchers += 1" in PANE
    assert "Plugins.telemetryWatchers = Math.max(0, Plugins.telemetryWatchers - 1)" in PANE


def test_store_preferences_are_persisted_validated_and_exposed():
    for key, default in (("storeRefreshOnOpen", True), ("storeShowCost", True), ("storeLanguage", "auto")):
        assert FACTORY["plugins"][key] == default
        assert f"{key}: plugins.{key}" in SERIALIZER
        assert f'setStoreOption("{key}"' in PANE
    assert 'readonly property var allowedStoreLanguages: ["auto", "en", "es"]' in CONFIG
    setter = CONFIG.split("function setStoreOption", 1)[1].split("function storeSpanish", 1)[0]
    assert "typeof value !== \"boolean\"" in setter and "allowedStoreLanguages.includes(value)" in setter
    assert "if (Config.plugins.storeRefreshOnOpen" in PANE


def test_docs_describe_the_store():
    flat = " ".join(DOCS.split())
    for needle in ("Managing extensions from Control Center", "Confirm remove", "data.error",
                   "storeRefreshOnOpen", "not measured per extension"):
        assert needle in flat, needle


def test_qml_list_likes_are_accepted():
    # Repeater modelData turns arrays into QVariantList, for which
    # Array.isArray is false; the pane showed no permissions, screenshots
    # or changelog until the store accepted list-likes (offscreen run).
    got = run_js("""
        const like = (a) => { const o = {length: a.length}; a.forEach((v, i) => o[i] = v); return o; };
        const e = {id: "x", name: "X",
            permissions: like([{kind: "program", value: "date", en: "Runs date.", es: "Ejecuta date."}]),
            screenshot_files: like([{file: "/c/a.png", alt: "A"}]),
            marketplace: {changelog: like([{version: "1.0.0", notes: "First."}])},
            capabilities: {providers: like(["time"])}};
        return [permissionLines(e, false).length, screenshotSources(e, "/p", false).length,
                changelog(e, 5).length, costSummary(e, {}).providers.length];""")
    assert got == [1, 1, 1, 1]

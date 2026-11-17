"""Customisation overview: changed-from-default list and reset-all scope."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "customisation.js"
CC = ROOT / "modules" / "controlcenter"
FACTORY = json.loads((ROOT / "config" / "shell.default.json").read_text())


def run_js(expr: str, data: dict):
    node = shutil.which("node")
    assert node, "node is required to execute services/customisation.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconst D=" + json.dumps(data) + ";console.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)


def test_factory_has_no_changes():
    assert run_js("return changed(D.f, D.f);", {"f": FACTORY}) == []


def test_changed_lists_label_pane_and_values():
    cur = json.loads(json.dumps(FACTORY))
    cur["appearance"]["rounding"]["scale"] = 1.6
    cur["launcher"]["sizes"]["itemWidth"] = 700
    got = run_js("return changed(D.c, D.f);", {"c": cur, "f": FACTORY})
    by = {g["path"]: g for g in got}
    r = by["appearance.rounding.scale"]
    assert (r["current"], r["factory"], r["pane"]) == (1.6, 1, "appearance")
    assert r["label"] == "Appearance › Rounding › Scale"
    l = by["launcher.sizes.itemWidth"]
    assert (l["pane"], l["current"], l["factory"]) == ("launcher", 700, 640)
    assert len(got) == 2


def test_user_data_is_never_listed_or_reset():
    cur = json.loads(json.dumps(FACTORY))
    cur["launcher"]["favouriteApps"] = ["firefox"]
    cur["launcher"]["hiddenApps"] = ["x"]
    cur["general"]["apps"]["terminal"] = ["foot"]
    cur["bar"]["bars"] = []
    cur["paths"] = {"wallpaperDir": "/x"}
    assert run_js("return changed(D.c, D.f);", {"c": cur, "f": FACTORY}) == []


def test_filter_matches_all_words():
    items = [{"label": "Appearance › Glow › Intensity", "path": "appearance.glow.intensity"},
             {"label": "Launcher › Sizes › Item width", "path": "launcher.sizes.itemWidth"}]
    assert len(run_js("return filter(D.i, 'glow int');", {"i": items})) == 1
    assert len(run_js("return filter(D.i, '');", {"i": items})) == 2
    assert run_js("return filter(D.i, 'nothing');", {"i": items}) == []


def test_every_customisation_section_exists_in_factory():
    secs = run_js("return SECTIONS;", {})
    for s in secs:
        assert s in FACTORY, s


def test_pane_registered_and_wired():
    reg = (CC / "PaneRegistry.qml").read_text()
    assert 'readonly property string id: "customisation"' in reg
    assert '"customisation/CustomisationPane.qml"' in reg
    src = (CC / "customisation" / "CustomisationPane.qml").read_text()
    assert "Customisation.changed(" in src and "Reset all" in src
    assert "Config.serializeConfig()" in src
    assert 'paneId: "customisation"' in src


def test_pack_roundtrip_and_validation():
    cur = json.loads(json.dumps(FACTORY))
    cur["appearance"]["rounding"]["scale"] = 1.6
    cur["launcher"]["sizes"]["itemWidth"] = 700
    pack = run_js("return exportPack(D.c, D.f, 'Cozy');", {"c": cur, "f": FACTORY})
    assert pack["schema"] == "hornero/look-pack@1" and pack["name"] == "Cozy"
    assert pack["values"] == {"appearance.rounding.scale": 1.6, "launcher.sizes.itemWidth": 700}
    r = run_js("return validatePack(D.p, D.f);", {"p": pack, "f": FACTORY})
    assert len(r["accepted"]) == 2 and r["rejected"] == []


def test_pack_rejects_bad_entries_and_clamps():
    pack = {"schema": "hornero/look-pack@1", "values": {
        "appearance.rounding.scale": 9999,          # clamped to 10x factory
        "appearance.reducedMotion": "yes",           # wrong type
        "launcher.favouriteApps": ["x"],             # user data
        "general.apps.terminal": ["foot"],           # not customisation
        "nope.nothing": 1,                           # unknown
    }}
    r = run_js("return validatePack(D.p, D.f);", {"p": pack, "f": FACTORY})
    assert [a["path"] for a in r["accepted"]] == ["appearance.rounding.scale"]
    assert r["accepted"][0]["value"] == 10
    assert sorted(x["path"] for x in r["rejected"]) == ["appearance.reducedMotion", "general.apps.terminal", "launcher.favouriteApps", "nope.nothing"]
    bad = run_js("return validatePack({schema:'other'}, D.f);", {"f": FACTORY})
    assert bad["accepted"] == [] and bad["rejected"][0]["reason"] == "not a Hornero look pack"

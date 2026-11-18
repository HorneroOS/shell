"""services/chromaticcli.js: request normalisation, argv construction and
helper-document parsing (executed under node)."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "chromaticcli.js"
FIXTURE = ROOT / "tests" / "fixtures" / "chromatic" / "generate-amber.json"


def run_js(expr: str):
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([shutil.which("node"), "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_variants_are_the_eight_of_rfc_0002_with_honest_text():
    out = run_js("return VARIANTS.map(v => v.id)")
    assert out == ["balanced", "vibrant", "expressive", "faithful", "muted", "monochrome", "high-contrast", "neon"]
    desc = run_js("return Object.fromEntries(VARIANTS.map(v => [v.id, v.description]))")
    assert "Dark only" in desc["neon"] and "Never chosen automatically" in desc["neon"]
    assert "not the accessibility switch" in desc["high-contrast"]
    assert "No glow" in desc["high-contrast"] or "no glow" in desc["high-contrast"]


def test_normalise_clamps_everything():
    out = run_js("return normalise({source: 'bogus', seeds: ['#abcdef', 'nope', '#123456', '#FFFFFF'], variant: 'wat', mode: 'x',"
                 " contrast: 'y', surfaceDepth: 'z', chroma: 9, hueShift: -999}, 'light')")
    assert out["source"] == "wallpaper" and out["seeds"] == ["#ABCDEF", "#123456"]
    assert out["variant"] == "auto" and out["mode"] == "auto" and out["contrast"] == "standard"
    assert out["chroma"] == 1.5 and out["hueShift"] == -180 and out["currentMode"] == "light"


def test_normalise_keeps_seeds_from_a_config_sequence():
    # Config.appearance.chromatic.seeds loaded from shell.json is a Qt
    # sequence (array-like, Array.isArray false). Dropping it turned a saved
    # "Colour" source into "Choose an accent colour" with no previews.
    out = run_js("return normalise({source: 'seed', seeds: {length: 2, 0: '#d98a3a', 1: '#3A7FD9'}}, 'dark')")
    assert out["source"] == "seed" and out["seeds"] == ["#D98A3A", "#3A7FD9"]
    # a bare string is not a list of seeds
    assert run_js("return normalise({source: 'seed', seeds: '#D98A3A'}, 'dark').seeds") == []
    seed = run_js("return engineRequest(normalise({source: 'seed', seeds: {length: 1, 0: '#D98A3A'}}, 'dark'), '', null)")
    assert seed and seed["seeds"] == ["#D98A3A"]


def test_helper_args_per_source():
    wall = run_js("return helperArgs(normalise({source: 'wallpaper'}, 'dark'), '/w/a.jpg', null)")
    assert wall[:3] == ["generate", "--source", "/w/a.jpg"] and wall[-2:] == ["--current-mode", "dark"]
    assert "--yes" not in wall
    assert run_js("return helperArgs(normalise({source: 'wallpaper'}, 'dark'), '', null)") is None
    seed = run_js("return helperArgs(normalise({source: 'seed', seeds: ['#D98A3A', '#3A7FD9']}, 'dark'), '', null)")
    assert seed.count("--seed") == 2
    assert run_js("return helperArgs(normalise({source: 'seed'}, 'dark'), '', null)") is None
    house = run_js("return helperArgs(normalise({source: 'house'}, 'dark'), '/w/a.jpg', null)")
    assert house[1] == "--house" and house[2:4] == ["--wallpaper", "/w/a.jpg"]
    img = run_js("return helperArgs(normalise({source: 'image', path: '/i.png'}, 'dark'), '/w/a.jpg', null)")
    assert img[1:3] == ["--source", "/i.png"]


def test_per_mode_preference_only_applies_to_auto_variant():
    pm = "{dark: {variant: 'vibrant'}, light: {variant: 'muted'}}"
    out = run_js("const pm = " + pm + "; return [effectiveVariant(normalise({variant: 'auto', mode: 'light'}, 'dark'), pm),"
                 " effectiveVariant(normalise({variant: 'auto'}, 'dark'), pm), effectiveVariant(normalise({variant: 'neon'}, 'dark'), pm)]")
    assert out == ["muted", "vibrant", "neon"]


def test_apply_goes_to_horneroctl_with_yes_last():
    a = run_js("return applyArgs(normalise({source: 'image', path: '/i.png', variant: 'vibrant'}, 'dark'), null, true)")
    assert a[:4] == ["horneroctl", "appearance", "chromatic", "apply"]
    assert "image:/i.png" in a and a[-2:] == ["--json", "--yes"] and "--no-persist" not in a
    once = run_js("return applyArgs(normalise({}, 'dark'), null, false)")
    assert "--no-persist" in once and once[-2:] == ["--json", "--yes"]
    for verb in ("saveArgs('a','A')", "importArgs('/f.json','')", "rollbackArgs()", "offArgs()", "followArgs()"):
        v = run_js(f"return {verb}")
        assert v[0] == "horneroctl" and v[-1] == "--yes", verb
    assert run_js("return exportArgs('/f.json')")[-1] == "--json"


def test_slug_is_kebab_and_never_the_reserved_id():
    assert run_js("return slug('  Dusk over Bahía!  ')") == "dusk-over-bah-a"
    assert run_js("return slug('hornero chromatic')") == "hornero-chromatic-1"
    assert run_js("return slug('???')") == ""


@pytest.mark.parametrize("code,video,expect", [(3, False, "source-unreadable"), (3, True, "video-needs-ffmpeg"), (4, False, "gates-unreachable"), (2, False, "usage"), (5, False, "internal")])
def test_failure_descriptions(code, video, expect):
    out = run_js(f"return describeFailure({code}, 'boom', false, {str(video).lower()})")
    assert out["code"] == expect and out["title"] and out["detail"]
    assert "ffmpeg" in out["detail"] if expect == "video-needs-ffmpeg" else True


def test_missing_helper_says_how_to_fix_it():
    out = run_js("return describeFailure(0, '', true, false)")
    assert out["code"] == "engine-missing" and "hornero-shell" in out["detail"] and "unchanged" in out["detail"]


def test_video_paths_are_detected():
    assert run_js("return [isVideoPath('/a/b.MP4'), isVideoPath('/a/b.png'), isVideoPath('')]") == [True, False, False]


def test_parse_generate_accepts_the_fixture_and_rejects_partial_documents():
    text = FIXTURE.read_text()
    ok = run_js(f"return parseGenerate({json.dumps(text)})")
    assert ok["ok"] and ok["result"]["scheme"]["id"] == "hornero-chromatic"
    assert ok["result"]["gates"]["rows"] and all("pass" in r for r in ok["result"]["gates"]["rows"])
    assert run_js("return parseGenerate('not json').ok") is False
    assert run_js("return parseGenerate('{\"schemaVersion\":1}').ok") is False


def test_inference_rows_flag_overrides():
    inf = {"mode": "dark", "variant": "balanced", "contrast": "standard"}
    rows = run_js("return inferenceRows(" + json.dumps(inf) + ", normalise({mode: 'light', variant: 'auto'}, 'dark'))")
    by = {r["key"]: r for r in rows}
    assert by["mode"]["overridden"] is True and by["variant"]["overridden"] is False


def test_engine_request_carries_the_rfc_keys_and_path():
    out = run_js("return engineRequest(normalise({source: 'wallpaper', variant: 'vibrant', chroma: 1.2, hueShift: 10}, 'light'), '/w/a.jpg', null)")
    assert out["path"] == "/w/a.jpg" and out["variant"] == "vibrant" and out["currentMode"] == "light"
    assert set(out) >= {"source", "seeds", "mode", "contrast", "surfaceDepth", "chroma", "hueShift"}
    assert run_js("return engineRequest(normalise({source: 'wallpaper'}, 'dark'), '', null)") is None
    assert run_js("return engineRequest(normalise({source: 'seed', seeds: ['#D98A3A']}, 'dark'), '', null).path") == ""


def test_engine_failure_codes_map_to_helper_exit_codes():
    assert run_js("return ['source-unreadable', 'usage', 'internal', 'other'].map(engineFailureExit)") == [3, 2, 5, 5]


def test_parse_document_accepts_an_object_like_the_in_process_result():
    doc = json.loads(FIXTURE.read_text())
    assert run_js("return parseDocument(%s).ok" % json.dumps(doc)) is True
    assert run_js("return parseDocument(null).ok") is False

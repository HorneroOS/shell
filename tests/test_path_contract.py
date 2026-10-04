"""The shell has one canonical Hornero namespace for persisted state."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATHS = ROOT / "utils" / "Paths.qml"


def test_paths_use_xdg_hornero_roots():
    text = PATHS.read_text()
    for root in ("`${dataHome}/hornero`", "`${stateHome}/hornero`", "`${cacheHome}/hornero`"):
        assert root in text
    for env in ("XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_CONFIG_HOME",
                "HORNERO_WALLPAPERS_DIR", "HORNERO_RECORDINGS_DIR", "HORNERO_LIB_DIR"):
        assert env in text
    assert '"DOTS_' not in text
    assert "/dots" not in text


def test_no_hardcoded_home_in_qml():
    hits = []
    for dirname in ("modules", "services", "config", "utils", "components"):
        for path in (ROOT / dirname).rglob("*.qml"):
            if "/home/" in path.read_text():
                hits.append(str(path.relative_to(ROOT)))
    assert not hits, f"hardcoded /home/ literals in: {hits}"


def test_presets_installed_by_cmake():
    cmake = (ROOT / "CMakeLists.txt").read_text()
    assert "presets" in cmake
    assert len(list((ROOT / "presets").glob("*.json"))) == 15


def test_shell_appearance_uses_native_hornero_contracts():
    pipeline = (ROOT / "services" / "ThemePipeline.qml").read_text()
    assert '"horneroctl", "appearance", "theme", "list", "--full"' in (
        ROOT / "services" / "ThemeCatalogue.qml").read_text()
    assert "ThemeCatalogue.themeById(job.themeId)" in pipeline
    assert "Fallback" not in pipeline


def test_no_retired_namespace_in_runtime_qml():
    hits = []
    for dirname in ("modules", "services", "config", "utils", "components"):
        for path in (ROOT / dirname).rglob("*.qml"):
            content = path.read_text()
            if "DOTS_" in content or "/dots/" in content:
                hits.append(str(path.relative_to(ROOT)))
    assert not hits, f"retired namespace remains in runtime QML: {hits}"

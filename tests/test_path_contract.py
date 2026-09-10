"""Path contract: utils/Paths.qml must expose env-override-first resolution
with XDG/$HOME fallbacks, and QML must not hardcode /home/ literals."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATHS = ROOT / "utils" / "Paths.qml"

REQUIRED_PROPS = [
    "wallpaperPointer", "imagecache", "wallsdir", "recsdir", "libdir",
    "data", "state", "cache", "config",
]
REQUIRED_ENVS = [
    "DOTS_DATA_DIR", "DOTS_STATE_DIR", "DOTS_CACHE_DIR", "DOTS_CONFIG_DIR",
    "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_CONFIG_HOME",
    "HORNERO_WALLPAPERS_DIR", "HORNERO_RECORDINGS_DIR", "HORNERO_LIB_DIR",
]


def test_paths_singleton_contract():
    text = PATHS.read_text()
    for prop in REQUIRED_PROPS:
        assert prop in text, f"Paths.qml missing property {prop}"
    for env in REQUIRED_ENVS:
        assert env in text, f"Paths.qml missing env override {env}"


def test_no_hardcoded_home_in_qml():
    hits = []
    for dirname in ("modules", "services", "config", "utils", "components"):
        for path in (ROOT / dirname).rglob("*.qml"):
            if "/home/" in path.read_text():
                hits.append(str(path.relative_to(ROOT)))
    assert not hits, f"hardcoded /home/ literals in: {hits}"


def test_presets_installed_by_cmake():
    cmake = (ROOT / "CMakeLists.txt").read_text()
    assert "presets" in cmake, "CMakeLists.txt must install presets/"
    assert (ROOT / "presets").is_dir()
    assert len(list((ROOT / "presets").glob("*.json"))) == 11

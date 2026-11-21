"""Cava is decorative: a broken/missing libcava must not kill the shell.

Regression: sndio 1.11 bumped libsndio.so.7 -> .9; the AUR/Chaotic
libcava built against .7 then failed to load, the Hornero.Services
plugin (which hard-linked libcava) failed with it, and the whole
shell aborted at startup. The plugin must resolve cava at runtime
and degrade to a silent spectrum when it cannot.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICES = ROOT / "plugin/src/Hornero/Services"


def test_plugin_does_not_link_libcava():
    services_cmake = (SERVICES / "CMakeLists.txt").read_text()
    hornero_cmake = (ROOT / "plugin/src/Hornero/CMakeLists.txt").read_text()
    assert "PkgConfig::Cava" not in services_cmake
    assert "PkgConfig::Cava" not in hornero_cmake
    assert "pkg_check_modules(Cava" not in hornero_cmake


def test_cava_loaded_at_runtime_and_degrades_to_silence():
    cpp = (SERVICES / "cavaprovider.cpp").read_text()
    hpp = (SERVICES / "cavaprovider.hpp").read_text()
    # No link-time header: the ABI is resolved via QLibrary at runtime.
    assert "cava/cavacore.h" not in hpp
    assert "QLibrary" in cpp
    for symbol in ("cava_init", "cava_execute", "cava_destroy"):
        assert f'"{symbol}"' in cpp, symbol
    # Unavailable cava leaves no plan; process() already returns early
    # on a null plan, so values stay at zero instead of failing to load.
    assert "m_plan" in cpp and "if (!m_plan" in cpp


def test_packaging_does_not_require_libcava():
    pkgbuild = (ROOT / "packaging/PKGBUILD").read_text()
    depends_block = pkgbuild.split("depends=(")[1].split(")")[0]
    assert "'libcava'" not in depends_block
    optdepends_block = pkgbuild.split("optdepends=(")[1].split(")")[0]
    assert "libcava" in optdepends_block

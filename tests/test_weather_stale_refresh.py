"""Opening the Weather views must not wipe a good forecast (shell#553)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _src(rel: str) -> str:
    return (ROOT / rel).read_text()


def test_views_refresh_only_when_stale():
    for rel in ("modules/dashboard/Weather.qml", "modules/dashboard/dash/Weather.qml"):
        src = _src(rel)
        assert "Component.onCompleted: Weather.refreshIfStale()" in src
        assert "Weather.reload()" not in src


def test_service_keeps_data_while_refreshing():
    src = _src("services/Weather.qml")
    assert "function refreshIfStale()" in src
    assert "lastFetchMs = Date.now();" in src
    assert "readonly property int freshMs" in src
    # reload() is the only place that clears the forecast
    refresh = src.split("function refreshIfStale()")[1].split("function fetchWeatherData")[0]
    assert "forecast = []" not in refresh and "cc = null" not in refresh


def test_loading_state_only_without_data():
    src = _src("modules/dashboard/Weather.qml")
    assert "!Weather.ready && (Weather.loading" in src

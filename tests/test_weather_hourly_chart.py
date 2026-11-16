"""Weather tab: hourly temperature chart, 7-day forecast always shown, and
a quiet attribution footer (themed links; Qt ignores linkColor for Markdown).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TAB = (ROOT / "modules/dashboard/Weather.qml").read_text(encoding="utf-8")
CHART = (ROOT / "modules/dashboard/weather/HourlyChart.qml").read_text(encoding="utf-8")


def test_hourly_section_is_a_chart():
    assert 'import "weather"' in TAB
    assert "HourlyChart {" in TAB
    assert "hourlyRow" not in TAB
    for needle in ("Shape.CurveRenderer", "LinearGradient", "PathSvg", "useFahrenheit", "useTwelveHourClock", 'qsTr("Now")'):
        assert needle in CHART, needle


def test_chart_credits_its_design_source():
    assert "Caelestia-Hourly-Weather (GPL-3.0" in CHART


def test_seven_day_forecast_is_not_hidden_by_hourly_data():
    assert "!(Weather.hourlyForecast && Weather.hourlyForecast.length > 0)" not in TAB
    assert 'qsTr("7-day forecast")' in TAB


def test_attribution_is_a_quiet_footer_with_themed_links():
    assert "textFormat: Text.StyledText" in TAB
    assert "linkColor: Signal.palette.inkMuted" in TAB
    assert "Text.MarkdownText" not in TAB

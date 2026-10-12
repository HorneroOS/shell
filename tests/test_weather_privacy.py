"""Weather stays idle without an explicitly configured location.

Execute the QML service's reload/request functions with a stub network layer,
so this contract proves behavior without reaching the network or opening HOME.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE = ROOT / "services" / "Weather.qml"
LOCK_WEATHER = ROOT / "modules" / "lock" / "WeatherInfo.qml"


def _function(source: str, name: str) -> str:
    match = re.search(rf"\bfunction {name}\s*\([^)]*\)(?:\s*:\s*\w+)?\s*\{{", source)
    assert match, f"Weather.qml is missing {name}"
    start = match.end() - 1
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                header = source[match.start():start]
                header = re.sub(r":\s*(?:string|var|int|bool|real|void)\b", "", header)
                return header + source[start:index + 1]
    raise AssertionError(f"unclosed QML function {name}")


def test_weather_network_requests_require_explicit_location():
    node = shutil.which("node")
    assert node, "Node.js is required to exercise the asynchronous QML service contract"
    source = SERVICE.read_text()
    functions = {name: _function(source, name) for name in ("reload", "request", "onWeatherLocationChanged")}
    script = r"""
const assert = require('node:assert/strict');
const functions = JSON.parse(process.argv[1]);
let requests = [];
const Config = { services: { weatherLocation: '' } };
const scope = {
  Config,
  Requests: { get(url, ok, fail, userAgent) { requests.push({url, ok, fail, userAgent}); } },
  qsTr: x => x,
  _requestGeneration: 0,
  get locationConfigured() { return !!Config.services.weatherLocation.trim(); },
  set lastError(v) {}, set cc(v) {}, set forecast(v) {}, set hourlyForecast(v) {},
  set city(v) {}, set loc(v) {}, set loading(v) { this._loading = v; },
  _setLocation() { throw new Error('empty location must not start a lookup'); },
  fetchCoordsFromCity(location) {
    invoke(functions.request, `https://example.invalid/geocode?name=${encodeURIComponent(location)}`, () => {}, () => {});
  },
};
scope.root = scope;
const invoke = (source, ...args) => Function('scope', `with (scope) { return (${source}); }`)(scope)(...args);
scope.reload = () => invoke(functions.reload);
invoke(functions.reload);
assert.equal(requests.length, 0, 'startup with an empty location must stay offline');
invoke(functions.request, 'https://example.invalid', () => {}, () => {});
assert.equal(requests.length, 0, 'request entry point must reject an empty location');
Config.services.weatherLocation = 'Buenos Aires';
invoke(functions.onWeatherLocationChanged);
assert.equal(requests.length, 1, 'changing the setting must trigger the real configuration handler');
assert.equal(requests[0].url.includes('Buenos%20Aires'), true, 'the handler must start lookup for the new location');
const delayed = requests[0].ok;
Config.services.weatherLocation = '';
invoke(functions.onWeatherLocationChanged);
delayed('late response');
assert.equal(requests.length, 1, 'clearing location must not schedule another request');
assert.equal(scope._loading, false, 'clearing location through the settings handler must stop loading');
"""
    result = subprocess.run(
        [node, "-e", script, json.dumps(functions)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr


def test_automatic_ip_discovery_and_plain_http_are_absent():
    source = SERVICE.read_text()
    assert "detectLocation" not in source
    assert "ip-api.com" not in source
    assert "http://" not in source
    assert source.count("Requests.get(") == 1, "all network access must pass the guarded request method"


def test_nominatim_request_identifies_horneroos_and_attributes_openstreetmap():
    source = SERVICE.read_text()
    reverse_geocode = _function(source, "fetchCityFromCoords")
    assert '"HorneroOS Shell (https://github.com/HorneroOS/shell; https://horneroos.com)"' in reverse_geocode
    assert '}, userAgent || "");' in _function(source, "request")

    settings = (ROOT / "modules" / "controlcenter" / "dashboard" / "GeneralSection.qml").read_text()
    assert "[© OpenStreetMap contributors](https://www.openstreetmap.org/copyright)" in settings
    assert "onLinkActivated: link => Quickshell.execDetached" in settings

    dashboard = (ROOT / "modules" / "dashboard" / "Weather.qml").read_text()
    assert "[Open-Meteo](https://open-meteo.com/)" in dashboard
    assert "[© OpenStreetMap contributors](https://www.openstreetmap.org/copyright)" in dashboard


def test_reverse_geocoding_caches_success_and_failure_for_the_session():
    node = shutil.which("node")
    assert node, "Node.js is required to exercise the asynchronous QML service contract"
    source = SERVICE.read_text()
    functions = {
        name: _function(source, name)
        for name in ("request", "fetchCityFromCoords")
    }
    script = r"""
const assert = require('node:assert/strict');
const functions = JSON.parse(process.argv[1]);
const requests = [];
const Config = { services: { weatherLocation: '10,20' } };
const scope = {
  Config,
  Requests: { get(url, ok, fail, userAgent) { requests.push({url, ok, fail, userAgent}); } },
  console: { warn() {} },
  _requestGeneration: 0,
  cachedCities: new Map(),
  city: '',
  get locationConfigured() { return !!Config.services.weatherLocation.trim(); },
};
const invoke = (source, ...args) => Function('scope', `with (scope) { return (${source}); }`)(scope)(...args);
scope.request = (...args) => invoke(functions.request, ...args);

invoke(functions.fetchCityFromCoords, '10,20');
assert.equal(requests.length, 1);
assert.match(requests[0].userAgent, /^HorneroOS Shell /);
requests[0].ok(JSON.stringify({features: [{properties: {geocoding: {type: 'city', name: 'Test City'}}}]}));
invoke(functions.fetchCityFromCoords, '10,20');
assert.equal(requests.length, 1, 'hourly refresh should reuse a successful cached lookup');
assert.equal(scope.city, 'Test City');

scope.city = '';
invoke(functions.fetchCityFromCoords, '30,40');
assert.equal(requests.length, 2);
requests[1].fail('offline');
invoke(functions.fetchCityFromCoords, '30,40');
assert.equal(requests.length, 2, 'hourly refresh should not retry a failed lookup');
assert.equal(scope.city, 'Unknown City');
"""
    result = subprocess.run(
        [node, "-e", script, json.dumps(functions)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr


def test_lock_weather_hides_measurements_until_weather_is_available():
    source = LOCK_WEATHER.read_text()
    humidity = re.search(r"StyledText\s*\{[^{}]*text:\s*qsTr\(\"Humidity:", source, re.S)
    assert humidity, "lock weather should keep a humidity row for configured locations"
    assert re.search(r"visible:\s*!!Weather\.cc", humidity.group(0)), "humidity must not show a fabricated 0%"
    assert "active: root.rootHeight > 820 && Weather.ready" in source, "forecast rows need loaded weather data"

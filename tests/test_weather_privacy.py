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
    functions = {name: _function(source, name) for name in ("reload", "request")}
    script = r"""
const assert = require('node:assert/strict');
const functions = JSON.parse(process.argv[1]);
let requests = [];
const Config = { services: { weatherLocation: '' } };
const scope = {
  Config,
  Requests: { get(url, ok, fail) { requests.push({url, ok, fail}); } },
  qsTr: x => x,
  _requestGeneration: 0,
  get locationConfigured() { return !!Config.services.weatherLocation.trim(); },
  set lastError(v) {}, set cc(v) {}, set forecast(v) {}, set hourlyForecast(v) {},
  set city(v) {}, set loc(v) {}, set loading(v) {},
  _setLocation() { throw new Error('empty location must not start a lookup'); },
};
const invoke = (source, ...args) => Function('scope', `with (scope) { return (${source}); }`)(scope)(...args);
invoke(functions.reload);
assert.equal(requests.length, 0, 'startup with an empty location must stay offline');
invoke(functions.request, 'https://example.invalid', () => {}, () => {});
assert.equal(requests.length, 0, 'request entry point must reject an empty location');
Config.services.weatherLocation = 'Buenos Aires';
invoke(functions.request, 'https://example.invalid', () => { throw new Error('stale response applied'); }, () => {});
assert.equal(requests.length, 1);
const delayed = requests[0].ok;
Config.services.weatherLocation = '';
scope._requestGeneration++;
delayed('late response');
assert.equal(requests.length, 1, 'stale callback must not schedule another request');
invoke(functions.reload);
assert.equal(requests.length, 1, 'clearing location must stop subsequent refreshes');
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


def test_lock_weather_hides_measurements_until_weather_is_available():
    source = LOCK_WEATHER.read_text()
    humidity = re.search(r"StyledText\s*\{[^{}]*text:\s*qsTr\(\"Humidity:", source, re.S)
    assert humidity, "lock weather should keep a humidity row for configured locations"
    assert re.search(r"visible:\s*!!Weather\.cc", humidity.group(0)), "humidity must not show a fabricated 0%"
    assert "active: root.rootHeight > 820 && Weather.ready" in source, "forecast rows need loaded weather data"

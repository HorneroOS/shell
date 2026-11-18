"""Factory shell defaults: config/shell.default.json must equal the shell's
in-code defaults key by key.

The factory file mirrors exactly what Config.qml serializeConfig() persists
on save (the key set the shell itself reads back through its JsonAdapter),
with values taken from the per-area *Config.qml initializers.

Schema coverage of the serializer itself (no JsonObject property dropped
on save) is enforced by tests/test_config_serializer.py.

Documented omissions (each asserted below with its reason):
- services.useTwelveHourClock: computed from Qt.locale() at runtime; left
  unset so first-run locale detection still applies.
- paths.wallpaperDir: runtime default is `${Paths.pictures}/Wallpapers`
  (XDG-aware); left unset so per-host resolution still applies.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_QML = ROOT / "config" / "Config.qml"
FACTORY = ROOT / "config" / "shell.default.json"

# (section, key, ...) paths intentionally absent from the factory file.
OMITTED = {
    ("services", "useTwelveHourClock"),
    ("paths", "wallpaperDir"),
}


class _Parser:
    """Minimal parser for the object literals returned by serialize*()."""

    def __init__(self, text):
        self.s = text
        self.i = 0

    def _ws(self):
        while self.i < len(self.s):
            if self.s[self.i].isspace():
                self.i += 1
            elif self.s.startswith("//", self.i):
                while self.i < len(self.s) and self.s[self.i] != "\n":
                    self.i += 1
            else:
                break

    def _string(self):
        q = self.s[self.i]
        assert q in "\"'", f"unexpected {q!r} at {self.i}"
        self.i += 1
        out = []
        while self.s[self.i] != q:
            if self.s[self.i] == "\\":
                out.append(self.s[self.i:self.i + 2])
                self.i += 2
            else:
                out.append(self.s[self.i])
                self.i += 1
        self.i += 1
        return "".join(out)

    def _key(self):
        self._ws()
        if self.s[self.i] in "\"'":
            return self._string()
        m = re.match(r"[A-Za-z_$][\w$]*", self.s[self.i:])
        assert m, f"no key at offset {self.i}: {self.s[self.i:self.i+20]!r}"
        self.i += len(m.group(0))
        return m.group(0)

    def _skip_value(self):
        # Skip one value; return the parsed subtree for '{...}' objects so
        # callers get the nested key structure, else None.
        self._ws()
        if self.s[self.i] == "{":
            return self._object()
        if self.s[self.i] in "\"'":
            self._string()
            return None
        depth = {"(": 0, "[": 0}
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in "\"'":
                self._string()
                continue
            if c == "(":
                depth["("] += 1
            elif c == ")":
                depth["("] -= 1
            elif c == "[":
                depth["["] += 1
            elif c == "]":
                if depth["["] == 0:
                    break
                depth["["] -= 1
            elif c in ",}" and depth["("] == 0 and depth["["] == 0:
                break
            self.i += 1
        return None

    def _object(self):
        assert self.s[self.i] == "{"
        self.i += 1
        keys = {}
        while True:
            self._ws()
            if self.s[self.i] == "}":
                self.i += 1
                return keys
            key = self._key()
            self._ws()
            assert self.s[self.i] == ":", f"no colon after {key!r}"
            self.i += 1
            keys[key] = self._skip_value()
            self._ws()
            if self.s[self.i] == ",":
                self.i += 1

    def parse_function_object(self):
        # Body is `return { ... };` possibly preceded by try/config noise.
        at = self.s.index("return", self.i)
        brace = self.s.index("{", at)
        self.i = brace
        return self._object()


def _fn_body(text, name):
    start = text.index(f"function {name}()")
    brace = text.index("{", start)
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[brace:i + 1]
    raise AssertionError(f"unbalanced braces in {name}")


def _expected_tree():
    text = CONFIG_QML.read_text()
    sections = _Parser(_fn_body(text, "serializeConfig")).parse_function_object()
    tree = {}
    for section in sections:
        body = _fn_body(text, f"serialize{section[0].upper()}{section[1:]}")
        tree[section] = _Parser(body).parse_function_object()
    return tree


def _check_keys(path, expected, actual):
    if isinstance(expected, dict):
        assert isinstance(actual, dict), f"{path or 'root'}: object expected"
        for key, sub in expected.items():
            if (*path, key) in OMITTED:
                assert key not in actual, f"{'.'.join([*path, key])} must stay omitted"
                continue
            assert key in actual, f"missing key {'.'.join([*path, key])}"
            _check_keys([*path, key], sub, actual[key])
        extra = set(actual) - set(expected) - {p[-1] for p in OMITTED if p[:-1] == tuple(path)}
        assert not extra, f"{path or 'root'}: unexpected keys {sorted(extra)}"
    # Non-object values (arrays/scalars) are opaque to the key check; values
    # are pinned by test_factory_values_match_code_defaults.


def _get(factory, dotted):
    node = factory
    for part in dotted.split("."):
        node = node[int(part)] if isinstance(node, list) else node[part]
    return node


def test_factory_key_structure_matches_serialize_functions():
    expected = _expected_tree()
    factory = json.loads(FACTORY.read_text())
    assert set(factory) == set(expected), (
        f"top-level mismatch: missing={set(expected) - set(factory)} "
        f"extra={set(factory) - set(expected)}"
    )
    _check_keys([], expected, factory)


def test_factory_values_match_code_defaults():
    factory = json.loads(FACTORY.read_text())
    bar_src = (ROOT / "config" / "BarConfig.qml").read_text()
    cases = [
        # appearance (AppearanceConfig.qml)
        ("appearance.theme", "hornero-signal-night"),
        ("appearance.reducedMotion", False),
        ("appearance.sliders.readout", True),
        ("appearance.sliders.readoutHold", 900),
        ("appearance.rounding.scale", 1),
        ("appearance.font.family.sans", "IBM Plex Sans"),
        ("appearance.font.family.mono", "IBM Plex Mono"),
        ("appearance.font.family.display", "IBM Plex Sans Condensed"),
        ("appearance.anim.mediaGifSpeedAdjustment", 300),
        ("appearance.anim.sessionGifSpeed", 0.7),
        ("appearance.transparency.enabled", False),
        ("appearance.transparency.base", 0.85),
        # general (GeneralConfig.qml; qsTr() yields the plain source string)
        ("general.apps.terminal", ["kitty"]),
        ("general.idle.lockBeforeSleep", True),
        ("general.idle.timeouts.1.idleAction", "dpms off"),
        ("general.battery.criticalLevel", 3),
        ("general.battery.warnLevels.0.level", 20),
        ("general.battery.warnLevels.2.critical", True),
        # background (BackgroundConfig.qml)
        ("background.enabled", True),
        ("background.desktopClock.position", "bottom-right"),
        ("background.desktopClock.shadow.blur", 0.4),
        ("background.visualiser.autoHide", True),
        ("background.video.enabled", True),
        ("background.video.batteryLimit", 20),
        # bar (BarConfig.qml) — factory default is the Cockpit layout
        # (presets/cockpit.json): top rail to act, bottom strip to know.
        ("bar.bars.0.edge", "top"),
        ("bar.bars.0.style", "inset"),
        ("bar.bars.0.margin", 18),
        ("bar.bars.0.radius", 11),
        ("bar.bars.0.thickness", 42),
        ("bar.bars.1.edge", "bottom"),
        ("bar.bars.1.style", "attached"),
        ("bar.bars.1.thickness", 28),
        ("bar.bars.1.margin", 0),
        ("bar.bars.1.groups.start.0.id", "workspaces"),
        ("bar.workspaces.shown", 5),
        ("bar.workspaces.maxWindowIcons", 3),
        ("bar.workspaces.glyphScale", 85),
        ("bar.activeWindow.inverted", False),
        ("bar.tray.hiddenIcons", []),
        ("bar.clock.showDate", False),
        ("bar.clock.background", False),
        ("bar.sizes.kbLayoutWidth", 320),
        ("bar.workspaces.showWindowsOnSpecialWorkspaces", True),
        ("bar.workspaces.capitalisation", "preserve"),
        ("bar.status.showNetwork", True),
        ("bar.status.showAudio", True),
        ("bar.status.showBattery", False),
        ("bar.sizes.innerWidth", 24),
        ("bar.bars.0.groups.start.0.id", "logo"),
        ("bar.bars.0.groups.center.0.id", "clock"),
        # Cockpit top-rail end order (presets/cockpit.json).
        ("bar.bars.0.groups.end.0.id", "modeIndicator"),  # shell#478, hidden in Everyday
        ("bar.bars.0.groups.end.1.id", "statusIcons"),
        ("bar.bars.0.groups.end.2.id", "tray"),
        ("bar.bars.0.groups.end.3.id", "extensions"),  # shell#441 island
        ("bar.bars.0.groups.end.4.id", "power"),
        ("bar.extensions.background", False),
        ("bar.extensions.compact", False),
        # border resolves Appearance tokens at scale 1: padding.normal=10,
        # rounding.large=25 (BorderConfig.qml)
        ("border.frameEnabled", True),
        ("border.thickness", 10),
        ("border.rounding", 25),
        ("border.edgeWidth", 1),
        # dashboard (DashboardConfig.qml)
        ("dashboard.dragThreshold", 50),
        ("dashboard.mediaUpdateInterval", 500),
        ("dashboard.resourceUpdateInterval", 1000),
        ("dashboard.sensorUpdateInterval", 2000),
        ("dashboard.diskUpdateInterval", 30000),
        ("dashboard.workspaces.maxAppIcons", 4),
        ("dashboard.workspaces.previewHeight", 200),
        ("dashboard.performance.showGpu", True),
        ("dashboard.sizes.mediaCoverArtSize", 150),
        # controlCenter / lock ratios are 16/9 in code (ControlCenterConfig,
        # LockConfig.qml)
        ("controlCenter.sizes.ratio", 16 / 9),
        # Appearance disclosure default exposes Themes first run
        # (ControlCenterConfig.qml appearanceOpenSections).
        ("controlCenter.appearanceOpenSections", ["themes"]),
        ("controlCenter.appearanceHoverPreview", True),
        ("launcher.maxShown", 8),
        ("launcher.specialPrefix", "@"),
        ("launcher.useFuzzy.wallpapers", False),
        ("launcher.sizes.itemHeight", 44),
        ("launcher.actions.5.name", "Random"),
        ("launcher.actions.10.command.2", ""),
        ("launcher.actions.13.command.0", "horneroctl"),
        ("launcher.actions.13.command.1", "config"),
        ("launcher.actions.13.command.2", "gui"),
        # notifs / osd
        ("notifs.defaultExpireTimeout", 5000),
        ("notifs.clearThreshold", 0.3),
        ("notifs.openExpanded", False),
        ("notifs.sizes.badge", 20),
        ("osd.hideDelay", 2000),
        ("osd.enableMicrophone", False),
        # session / winfo / lock / utilities / sidebar
        ("session.dragThreshold", 30),
        ("session.commands.hibernate.1", "hibernate"),
        ("session.sizes.button", 80),
        ("winfo.sizes.detailsWidth", 500),
        ("lock.maxFprintTries", 3),
        ("lock.hideNotifs", True),
        ("lock.sizes.centerWidth", 600),
        ("utilities.maxToasts", 4),
        ("utilities.toasts.nowPlaying", False),
        ("utilities.toasts.kbLimit", True),
        ("utilities.vpn.provider", ["netbird"]),
        ("sidebar.sizes.width", 430),
        # services (ServiceConfig.qml; useTwelveHourClock intentionally
        # absent because it is locale-computed)
        ("services.visualiserBars", 45),
        ("services.audioIncrement", 0.1),
        ("services.maxVolume", 1.0),
        ("services.smartScheme", True),
        ("services.defaultPlayer", "Spotify"),
        ("services.playerAliases.0.to", "YT Music"),
        # paths (UserPaths.qml; wallpaperDir intentionally absent, XDG-aware)
        ("paths.sessionGif", "root:/assets/kurukuru.gif"),
        ("paths.mediaGif", "root:/assets/bongocat.gif"),
    ]
    for dotted, want in cases:
        node = factory
        for part in dotted.split("."):
            node = node[int(part)] if isinstance(node, list) else node[part]
        assert node == want, f"{dotted}: got {node!r}, want {want!r}"
    # Workspace defaults show native workspace IDs instead of ambiguous glyphs.
    for key in ("label", "occupiedLabel", "activeLabel"):
        m = re.search(rf"property string {key}: \"(.*?)\"", bar_src)
        assert m, f"{key} default not found in BarConfig.qml"
        assert m.group(1) == "", f"{key} should use the readable workspace ID fallback"
        assert factory["bar"]["workspaces"][key] == "", f"bar.workspaces.{key} should use the readable workspace ID fallback"


def test_factory_documents_omissions():
    for path in OMITTED:
        node = json.loads(FACTORY.read_text())
        for part in path[:-1]:
            node = node[part]
        assert path[-1] not in node, f"omitted key {'.'.join(path)} present"


def test_missing_user_config_is_not_an_error():
    # Existing behavior (config/Config.qml): the FileView reads
    # ${Paths.config}/shell.json and its onLoadFailed handler ignores a
    # missing file, so first run with compiled defaults is not an error.
    text = CONFIG_QML.read_text()
    assert "${Paths.config}/shell.json" in text
    m = re.search(r"onLoadFailed:\s*err\s*=>\s*\{(.*?)\}", text, re.DOTALL)
    assert m, "Config.qml FileView must keep its onLoadFailed handler"
    assert "FileViewError.FileNotFound" in m.group(1), (
        "missing shell.json (FileNotFound) must stay a tolerated case"
    )

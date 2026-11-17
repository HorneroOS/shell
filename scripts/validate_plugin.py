#!/usr/bin/env python3
"""Validate a Hornero Shell extension's manifest and conservative source rules.

This validator is a review aid. Quickshell extensions run with the user's
permissions and are not sandboxed; passing validation is not a safety proof.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import stat
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse


ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
SEMVER = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$"
)
SAFE_COMMAND = re.compile(r"^[A-Za-z0-9_.+-]+$")
SAFE_ACTION = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
SAFE_HOST = re.compile(
    r"^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$"
)
SAFE_PATH = re.compile(r"^[A-Za-z0-9._/-]+$")
IMPORT = re.compile(r"^\s*import\s+([A-Za-z0-9_.]+)(?:\s+[0-9.]+)?", re.MULTILINE)
PROCESS_COMMAND = re.compile(
    r"\bProcess\s*\{(?:(?!\bProcess\s*\{).)*?\bcommand\s*:\s*\[\s*['\"]([^'\"]+)['\"]",
    re.DOTALL,
)
URL_LITERAL = re.compile(r"https?://([^/\s'\"\\]+)", re.IGNORECASE)
FORBIDDEN_COMMANDS = {"sh", "bash", "dash", "zsh", "fish", "sudo", "doas", "su"}
FORBIDDEN_MARKERS = (
    re.compile(r"\b(?:sudo|doas|pkexec)\b|\bsu\s+-"),
    re.compile(r"\b(?:sh|bash|dash|zsh|fish)\s+-c\b"),
    re.compile(r"(?:^|[/\\])\.ssh(?:[/\\]|$)"),
    re.compile(r"(?:^|[\s='\"])/etc(?:/|\s|['\"]|$)"),
    re.compile(r"\b(?:HOME|XDG_CONFIG_HOME)\s*[/+]"),
)
LOCALE_TAG = re.compile(r"^[a-z]{2,3}(_[A-Z]{2})?$")
# PluginKit Translations calls with a literal source string, e.g.
# i18n.tr("Example Clock"). Only literal strings are extracted for
# catalog-coverage checks; dynamic strings are the author's
# responsibility (documented in docs/PLUGINS.md).
TR_LITERAL = re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"')
QSTR_CALL = re.compile(r"\bqsTr\s*\(")
PLACEHOLDER = re.compile(r"%\d+")
PLACEMENTS = ("background", "bar", "dashboard", "desktop")
# Manifest v2 surfaces. The first four have runtime hosts today;
# "settings" (Control Center settings) is hosted in Control Center
# › Extensions; "launcher" (search/launcher action) is hosted by
# PluginLauncherHost into the launcher provider registry, and
# declaring one grants no privilege.
SURFACES = PLACEMENTS + ("launcher", "settings", "commands")
# Surfaces that exist only from PluginKit 4 (RFC 0003): declaring one needs
# `"pluginKit": 4`.
SURFACES_V4 = ("commands",)
# Dashboard card size classes (shell#378): preferred card width class a
# dashboard surface may hint; the user's persisted layout wins.
DASHBOARD_CARD_SIZES = ("compact", "standard", "wide")
BAR_SECTIONS = ("status", "actions", "clock", "end")
SCHEMA_VERSIONS = (3,)
# PluginKit API level this validator targets; must equal
# plugin/qml/Hornero/PluginKit/PluginKitInfo.qml apiLevel (tested).
PLUGINKIT_API_LEVEL = 4
# Material-era manifests (PluginKit 1/2) are refused with a migration hint.
LEGACY_SCHEMA_VERSIONS = (1, 2)
DESKTOP_ANCHORS = (
    "top-left", "top-center", "top-right",
    "middle-left", "middle-center", "middle-right",
    "bottom-left", "bottom-center", "bottom-right",
)
DESKTOP_SIZE_KEYS = ("width", "height", "minWidth", "minHeight")
DESKTOP_KEYS = DESKTOP_SIZE_KEYS + ("resizable", "anchor", "instances")
# Shared provider domains (RFC 0001 §5b) an extension may read; declared
# in capabilities.providers and cross-checked against the QML.
PROVIDER_DOMAINS = (
    "system", "network", "spectrum", "media", "audio", "power", "weather",
    "time", "workspaces",
)
FACADE_DOMAINS = {
    "System": ("system",),
    "Telemetry": ("system", "network"),
    "Network": ("network",),
    "Media": ("media",),
    "Audio": ("audio",),
    "Power": ("power",),
    "Weather": ("weather",),
    "Time": ("time",),
    "Workspaces": ("workspaces",),
}
GLYPH_NAMES_FILE = Path(__file__).resolve().parent.parent / "assets" / "fonts" / "hornero-glyphs.names"
ALLOWED_IMPORTS = (
    "QtQuick",
    "QtQuick.Controls",
    "QtQuick.Layouts",
    "QtQml",
    "Quickshell",
    "Quickshell.Io",
    "Hornero.PluginKit",
)


class ValidationError(Exception):
    pass


def _object(value: object, where: str) -> dict:
    if not isinstance(value, dict):
        raise ValidationError(f"{where} must be an object")
    return value


def _string(value: object, where: str, maximum: int) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValidationError(f"{where} must be a non-empty string of at most {maximum} characters")
    return value


def _safe_relative(value: object, where: str, *, qml: bool = False) -> str:
    path = _string(value, where, 240)
    pure = PurePosixPath(path)
    if (
        not SAFE_PATH.fullmatch(path)
        or pure.is_absolute()
        or pure.as_posix() != path
        or ".." in pure.parts
        or "\\" in path
        or "\x00" in path
    ):
        raise ValidationError(f"{where} must be a safe relative path")
    if qml and pure.suffix != ".qml":
        raise ValidationError(f"{where} must point to a .qml file")
    return path


def _string_list(value: object, where: str, item_pattern: re.Pattern[str]) -> list[str]:
    if not isinstance(value, list):
        raise ValidationError(f"{where} must be an array")
    if any(not isinstance(item, str) or not item_pattern.fullmatch(item) for item in value):
        raise ValidationError(f"{where} contains an invalid value")
    if len(value) != len(set(value)):
        raise ValidationError(f"{where} must not contain duplicates")
    return value


def _validate_surfaces(
    manifest: dict,
    schema_version: int,
    placement: str,
    entrypoint: str,
    safe_files: set[str],
) -> None:
    if "surfaces" not in manifest:
        return
    surfaces = _object(manifest["surfaces"], "surfaces")
    if not surfaces:
        raise ValidationError(
            "surfaces must declare at least one surface (remove the empty "
            "\"surfaces\": {} or add a surface entrypoint)"
        )
    for name, raw_surface in surfaces.items():
        where = f"surfaces.{name}"
        if name not in SURFACES:
            raise ValidationError(
                f"unknown surface {name!r} in surfaces (known surfaces: "
                f"{', '.join(SURFACES)}; a bar popover/panel is shown from the "
                "bar surface with PluginKit UiPopover, not a separate surface)"
            )
        if name in SURFACES_V4 and manifest.get("pluginKit", 3) < 4:
            raise ValidationError(
                f'{where} is a PluginKit 4 surface; declare "pluginKit": 4 in the manifest'
            )
        surface = _object(raw_surface, where)
        extra = set(surface) - {"entrypoint", "enabled", "size", "category", "section", *DESKTOP_KEYS}
        if extra:
            raise ValidationError(
                f"{where} contains unknown fields: {', '.join(sorted(extra))} "
                "(a surface declares only entrypoint, optional enabled, and — "
                "dashboard only — optional size/category card hints; bar only — "
                "optional section; desktop only — optional width/height/"
                "minWidth/minHeight/resizable/anchor widget hints)"
            )
        # Desktop widget hints (PluginKit 3): default and minimum logical
        # size, resizability and the default anchor; the person's saved
        # geometry always wins.
        desktop_hints = [key for key in DESKTOP_KEYS if key in surface]
        if desktop_hints and name != "desktop":
            raise ValidationError(
                f"{where}.{desktop_hints[0]} is a desktop widget hint and is only "
                "allowed on the desktop surface"
            )
        for key in DESKTOP_SIZE_KEYS:
            if key in surface:
                value = surface[key]
                if type(value) is not int or not 80 <= value <= 1600:
                    raise ValidationError(
                        f"{where}.{key} must be an integer between 80 and 1600 (logical pixels)"
                    )
        for low, high in (("minWidth", "width"), ("minHeight", "height")):
            if low in surface and high in surface and surface[low] > surface[high]:
                raise ValidationError(f"{where}.{low} must not exceed {where}.{high}")
        if "resizable" in surface and not isinstance(surface["resizable"], bool):
            raise ValidationError(f"{where}.resizable must be a boolean")
        # RFC 0003 section 6: the extension reads its settings per
        # instance (hostInstanceId + Settings.instanceId), so Control
        # Center may add extra instances of its desktop widget. A level-4
        # feature: declaring it needs "pluginKit": 4.
        if "instances" in surface:
            if not isinstance(surface["instances"], bool):
                raise ValidationError(f"{where}.instances must be a boolean")
            if surface["instances"] and manifest.get("pluginKit", 3) < 4:
                raise ValidationError(
                    f'{where}.instances needs PluginKit 4; declare "pluginKit": 4 in the manifest'
                )
        if "anchor" in surface and surface["anchor"] not in DESKTOP_ANCHORS:
            raise ValidationError(
                f"{where}.anchor must be one of {', '.join(DESKTOP_ANCHORS)}"
            )
        # Bar section hint (shell#439): which native bar island the
        # indicator joins instead of a separate block after the end group.
        if "section" in surface and name != "bar":
            raise ValidationError(
                f"{where}.section is a bar hint and is only allowed on the bar surface"
            )
        if "section" in surface and surface["section"] not in BAR_SECTIONS:
            raise ValidationError(
                f"{where}.section must be one of {', '.join(BAR_SECTIONS)} "
                "(native bar island the indicator joins; default end)"
            )
        # Dashboard card hints (shell#378): the composable dashboard
        # layout reads a preferred card size class and grouping
        # category from the dashboard surface. They are hints: the
        # user's persisted layout overrides both, and declaring them
        # on any other surface is a mistake worth an actionable error
        # (no other host has cards to size or group).
        if ("size" in surface or "category" in surface) and name != "dashboard":
            raise ValidationError(
                f"{where}.size/category are dashboard card hints and are only "
                "allowed on the dashboard surface"
            )
        if "size" in surface and surface["size"] not in DASHBOARD_CARD_SIZES:
            raise ValidationError(
                f"{where}.size must be one of {', '.join(DASHBOARD_CARD_SIZES)} "
                "(preferred dashboard card size class; users can override it)"
            )
        if "category" in surface:
            category = surface["category"]
            if (
                not isinstance(category, str)
                or not category.strip()
                or len(category) > 40
                or category.strip().lower() == "pinned"
            ):
                raise ValidationError(
                    f"{where}.category must be a non-empty grouping label of at "
                    'most 40 characters (and not the reserved "Pinned" section)'
                )
        if "entrypoint" not in surface:
            raise ValidationError(f"{where}.entrypoint is required (the .qml file this surface loads)")
        surface_entrypoint = _safe_relative(surface["entrypoint"], f"{where}.entrypoint", qml=True)
        if surface_entrypoint not in safe_files:
            raise ValidationError(
                f"{where}.entrypoint must be listed in files (add {surface_entrypoint!r} to files)"
            )
        if name == placement and surface_entrypoint != entrypoint:
            raise ValidationError(
                f"{where}.entrypoint conflicts with the top-level entrypoint: "
                f"placement {placement!r} is the primary surface and already loads "
                f"{entrypoint!r}; redeclare it in surfaces only with the same "
                "entrypoint (e.g. to set enabled) or change the top-level placement"
            )
        if "enabled" in surface and not isinstance(surface["enabled"], bool):
            raise ValidationError(f"{where}.enabled must be a boolean (true or false)")


# Contributions (RFC 0003 section 4.1): declarative metadata the Shell can
# list without running extension code. PluginKit 4 defines `commands`
# (launcher rows, IPC, key bindings); other kinds are rejected until a
# later level defines them, so an older validator never silently accepts
# a contribution it cannot host.
CONTRIBUTION_KINDS = ("commands",)
COMMAND_ID = re.compile(r"^[a-z][a-zA-Z0-9]{0,31}$")
MAX_COMMANDS = 16
COMMAND_FIELDS = {"id", "title", "description", "glyph", "keywords"}


def _validate_contributes(manifest: dict, declared_level: int) -> list[dict]:
    """Validate `contributes`; returns the declared command list."""
    surfaces = manifest.get("surfaces") or {}
    has_surface = "commands" in surfaces
    if "contributes" not in manifest:
        if has_surface:
            raise ValidationError(
                "surfaces.commands needs contributes.commands: declare the commands "
                "(id, title) the extension provides so the Shell can list them"
            )
        return []
    if declared_level < 4:
        raise ValidationError('contributes needs PluginKit 4; declare "pluginKit": 4 in the manifest')
    contributes = _object(manifest["contributes"], "contributes")
    if not contributes:
        raise ValidationError("contributes must declare at least one contribution kind (remove it or add commands)")
    unknown = set(contributes) - set(CONTRIBUTION_KINDS)
    if unknown:
        raise ValidationError(
            f"contributes contains unknown kinds: {', '.join(sorted(unknown))} "
            f"(known kinds: {', '.join(CONTRIBUTION_KINDS)})"
        )
    commands = contributes.get("commands", [])
    if not isinstance(commands, list) or not commands or len(commands) > MAX_COMMANDS:
        raise ValidationError(f"contributes.commands must be a list of 1 to {MAX_COMMANDS} commands")
    seen: set[str] = set()
    glyphs = glyph_names()
    for index, raw in enumerate(commands):
        where = f"contributes.commands[{index}]"
        command = _object(raw, where)
        extra = set(command) - COMMAND_FIELDS
        if extra:
            raise ValidationError(
                f"{where} contains unknown fields: {', '.join(sorted(extra))} "
                "(a command declares id, title and optional description, glyph, keywords)"
            )
        if not {"id", "title"} <= set(command):
            raise ValidationError(f"{where} must contain id and title")
        command_id = command["id"]
        if not isinstance(command_id, str) or not COMMAND_ID.fullmatch(command_id):
            raise ValidationError(f"{where}.id must match {COMMAND_ID.pattern}")
        if command_id in seen:
            raise ValidationError(f"{where}.id duplicates another command: {command_id}")
        seen.add(command_id)
        _string(command["title"], f"{where}.title", 48)
        if "description" in command:
            _string(command["description"], f"{where}.description", 120)
        if "glyph" in command and (not isinstance(command["glyph"], str) or (glyphs and command["glyph"] not in glyphs)):
            raise ValidationError(f"{where}.glyph must be a Hornero Glyph name (assets/fonts/hornero-glyphs.names)")
        if "keywords" in command:
            keywords = command["keywords"]
            if (
                not isinstance(keywords, list) or len(keywords) > 8
                or any(not isinstance(k, str) or not k.strip() or len(k) > 24 for k in keywords)
                or len(set(keywords)) != len(keywords)
            ):
                raise ValidationError(f"{where}.keywords must be at most 8 unique strings of at most 24 characters")
    if not has_surface:
        raise ValidationError(
            "contributes.commands needs surfaces.commands: the entrypoint that implements "
            "`function run(commandId: string, args: string): string`"
        )
    return commands


def _unescape_qml_string(raw: str) -> str:
    out: list[str] = []
    index = 0
    escapes = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
    while index < len(raw):
        char = raw[index]
        if char == "\\" and index + 1 < len(raw) and raw[index + 1] in escapes:
            out.append(escapes[raw[index + 1]])
            index += 2
        else:
            out.append(char)
            index += 1
    return "".join(out)


def _validate_translations_declaration(
    manifest: dict, safe_files: set[str]
) -> tuple[str, list[str]] | None:
    """Validate the optional `translations` declaration shape.

    Returns (directory, locales) for the catalog checks, or None when
    the package declares no translations (the pre-#375 shape, which
    stays valid). Catalogs are flat JSON files — source-reviewable,
    never compiled .qm binaries.
    """
    if "translations" not in manifest:
        return None
    translations = _object(manifest["translations"], "translations")
    extra = set(translations) - {"sourceLocale", "locales", "directory"}
    if extra:
        raise ValidationError(
            f"translations contains unknown fields: {', '.join(sorted(extra))} "
            "(a translations declaration names only sourceLocale, locales, "
            "and optional directory)"
        )
    if not {"sourceLocale", "locales"} <= set(translations):
        raise ValidationError("translations must contain sourceLocale and locales (directory is optional)")
    source_locale = translations["sourceLocale"]
    if not isinstance(source_locale, str) or not LOCALE_TAG.fullmatch(source_locale):
        raise ValidationError('translations.sourceLocale must be a locale tag like "en" or "es_AR"')
    locales = translations["locales"]
    if (
        not isinstance(locales, list)
        or not locales
        or any(not isinstance(locale, str) or not LOCALE_TAG.fullmatch(locale) for locale in locales)
        or len(locales) != len(set(locales))
    ):
        raise ValidationError('translations.locales must be a non-empty list of unique locale tags like "es" or "es_AR"')
    directory = translations.get("directory", "translations")
    directory = _safe_relative(directory, "translations.directory")
    if directory.endswith("/"):
        raise ValidationError("translations.directory must not end with '/'")
    for locale in locales:
        catalog = f"{directory}/{locale}.json"
        if catalog not in safe_files:
            raise ValidationError(
                f"translations declares locale {locale!r} but files does not list "
                f"{catalog!r} (ship one JSON catalog per declared locale and list it in files)"
            )
    return directory, locales


def _validate_translation_catalogs(
    root: Path,
    declaration: tuple[str, list[str]] | None,
    qml_files: list[Path],
) -> None:
    if declaration is None:
        return
    directory, locales = declaration
    used: set[str] = set()
    for path in qml_files:
        source = path.read_text(encoding="utf-8")
        used.update(_unescape_qml_string(raw) for raw in TR_LITERAL.findall(source))

    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValidationError(f"translation catalog contains duplicate key {key!r}")
            result[key] = value
        return result

    for locale in locales:
        relative = f"{directory}/{locale}.json"
        catalog_path = root / relative
        try:
            catalog = json.loads(
                catalog_path.read_text(encoding="utf-8"), object_pairs_hook=unique_object
            )
        except (OSError, json.JSONDecodeError) as error:
            raise ValidationError(f"{relative} is not readable JSON: {error}") from error
        if not isinstance(catalog, dict):
            raise ValidationError(f"{relative} must be a JSON object mapping source strings to translations")
        for source_text, translated in catalog.items():
            if not source_text.strip() or len(source_text) > 4000:
                raise ValidationError(f"{relative} contains an empty or overlong source string key")
            if not isinstance(translated, str) or not translated.strip() or len(translated) > 4000:
                raise ValidationError(
                    f"{relative} entry for {source_text!r} must be a non-empty translated string "
                    "(omit untranslated strings instead of shipping them empty)"
                )
            if set(PLACEHOLDER.findall(source_text)) != set(PLACEHOLDER.findall(translated)):
                raise ValidationError(
                    f"{relative} entry for {source_text!r} must keep the same %1/%2 placeholders "
                    "as the source string"
                )
        untranslated = sorted(used - set(catalog))
        if untranslated:
            raise ValidationError(
                f"{relative} is missing translations for strings passed to Translations.tr(): "
                + ", ".join(repr(text) for text in untranslated)
            )


def effective_surfaces(manifest: dict) -> dict[str, dict]:
    """Effective per-surface entry points for an already-valid manifest.

    v1 (or v2 without `surfaces`) yields exactly the one primary
    placement surface, enabled, loading the top-level entrypoint —
    identical to the pre-v2 runtime. Declaring a surface grants no
    privilege; it only names a .qml entrypoint a host may load.
    """
    placement = manifest.get("placement", "background")
    effective: dict[str, dict] = {
        placement: {"entrypoint": manifest["entrypoint"], "enabled": True}
    }
    for name, surface in (manifest.get("surfaces") or {}).items():
        effective[name] = {
            "entrypoint": surface["entrypoint"],
            "enabled": surface.get("enabled", True),
        }
        # Dashboard card hints ride along only where declared, so
        # pre-#378 manifests derive byte-identical effective surfaces.
        if name == "dashboard":
            if "size" in surface:
                effective[name]["size"] = surface["size"]
            if "category" in surface:
                effective[name]["category"] = surface["category"]
    return effective


# Extension settings (shell#374): typed declarations in
# capabilities.settings drive the generated Control Center UI. The
# base type set is boolean, integer, number, string and enum (a
# string restricted to declared `options`). PluginKit 4 adds colour,
# list (multi-select over `options`), text (multi-line string) and
# path (a string the Shell never opens; RFC 0003 section 5.1), plus
# display-only fields (title, group, unit, step, visibleWhen). The
# new types and fields require `"pluginKit": 4` in the manifest.
SETTING_TYPES_V3 = ("boolean", "integer", "number", "string", "enum")
SETTING_TYPES_V4 = ("colour", "list", "text", "path")
SETTING_TYPES = SETTING_TYPES_V3 + SETTING_TYPES_V4
SETTING_STRING_MAX = 4096
SETTING_ENUM_MAX_OPTIONS = 32
SETTING_PATH_MAX = 1024
SETTING_LIST_MAX_ITEMS = 32
# Display-only fields valid on every type; constraints per type below.
SETTING_DISPLAY_ALL = frozenset({"title", "group", "visibleWhen"})
SETTING_DISPLAY_NUMERIC = frozenset({"unit", "step"})
SETTING_FIELDS = {
    "type", "default", "description",
    "minimum", "maximum", "minLength", "maxLength", "options",
    "step", "unit", "title", "group", "visibleWhen",
    "alpha", "minItems", "maxItems", "rows", "kind", "mustExist",
}
SETTING_CONSTRAINTS = {
    "boolean": frozenset(),
    "integer": frozenset({"minimum", "maximum", "step", "unit"}),
    "number": frozenset({"minimum", "maximum", "step", "unit"}),
    "string": frozenset({"minLength", "maxLength"}),
    "enum": frozenset({"options"}),
    "colour": frozenset({"alpha"}),
    "list": frozenset({"options", "minItems", "maxItems"}),
    "text": frozenset({"minLength", "maxLength", "rows"}),
    "path": frozenset({"kind", "mustExist"}),
}
# Fields that exist only from PluginKit 4 on, whatever the type.
SETTING_V4_FIELDS = frozenset({"title", "group", "visibleWhen", "step", "unit"})
PATH_KINDS = ("file", "directory")
COLOUR_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
COLOUR_ALPHA_RE = re.compile(r"^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$")


def _is_finite_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _is_plain_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def setting_value_valid(declaration: dict, value: object) -> bool:
    """Whether `value` satisfies an already-valid setting declaration.

    Mirrors Plugins.settingValueValid in services/Plugins.qml (used by
    the PluginKit Settings facade and the generated settings UI):
    exact type match plus every declared constraint.
    """
    kind = declaration.get("type")
    if kind == "boolean":
        return isinstance(value, bool)
    if kind == "integer":
        if not _is_plain_int(value):
            return False
    elif kind == "number":
        if not _is_finite_number(value):
            return False
    elif kind in ("string", "text"):
        if not isinstance(value, str) or len(value) > SETTING_STRING_MAX:
            return False
        if "minLength" in declaration and len(value) < declaration["minLength"]:
            return False
        if "maxLength" in declaration and len(value) > declaration["maxLength"]:
            return False
        return True
    elif kind == "enum":
        return isinstance(value, str) and value in declaration.get("options", [])
    elif kind == "colour":
        pattern = COLOUR_ALPHA_RE if declaration.get("alpha") is True else COLOUR_RE
        return isinstance(value, str) and pattern.fullmatch(value) is not None
    elif kind == "list":
        if not isinstance(value, list) or len(value) != len(set(map(str, value))):
            return False
        options = declaration.get("options", [])
        if any(not isinstance(item, str) or item not in options for item in value):
            return False
        return declaration.get("minItems", 0) <= len(value) <= declaration.get("maxItems", len(options))
    elif kind == "path":
        return (
            isinstance(value, str)
            and len(value) <= SETTING_PATH_MAX
            and not any(ord(char) < 32 or ord(char) == 127 for char in value)
        )
    else:
        return False
    # integer / number range constraints
    if "minimum" in declaration and value < declaration["minimum"]:
        return False
    if "maximum" in declaration and value > declaration["maximum"]:
        return False
    return True


def migrated_setting_value(declaration: dict, stored: object) -> object:
    """Effective value for a stored setting under the current declaration.

    Migration rule (shell#374): a stored value written under an older
    manifest keeps working unchanged while it still satisfies the
    current declaration; anything else — changed type, removed enum
    option, tightened range/length, malformed shape — falls back to
    the declared default instead of crashing or being coerced.
    """
    return stored if setting_value_valid(declaration, stored) else declaration["default"]


def _validate_setting(key: str, setting: dict) -> None:
    where = f"capabilities.settings.{key}"
    unknown = set(setting) - SETTING_FIELDS
    if unknown:
        raise ValidationError(
            f"{where} contains unknown fields: {', '.join(sorted(unknown))} "
            "(a setting declares type, default, optional description and "
            "the constraints for its type)"
        )
    if not {"type", "default"} <= set(setting):
        raise ValidationError(f"setting {key} must contain type and default, with optional description")
    kind = setting["type"]
    if kind not in SETTING_TYPES:
        raise ValidationError(
            f"setting {key} type must be one of: {', '.join(SETTING_TYPES)} "
            f"(got {kind!r}; settings are plain Shell-owned values — a path "
            "setting is a string the Shell never opens)"
        )
    allowed_extra = SETTING_CONSTRAINTS[kind] | SETTING_DISPLAY_ALL
    misplaced = (set(setting) - {"type", "default", "description"}) - allowed_extra
    if misplaced:
        raise ValidationError(
            f"setting {key} of type {kind} cannot declare "
            f"{', '.join(sorted(misplaced))} (allowed fields for "
            f"{kind}: {', '.join(sorted(allowed_extra))})"
        )
    if "description" in setting:
        _string(setting["description"], f"setting {key} description", 160)
    if "title" in setting:
        _string(setting["title"], f"setting {key} title", 48)
    if "group" in setting:
        _string(setting["group"], f"setting {key} group", 32)
    if "unit" in setting:
        _string(setting["unit"], f"setting {key} unit", 8)
    if "step" in setting:
        step = setting["step"]
        if not _is_finite_number(step) or step <= 0 or (kind == "integer" and not _is_plain_int(step)):
            raise ValidationError(
                f"setting {key} step must be a positive "
                f"{'integer' if kind == 'integer' else 'number'}"
            )

    if kind == "integer":
        for bound in ("minimum", "maximum"):
            if bound in setting and not _is_plain_int(setting[bound]):
                raise ValidationError(f"setting {key} {bound} must be an integer")
    if kind == "number":
        for bound in ("minimum", "maximum"):
            if bound in setting and not _is_finite_number(setting[bound]):
                raise ValidationError(f"setting {key} {bound} must be a finite number")
    if kind in ("integer", "number"):
        if (
            "minimum" in setting and "maximum" in setting
            and setting["minimum"] > setting["maximum"]
        ):
            raise ValidationError(f"setting {key} minimum must not exceed maximum")
    if kind in ("string", "text"):
        for bound in ("minLength", "maxLength"):
            if bound in setting and (
                not _is_plain_int(setting[bound])
                or not 0 <= setting[bound] <= SETTING_STRING_MAX
            ):
                raise ValidationError(
                    f"setting {key} {bound} must be an integer between 0 and {SETTING_STRING_MAX}"
                )
        if (
            "minLength" in setting and "maxLength" in setting
            and setting["minLength"] > setting["maxLength"]
        ):
            raise ValidationError(f"setting {key} minLength must not exceed maxLength")
    if kind == "text" and "rows" in setting and (
        not _is_plain_int(setting["rows"]) or not 1 <= setting["rows"] <= 12
    ):
        raise ValidationError(f"setting {key} rows must be an integer between 1 and 12")
    if kind in ("enum", "list"):
        options = setting.get("options")
        if not isinstance(options, list) or not options or len(options) > SETTING_ENUM_MAX_OPTIONS:
            raise ValidationError(
                f"setting {key} of type {kind} must declare options: a list of "
                f"1 to {SETTING_ENUM_MAX_OPTIONS} allowed values"
            )
        if any(not isinstance(option, str) or not option or len(option) > 64 for option in options):
            raise ValidationError(f"setting {key} options must be non-empty strings of at most 64 characters")
        if len(options) != len(set(options)):
            raise ValidationError(f"setting {key} options must not contain duplicates")
    if kind == "list":
        for bound in ("minItems", "maxItems"):
            if bound in setting and (
                not _is_plain_int(setting[bound])
                or not 0 <= setting[bound] <= len(setting["options"])
            ):
                raise ValidationError(
                    f"setting {key} {bound} must be an integer between 0 and the number of options"
                )
        if "minItems" in setting and "maxItems" in setting and setting["minItems"] > setting["maxItems"]:
            raise ValidationError(f"setting {key} minItems must not exceed maxItems")
    if kind == "colour" and "alpha" in setting and not isinstance(setting["alpha"], bool):
        raise ValidationError(f"setting {key} alpha must be a boolean")
    if kind == "path":
        if "kind" in setting and setting["kind"] not in PATH_KINDS:
            raise ValidationError(f"setting {key} kind must be one of: {', '.join(PATH_KINDS)}")
        if "mustExist" in setting and not isinstance(setting["mustExist"], bool):
            raise ValidationError(f"setting {key} mustExist must be a boolean")
        default = setting["default"]
        if isinstance(default, str) and default != "":
            pure = PurePosixPath(default)
            if (
                default.startswith(("/", "~"))
                or ".." in pure.parts
                or "\\" in default
            ):
                raise ValidationError(
                    f"setting {key} default must be empty or a safe relative path "
                    "(no leading / or ~, no ..): the Shell never ships a default "
                    "pointing outside the user's own directories"
                )

    if not setting_value_valid(setting, setting["default"]):
        raise ValidationError(
            f"setting {key} default does not match its declared type or constraints"
        )


def settings_need_level(settings: dict) -> int:
    """PluginKit level the declared settings require (3 or 4)."""
    for setting in settings.values():
        if (
            isinstance(setting, dict)
            and (setting.get("type") in SETTING_TYPES_V4 or SETTING_V4_FIELDS & set(setting))
        ):
            return 4
    return 3


def _validate_visible_when(settings: dict) -> None:
    """visibleWhen references: known sibling, matching value, no cycles."""
    for key, setting in settings.items():
        if "visibleWhen" not in setting:
            continue
        where = f"setting {key} visibleWhen"
        condition = _object(setting["visibleWhen"], where)
        if set(condition) != {"key", "equals"}:
            raise ValidationError(f"{where} must be exactly {{\"key\": <setting>, \"equals\": <value>}}")
        target = condition["key"]
        if target == key:
            raise ValidationError(f"{where} must not reference the setting itself")
        if not isinstance(target, str) or target not in settings:
            raise ValidationError(f"{where} references unknown setting {target!r}")
        if not setting_value_valid(settings[target], condition["equals"]):
            raise ValidationError(
                f"{where} equals value does not satisfy setting {target}'s declaration"
            )
    for key in settings:
        seen = {key}
        current = key
        while "visibleWhen" in settings[current]:
            current = settings[current]["visibleWhen"]["key"]
            if current in seen:
                raise ValidationError(f"setting {key} visibleWhen forms a cycle")
            seen.add(current)


# Marketplace metadata (shell#379): static discovery/detail data the
# Extensions pane renders WITHOUT executing plugin code — screenshots
# are plain image files shipped in the package (never QML, SVG or
# animated formats the shell would have to interpret), plus declared
# shell compatibility, a short version history, and a deprecation /
# replaced-by state. Optional in every schema version; declaring it
# grants no privilege and changes no lifecycle: install, update and
# rollback still go through the existing horneroctl verified
# provenance contracts only (shell#251/#366).
MARKETPLACE_SCREENSHOT_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")
MARKETPLACE_MAX_SCREENSHOTS = 6
MARKETPLACE_MAX_CHANGELOG = 20


def _semver_key(version: str) -> tuple:
    core, _, prerelease = version.split("+", 1)[0].partition("-")
    numbers = tuple(int(part) for part in core.split("."))
    # A release outranks any prerelease of the same core; prerelease
    # identifiers compare dot-by-dot (numeric identifiers numerically).
    if not prerelease:
        return (numbers, (1,))
    parts = tuple(
        (0, int(part), "") if part.isdigit() else (1, 0, part)
        for part in prerelease.split(".")
    )
    return (numbers, (0,) + parts)


# Theme templates (RFC 0002 §12.2, HorneroOS/plugins#70): optional in every
# schema version. An extension may ship plain-text templates that
# horneroctl renders from the live palette whenever it changes. The
# extension never runs anything on a palette change: output paths are fixed
# by the host to ${XDG_CACHE_HOME}/hornero/themes/ext/<id>/<output>, so
# `output` is only a file name (no directory, no dots-only, no hidden file).
THEME_MAX_TEMPLATES = 8
THEME_OUTPUT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
THEME_ROLES = (
    "ground", "sunken", "base", "panel", "raised", "lifted", "ink", "inkMuted",
    "inkFaint", "rule", "ruleStrong", "focus", "signal", "glow", "onSignal",
    "signalWell", "onSignalWell", "cue", "onCue", "cueWell", "onCueWell",
    "phosphor", "onPhosphor", "phosphorWell", "onPhosphorWell", "alert",
    "onAlert", "alertWell", "onAlertWell", "inverse", "onInverse",
    "inverseSignal", "scrim", "shadow",
) + tuple(f"term{i}" for i in range(16))
THEME_FILTERS = ("hex", "bare", "rgb", "r", "g", "b")
THEME_TAG = re.compile(r"\{\{(.*?)\}\}", re.DOTALL)
THEME_VALUE = re.compile(
    r"^(?P<name>[A-Za-z][A-Za-z0-9]*)(?:\.(?P<filter>[a-z]+)(?:\s+(?P<alpha>[0-9]*\.?[0-9]+))?)?$"
)
THEME_MAX_TEMPLATE_BYTES = 64 * 1024


def _validate_theme(manifest: dict, safe_files: set[str]) -> list[dict]:
    if "theme" not in manifest:
        return []
    theme = _object(manifest["theme"], "theme")
    extra = set(theme) - {"templates"}
    if extra:
        raise ValidationError(f"theme contains unknown fields: {', '.join(sorted(extra))} (theme names only templates)")
    templates = theme.get("templates")
    if not isinstance(templates, list) or not templates or len(templates) > THEME_MAX_TEMPLATES:
        raise ValidationError(f"theme.templates must be a list of 1 to {THEME_MAX_TEMPLATES} entries")
    seen_outputs: set[str] = set()
    seen_templates: set[str] = set()
    result = []
    for index, raw in enumerate(templates):
        where = f"theme.templates[{index}]"
        entry = _object(raw, where)
        if set(entry) != {"template", "output"}:
            raise ValidationError(f"{where} must have exactly template and output")
        template = _safe_relative(entry["template"], f"{where}.template")
        if not template.endswith(".tmpl"):
            raise ValidationError(f"{where}.template must be a .tmpl file")
        if template not in safe_files:
            raise ValidationError(f"{where}.template must be listed in files")
        output = entry["output"]
        if not isinstance(output, str) or not THEME_OUTPUT.match(output) or ".." in output:
            raise ValidationError(
                f"{where}.output must be a plain file name (letters, digits, dot, dash, underscore; "
                "no directory, absolute path or '..'): the host writes it under the extension's own "
                "cache directory"
            )
        if output in seen_outputs:
            raise ValidationError(f"{where}.output duplicates another template output: {output}")
        if template in seen_templates:
            raise ValidationError(f"{where}.template is declared twice: {template}")
        seen_outputs.add(output)
        seen_templates.add(template)
        result.append({"template": template, "output": output})
    return result


def _check_theme_template(relative: str, text: str) -> None:
    """Strict grammar of contract §6.4; anything else is rejected with its line."""
    if len(text.encode("utf-8")) > THEME_MAX_TEMPLATE_BYTES:
        raise ValidationError(f"{relative} exceeds {THEME_MAX_TEMPLATE_BYTES} bytes")
    stack: list[str] = []
    for match in THEME_TAG.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        body = match.group(1).strip()
        where = f"{relative}:{line}"
        if body in ("#dark", "#light"):
            stack.append(body[1:])
            continue
        if body in ("/dark", "/light"):
            if not stack or stack.pop() != body[1:]:
                raise ValidationError(f"{where}: unbalanced section {{{{{body}}}}}")
            continue
        value = THEME_VALUE.match(body)
        if not value:
            raise ValidationError(f"{where}: unsupported template expression {{{{{body}}}}}")
        name, flt, alpha = value.group("name", "filter", "alpha")
        if name in ("mode", "id"):
            if flt:
                raise ValidationError(f"{where}: {name} takes no filter")
            continue
        if name not in THEME_ROLES:
            raise ValidationError(f"{where}: unknown palette role {name!r}")
        if flt is None:
            continue
        if flt == "rgba":
            if alpha is None or not 0 <= float(alpha) <= 1:
                raise ValidationError(f"{where}: rgba needs an alpha between 0 and 1")
        elif flt not in THEME_FILTERS or alpha is not None:
            raise ValidationError(f"{where}: unsupported filter {flt!r}")
    if stack:
        raise ValidationError(f"{relative}: section {{{{#{stack[-1]}}}}} is never closed")
    leftover = THEME_TAG.sub("", text)
    if "{{" in leftover or "}}" in leftover:
        line = leftover[: leftover.index("{{" if "{{" in leftover else "}}")].count("\n") + 1
        raise ValidationError(f"{relative}:{line}: stray template delimiter")


def _validate_marketplace(manifest: dict, safe_files: set[str], plugin_id: str) -> None:
    if "marketplace" not in manifest:
        return
    marketplace = _object(manifest["marketplace"], "marketplace")
    extra = set(marketplace) - {"screenshots", "compatibility", "changelog", "deprecation"}
    if extra:
        raise ValidationError(
            f"marketplace contains unknown fields: {', '.join(sorted(extra))} "
            "(marketplace names only screenshots, compatibility, changelog "
            "and deprecation)"
        )
    if not marketplace:
        raise ValidationError(
            "marketplace must declare at least one of screenshots, "
            "compatibility, changelog or deprecation (remove the empty "
            "\"marketplace\": {} instead)"
        )
    if "screenshots" in marketplace:
        screenshots = marketplace["screenshots"]
        if (
            not isinstance(screenshots, list)
            or not screenshots
            or len(screenshots) > MARKETPLACE_MAX_SCREENSHOTS
        ):
            raise ValidationError(
                f"marketplace.screenshots must list 1 to {MARKETPLACE_MAX_SCREENSHOTS} screenshots"
            )
        seen_paths: set[str] = set()
        for index, raw in enumerate(screenshots):
            where = f"marketplace.screenshots[{index}]"
            shot = _object(raw, where)
            shot_extra = set(shot) - {"path", "alt"}
            if shot_extra:
                raise ValidationError(
                    f"{where} contains unknown fields: {', '.join(sorted(shot_extra))} "
                    "(a screenshot names only path and optional alt)"
                )
            if "path" not in shot:
                raise ValidationError(f"{where}.path is required (a static image file shipped in files)")
            path = _safe_relative(shot["path"], f"{where}.path")
            if not path.lower().endswith(MARKETPLACE_SCREENSHOT_SUFFIXES):
                raise ValidationError(
                    f"{where}.path must be a static image ({', '.join(MARKETPLACE_SCREENSHOT_SUFFIXES)}); "
                    "previews are rendered as plain images without executing "
                    "plugin code, so QML/SVG/animated previews are not allowed"
                )
            if path not in safe_files:
                raise ValidationError(
                    f"{where}.path must be listed in files (add {path!r} to files)"
                )
            if path in seen_paths:
                raise ValidationError("marketplace.screenshots must not repeat a path")
            seen_paths.add(path)
            if "alt" in shot:
                _string(shot["alt"], f"{where}.alt", 160)
    if "compatibility" in marketplace:
        compatibility = _object(marketplace["compatibility"], "marketplace.compatibility")
        compat_extra = set(compatibility) - {"minShellVersion", "maxShellVersion"}
        if compat_extra:
            raise ValidationError(
                f"marketplace.compatibility contains unknown fields: "
                f"{', '.join(sorted(compat_extra))} (compatibility names only "
                "minShellVersion and maxShellVersion)"
            )
        if not compatibility:
            raise ValidationError(
                "marketplace.compatibility must declare minShellVersion "
                "and/or maxShellVersion"
            )
        for bound in ("minShellVersion", "maxShellVersion"):
            if bound in compatibility:
                value = _string(compatibility[bound], f"marketplace.compatibility.{bound}", 80)
                if not SEMVER.fullmatch(value):
                    raise ValidationError(
                        f"marketplace.compatibility.{bound} must be semantic versioning"
                    )
        if (
            "minShellVersion" in compatibility
            and "maxShellVersion" in compatibility
            and _semver_key(compatibility["minShellVersion"])
            > _semver_key(compatibility["maxShellVersion"])
        ):
            raise ValidationError(
                "marketplace.compatibility.minShellVersion must not exceed maxShellVersion"
            )
    if "changelog" in marketplace:
        changelog = marketplace["changelog"]
        if (
            not isinstance(changelog, list)
            or not changelog
            or len(changelog) > MARKETPLACE_MAX_CHANGELOG
        ):
            raise ValidationError(
                f"marketplace.changelog must list 1 to {MARKETPLACE_MAX_CHANGELOG} entries "
                "(newest first)"
            )
        seen_versions: set[str] = set()
        for index, raw in enumerate(changelog):
            where = f"marketplace.changelog[{index}]"
            entry = _object(raw, where)
            entry_extra = set(entry) - {"version", "notes"}
            if entry_extra:
                raise ValidationError(
                    f"{where} contains unknown fields: {', '.join(sorted(entry_extra))} "
                    "(a changelog entry names only version and notes)"
                )
            if not {"version", "notes"} <= set(entry):
                raise ValidationError(f"{where} must contain version and notes")
            version = _string(entry["version"], f"{where}.version", 80)
            if not SEMVER.fullmatch(version):
                raise ValidationError(f"{where}.version must be semantic versioning")
            if version in seen_versions:
                raise ValidationError("marketplace.changelog must not repeat a version")
            seen_versions.add(version)
            _string(entry["notes"], f"{where}.notes", 1000)
    if "deprecation" in marketplace:
        deprecation = _object(marketplace["deprecation"], "marketplace.deprecation")
        dep_extra = set(deprecation) - {"message", "replacedBy"}
        if dep_extra:
            raise ValidationError(
                f"marketplace.deprecation contains unknown fields: "
                f"{', '.join(sorted(dep_extra))} (deprecation names only "
                "optional message and replacedBy; its presence alone "
                "already means deprecated)"
            )
        if "message" in deprecation:
            _string(deprecation["message"], "marketplace.deprecation.message", 280)
        if "replacedBy" in deprecation:
            replaced_by = deprecation["replacedBy"]
            if not isinstance(replaced_by, str) or not ID.fullmatch(replaced_by):
                raise ValidationError(
                    "marketplace.deprecation.replacedBy must be a plugin id "
                    "(lowercase letters, digits, and internal hyphens)"
                )
            if replaced_by == plugin_id:
                raise ValidationError(
                    "marketplace.deprecation.replacedBy must not name the "
                    "plugin itself"
                )


def effective_marketplace(manifest: dict) -> dict | None:
    """Normalized marketplace metadata for an already-valid manifest.

    Returns None when the package declares none (the pre-#379 shape,
    which stays valid and renders exactly as before). The returned
    shape mirrors Plugins.normalizeMarketplace in
    services/Plugins.qml: screenshots keep path plus optional alt,
    deprecation presence means deprecated.
    """
    marketplace = manifest.get("marketplace")
    if not isinstance(marketplace, dict) or not marketplace:
        return None
    effective: dict[str, object] = {}
    if "screenshots" in marketplace:
        effective["screenshots"] = [
            {key: shot[key] for key in ("path", "alt") if key in shot}
            for shot in marketplace["screenshots"]
        ]
    if "compatibility" in marketplace:
        effective["compatibility"] = dict(marketplace["compatibility"])
    if "changelog" in marketplace:
        effective["changelog"] = [
            {"version": entry["version"], "notes": entry["notes"]}
            for entry in marketplace["changelog"]
        ]
    if "deprecation" in marketplace:
        effective["deprecation"] = dict(marketplace["deprecation"])
    return effective or None


def _validate_manifest(manifest: dict, root: Path) -> None:
    allowed = {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "homepage", "entrypoint", "files", "capabilities", "placement",
        "signing", "surfaces", "translations", "marketplace", "theme",
        "pluginKit", "contributes",
    }
    unknown = manifest.keys() - allowed
    missing = {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "entrypoint", "files", "capabilities",
    } - manifest.keys()
    if unknown:
        raise ValidationError(
            f"unknown manifest fields: {', '.join(sorted(unknown))} "
            "(unknown fields are rejected, not ignored; see docs/PLUGINS.md)"
        )
    if missing:
        raise ValidationError(f"missing manifest fields: {', '.join(sorted(missing))}")
    if type(manifest["schemaVersion"]) is int and manifest["schemaVersion"] in LEGACY_SCHEMA_VERSIONS:
        raise ValidationError(
            f"schemaVersion {manifest['schemaVersion']} targets the Material-era "
            "PluginKit, which Hornero Signal removed; port the extension to "
            "PluginKit 3 (Theme.palette roles, Hornero Glyph names, glyph/name "
            "icon properties) and set \"schemaVersion\": 3 — see "
            "docs/PLUGINS.md \"Migrating to PluginKit 3\""
        )
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] not in SCHEMA_VERSIONS:
        raise ValidationError(
            f"schemaVersion must be 3 (got {manifest['schemaVersion']!r}); "
            "unknown manifest versions are rejected"
        )
    schema_version = manifest["schemaVersion"]
    # Minimum PluginKit apiLevel the package needs (RFC 0003 section 3).
    # Defaults to 3; features that exist only from level 4 on must be
    # declared, so an author cannot under-declare and ship a package an
    # older kit would half-load.
    declared_level = manifest.get("pluginKit", 3)
    if type(declared_level) is not int or not 3 <= declared_level <= PLUGINKIT_API_LEVEL:
        raise ValidationError(
            f"pluginKit must be an integer between 3 and {PLUGINKIT_API_LEVEL} "
            f"(got {declared_level!r}); a package that needs a newer PluginKit "
            "than this Shell provides is refused rather than half-loaded"
        )
    plugin_id = _string(manifest["id"], "id", 48)
    if not ID.fullmatch(plugin_id):
        raise ValidationError("id must use lowercase letters, digits, and internal hyphens")
    _string(manifest["name"], "name", 64)
    version = _string(manifest["version"], "version", 80)
    if not SEMVER.fullmatch(version):
        raise ValidationError("version must be semantic versioning")
    _string(manifest["description"], "description", 280)
    _string(manifest["author"], "author", 120)
    _string(manifest["license"], "license", 80)

    homepage = manifest.get("homepage")
    if homepage is not None:
        parsed = urlparse(_string(homepage, "homepage", 500))
        if parsed.scheme != "https" or not parsed.netloc:
            raise ValidationError("homepage must be an HTTPS URL")

    placement = manifest.get("placement", "background")
    if placement not in PLACEMENTS:
        raise ValidationError("placement must be background, bar, dashboard or desktop")

    entrypoint = _safe_relative(manifest["entrypoint"], "entrypoint", qml=True)
    files = manifest["files"]
    if not isinstance(files, list) or not files:
        raise ValidationError("files must be a non-empty list of package-owned relative paths")
    safe_files = [_safe_relative(item, "files[]") for item in files]
    if len(safe_files) != len(set(safe_files)):
        raise ValidationError("files must not contain duplicates")
    if entrypoint not in safe_files:
        raise ValidationError("entrypoint must be listed in files")
    if not {"README.md", "LICENSE"} <= set(safe_files):
        raise ValidationError("files must include README.md and LICENSE")

    # Manifest v2 surfaces (shell#373): additive multi-surface entry
    # points. v1 manifests derive exactly one effective surface from
    # placement+entrypoint and load identically; `surfaces` is rejected
    # under v1 so an older host/validator can never silently ignore it.
    _validate_surfaces(manifest, schema_version, placement, entrypoint, set(safe_files))
    # Contributions (RFC 0003): declarative commands, level 4.
    _validate_contributes(manifest, declared_level)

    # Plugin translations (shell#375): optional in every schema
    # version; pre-#375 manifests without the field stay valid.
    translations_declaration = _validate_translations_declaration(manifest, set(safe_files))

    # Marketplace metadata (shell#379): optional in every schema
    # version; pre-#379 manifests without the field stay valid.
    _validate_marketplace(manifest, set(safe_files), plugin_id)

    # Theme templates (RFC 0002, plugins#70): optional in every schema
    # version; rendered by horneroctl only.
    theme_templates = _validate_theme(manifest, set(safe_files))

    capabilities = _object(manifest["capabilities"], "capabilities")
    # `actions` is the optional horneroctl plugin-broker declaration
    # (HorneroOS/hornero#408): snake_case action names the plugin may
    # request through the typed broker. Shape only — catalogue
    # membership and authorization are enforced by the broker at
    # call time, so an unknown name here is inert metadata, while a
    # malformed one fails validation everywhere.
    if not {"processCommands", "networkHosts", "settings"} <= capabilities.keys() <= {
        "processCommands", "networkHosts", "settings", "actions", "providers"
    }:
        raise ValidationError(
            "capabilities must contain processCommands, networkHosts, and settings, "
            "plus optional actions and providers"
        )
    declared_providers: set[str] = set()
    if "providers" in capabilities:
        raw_providers = capabilities["providers"]
        if (
            not isinstance(raw_providers, list)
            or any(item not in PROVIDER_DOMAINS for item in raw_providers)
            or len(set(raw_providers)) != len(raw_providers)
        ):
            raise ValidationError(
                "capabilities.providers must list unique provider domains from: "
                + ", ".join(PROVIDER_DOMAINS)
            )
        declared_providers = set(raw_providers)
    if "actions" in capabilities:
        declared_actions = _string_list(capabilities["actions"], "capabilities.actions", SAFE_ACTION)
        if len(declared_actions) > 32:
            raise ValidationError("capabilities.actions must declare at most 32 actions")
    commands = _string_list(capabilities["processCommands"], "capabilities.processCommands", SAFE_COMMAND)
    if any(Path(command).name != command or command.lower() in FORBIDDEN_COMMANDS for command in commands):
        raise ValidationError("capabilities.processCommands must be executable basenames and cannot name a shell or privilege tool")
    hosts = _string_list(capabilities["networkHosts"], "capabilities.networkHosts", SAFE_HOST)

    settings = _object(capabilities["settings"], "capabilities.settings")
    for key, raw_setting in settings.items():
        if not re.fullmatch(r"[a-z][a-zA-Z0-9]{0,47}", key):
            raise ValidationError(f"invalid setting id: {key}")
        _validate_setting(key, _object(raw_setting, f"capabilities.settings.{key}"))
    _validate_visible_when(settings)
    if settings_need_level(settings) > declared_level:
        raise ValidationError(
            "capabilities.settings uses PluginKit 4 features (colour, list, "
            "text or path settings, or title/group/unit/step/visibleWhen); "
            'declare "pluginKit": 4 in the manifest'
        )

    actual: set[str] = set()
    qml_files: list[Path] = []
    for path in root.rglob("*"):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise ValidationError(f"symbolic links are not allowed: {relative}")
        if path.is_dir():
            continue
        if relative == "manifest.json":
            continue
        if not path.is_file():
            raise ValidationError(f"unsupported file type: {relative}")
        mode = path.stat().st_mode
        if mode & (stat.S_ISUID | stat.S_ISGID | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH | stat.S_IWOTH):
            raise ValidationError(f"setuid, setgid, executable, or world-writable plugin files are not allowed: {relative}")
        if path.suffix.lower() in {".so", ".dll", ".dylib", ".exe", ".pyc", ".qm"}:
            raise ValidationError(f"compiled or bytecode files are not allowed: {relative}")
        actual.add(relative)
        if path.suffix == ".qml":
            qml_files.append(path)
    if actual != set(safe_files):
        missing_files = sorted(actual - set(safe_files))
        absent = sorted(set(safe_files) - actual)
        detail = []
        if missing_files:
            detail.append(f"unlisted files: {', '.join(missing_files)}")
        if absent:
            detail.append(f"missing files: {', '.join(absent)}")
        raise ValidationError("manifest files must exactly match package contents (excluding manifest.json): " + "; ".join(detail))

    _validate_translation_catalogs(root, translations_declaration, qml_files)
    for entry in theme_templates:
        _check_theme_template(entry["template"], (root / entry["template"]).read_text(encoding="utf-8"))

    desktop_surface = (manifest.get("surfaces") or {}).get("desktop") or {}
    if desktop_surface.get("instances") is True:
        # An extension that claims per-instance settings must actually
        # read them: its desktop entrypoint declares hostInstanceId and
        # passes it to Settings.instanceId, otherwise a second instance
        # would silently share the first one's state.
        entry_source = (root / desktop_surface["entrypoint"]).read_text(encoding="utf-8")
        if "hostInstanceId" not in entry_source or not re.search(r"\binstanceId\s*:", entry_source):
            raise ValidationError(
                "surfaces.desktop.instances is true but the desktop entrypoint does not "
                "read its instance: declare `property string hostInstanceId: \"\"` on the "
                "root and bind `Settings { pluginId: ...; instanceId: root.hostInstanceId }`"
            )

    commands_surface = (manifest.get("surfaces") or {}).get("commands")
    if commands_surface:
        command_source = (root / commands_surface["entrypoint"]).read_text(encoding="utf-8")
        if not re.search(r"\bfunction\s+run\s*\(", command_source):
            raise ValidationError(
                "surfaces.commands entrypoint must implement "
                "`function run(commandId: string, args: string): string` "
                "(return an empty string on success or a short error)"
            )

    for path in qml_files:
        source = path.read_text(encoding="utf-8")
        for imported in IMPORT.findall(source):
            if imported not in ALLOWED_IMPORTS:
                raise ValidationError(f"{path.relative_to(root)} imports unsupported module {imported}")
        for marker in FORBIDDEN_MARKERS:
            if marker.search(source):
                raise ValidationError(f"{path.relative_to(root)} contains a forbidden shell, privilege, or host-path pattern")
        commands_used = PROCESS_COMMAND.findall(source)
        process_count = len(re.findall(r"\bProcess\s*\{", source))
        if process_count != len(commands_used):
            raise ValidationError(f"{path.relative_to(root)} Process must use a literal argv array command")
        for executable in commands_used:
            basename = Path(executable).name
            if basename != executable or basename in FORBIDDEN_COMMANDS or basename not in commands:
                raise ValidationError(f"{path.relative_to(root)} invokes undeclared or disallowed command {executable!r}")
        if re.search(r"\b(?:XMLHttpRequest|WebSocket|NetworkRequest|TcpSocket)\b", source) and not hosts:
            raise ValidationError(f"{path.relative_to(root)} uses network APIs but declares no networkHosts")
        if QSTR_CALL.search(source):
            raise ValidationError(
                f"{path.relative_to(root)} uses qsTr(), which is never translated for plugins "
                "(the shell installs no QTranslator for extension catalogs); use PluginKit "
                "Translations { pluginId: ... } and tr() instead — see docs/PLUGINS.md"
            )
        _check_signal_contract(path.relative_to(root), source)
        _check_providers(path.relative_to(root), source, declared_providers)
        for host in URL_LITERAL.findall(source):
            hostname = host.split(":", 1)[0].lower()
            if hostname not in {item.lower() for item in hosts}:
                raise ValidationError(f"{path.relative_to(root)} contains an undeclared network host {hostname}")


# PluginKit 3 (Hornero Signal) source contract. Material-era names fail
# with the replacement spelled out, so a port is mechanical.
LEGACY_THEME = {
    "primary": "Theme.palette.signal",
    "onPrimary": "Theme.palette.onSignal",
    "primaryContainer": "Theme.palette.signalWell",
    "onPrimaryContainer": "Theme.palette.onSignalWell",
    "secondary": "Theme.palette.cue",
    "onSecondary": "Theme.palette.onCue",
    "secondaryContainer": "Theme.palette.cueWell",
    "onSecondaryContainer": "Theme.palette.onCueWell",
    "tertiary": "Theme.palette.phosphor",
    "onTertiary": "Theme.palette.onPhosphor",
    "tertiaryContainer": "Theme.palette.phosphorWell",
    "onTertiaryContainer": "Theme.palette.onPhosphorWell",
    "success": "Theme.palette.phosphor",
    "error": "Theme.palette.alert",
    "onError": "Theme.palette.onAlert",
    "errorContainer": "Theme.palette.alertWell",
    "onErrorContainer": "Theme.palette.onAlertWell",
    "background": "Theme.palette.ground",
    "onBackground": "Theme.palette.ink",
    "surface": "Theme.palette.base",
    "surfaceDim": "Theme.palette.ground",
    "surfaceBright": "Theme.palette.lifted",
    "surfaceVariant": "Theme.palette.raised",
    "surfaceContainerLowest": "Theme.palette.ground",
    "surfaceContainerLow": "Theme.palette.sunken",
    "surfaceContainer": "Theme.palette.panel",
    "surfaceContainerHigh": "Theme.palette.raised",
    "surfaceContainerHighest": "Theme.palette.lifted",
    "onSurface": "Theme.palette.ink",
    "onSurfaceVariant": "Theme.palette.inkMuted",
    "outline": "Theme.palette.ruleStrong",
    "outlineVariant": "Theme.palette.rule",
    "componentBorder": "Theme.palette.ruleStrong",
    "focusRing": "Theme.palette.focus",
    "fontFamily": "Theme.font.family.sans",
    "monoFontFamily": "Theme.font.family.mono",
    "iconFontFamily": "UiIcon",
    "fontSize": "Theme.font.size.normal",
    "fontSizeSmall": "Theme.font.size.small",
    "fontSizeBody": "Theme.font.size.smaller",
    "fontSizeTitle": "Theme.font.size.larger",
    "fontSizeLarge": "Theme.font.size.large",
    "fontSizeDisplay": "Theme.font.size.extraLarge",
    "iconSize": "Theme.font.size.larger",
    "iconSizeLarge": "Theme.font.size.large",
    "spacingSmall": "Theme.spacing.small",
    "spacingLarge": "Theme.spacing.large",
    "paddingLarge": "Theme.padding.large",
    "roundingSmall": "Theme.rounding.small",
    "roundingLarge": "Theme.rounding.large",
    "durationSmall": "Theme.duration(\"short\")",
    "durationNormal": "Theme.duration(\"medium\")",
    "durationExpressiveFastSpatial": "Theme.duration(\"settleFast\")",
    "curveStandard": "Theme.anim.curves.standard",
    "curveStandardDecel": "Theme.anim.curves.enter",
    "curveExpressiveFastSpatial": "Theme.anim.curves.settleFast",
    "animationScale": "Theme.duration(name)",
    "motionDuration": "Theme.duration(name)",
    "stateHoverOpacity": "the Signal hover fill (Theme.palette.raised)",
    "statePressedOpacity": "the Signal pressed fill (Theme.palette.lifted)",
}
# Flat tokens that became groups: Theme.spacing → Theme.spacing.normal.
LEGACY_FLAT = {
    "spacing": "Theme.spacing.<small|smaller|normal|larger|large>",
    "padding": "Theme.padding.<small|smaller|normal|larger|large>",
    "rounding": "Theme.rounding.<small|normal|large>",
}
LEGACY_THEME_RE = re.compile(r"\bTheme\.([A-Za-z]+)\b(?!\s*\.)")
LEGACY_PROPERTIES = {
    "iconName": "glyph",
    "trailingIconName": "trailingGlyph",
    "iconFill": None,
}
LEGACY_PROPERTY_RE = re.compile(r"\b(iconName|trailingIconName|iconFill)\s*:")
ICON_FILL_RE = re.compile(r"(?<![.\w])fill\s*:\s*(?:[01](?:\.0)?\s*(?:$|;|\n)|[^\n;]*\?\s*1\s*:\s*0)")
UI_ICON_BLOCK = re.compile(r"\bUiIcon\s*\{([^{}]*)\}")
UI_ICON_LEGACY_ICON = re.compile(r"(?<![.\w])icon\s*:")
GLYPH_ASSIGNMENT = re.compile(r"\b(?:glyph|trailingGlyph)\s*:\s*([^\n]+)")
UI_ICON_NAME = re.compile(r"(?<![.\w])name\s*:\s*([^\n]+)")
STRING_LITERAL = re.compile(r'"([^"\\]*)"')
SUBSCRIPTION_DOMAIN = re.compile(r"\bSubscription\s*\{[^{}]*?\bdomain\s*:\s*\"([a-z]+)\"", re.DOTALL)
FACADE_USE = re.compile(r"(?<![.\w])(System|Telemetry|Network|Media|Audio|Power|Weather|Time|Workspaces)\.[a-zA-Z]")
SPECTRUM_USE = re.compile(r"(?<![.\w])Audio\.spectrum\b")
_GLYPH_NAMES: set[str] | None = None


def glyph_names() -> set[str]:
    """Hornero Glyph names (the shell's assets/fonts/hornero-glyphs.names)."""
    global _GLYPH_NAMES
    if _GLYPH_NAMES is None:
        names: set[str] = set()
        if GLYPH_NAMES_FILE.is_file():
            for line in GLYPH_NAMES_FILE.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    names.add(line)
        _GLYPH_NAMES = names
    return _GLYPH_NAMES


def _strip_comments(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", source)


def _check_glyph_literal(where: PurePosixPath | Path, value: str) -> None:
    if not value:
        return
    names = glyph_names()
    if "_" in value or (names and value not in names):
        hint = (
            "it looks like a Material-era icon ligature; Hornero Glyphs use Tabler "
            "outline names with hyphens (e.g. \"player-play\", \"alert-triangle\")"
            if "_" in value
            else "it is not a Hornero Glyph"
        )
        raise ValidationError(
            f"{where} uses glyph {value!r}: {hint} — pick a name from the shell's "
            "assets/fonts/hornero-glyphs.names (docs/PLUGINS.md, glyphs)"
        )


def _check_signal_contract(where: PurePosixPath | Path, raw_source: str) -> None:
    """Reject Material-era PluginKit API with the PluginKit 3 replacement."""
    source = _strip_comments(raw_source)
    for match in LEGACY_THEME_RE.finditer(source):
        name = match.group(1)
        if name in LEGACY_THEME:
            raise ValidationError(
                f"{where} uses Theme.{name}, a Material-era token removed in "
                f"PluginKit 3; use {LEGACY_THEME[name]} (docs/PLUGINS.md "
                "\"Migrating to PluginKit 3\")"
            )
        if name in LEGACY_FLAT:
            raise ValidationError(
                f"{where} uses Theme.{name} as a number; PluginKit 3 tokens are "
                f"groups: {LEGACY_FLAT[name]}"
            )
    for match in LEGACY_PROPERTY_RE.finditer(source):
        name = match.group(1)
        replacement = LEGACY_PROPERTIES[name]
        if replacement is None:
            raise ValidationError(
                f"{where} sets {name}: Hornero Glyphs are outline-only and have "
                "no fill axis; remove it (state belongs in colour or an on-air "
                "chip, docs/PLUGINS.md)"
            )
        raise ValidationError(
            f"{where} sets {name}: PluginKit 3 renamed it to {replacement} "
            "and it takes a Hornero Glyph name"
        )
    if re.search(r"(?m)^\s*icon\s*:", source):
        raise ValidationError(
            f"{where} sets an icon property: PluginKit 3 renamed it (UiIcon.name; glyph on "
            "UiCard, UiButton, UiChip, UiDetailRow and UiActionRow)"
        )
    if ICON_FILL_RE.search(source):
        raise ValidationError(
            f"{where} sets a Material icon fill axis (fill: 0/1); Hornero Glyphs "
            "are outline-only — remove it"
        )
    for block in UI_ICON_BLOCK.finditer(source):
        body = block.group(1)
        if UI_ICON_LEGACY_ICON.search(body):
            raise ValidationError(
                f"{where} sets UiIcon.icon: PluginKit 3 renamed it to name "
                "(UiIcon { name: \"clock\" }, like the shell's Glyph)"
            )
        for value in UI_ICON_NAME.findall(body):
            for literal in STRING_LITERAL.findall(value):
                _check_glyph_literal(where, literal)
    for value in GLYPH_ASSIGNMENT.findall(source):
        for literal in STRING_LITERAL.findall(value):
            _check_glyph_literal(where, literal)


def _check_providers(where: PurePosixPath | Path, raw_source: str, declared: set[str]) -> None:
    """Every shared provider domain the QML reads must be declared."""
    source = _strip_comments(raw_source)
    for domain in SUBSCRIPTION_DOMAIN.findall(source):
        if domain not in PROVIDER_DOMAINS:
            raise ValidationError(f"{where} subscribes to unknown provider domain {domain!r}")
        if domain not in declared:
            raise ValidationError(
                f"{where} subscribes to provider {domain!r} but capabilities.providers "
                "does not declare it"
            )
    for facade in set(FACADE_USE.findall(source)):
        needed = FACADE_DOMAINS[facade]
        if not declared.intersection(needed):
            raise ValidationError(
                f"{where} reads the {facade} facade but capabilities.providers declares "
                f"none of: {', '.join(needed)}"
            )
    if SPECTRUM_USE.search(source) and "spectrum" not in declared:
        raise ValidationError(
            f"{where} reads Audio.spectrum but capabilities.providers does not declare \"spectrum\""
        )


MOUSE_CLICK = re.compile(r"\bMouseArea\b")
CLICK_HANDLER = re.compile(r"\bon(?:Clicked|DoubleClicked|PressAndHold)\s*:")
A11Y_EVIDENCE = (
    "Accessible.",
    "accessibleName",
    "Keys.on",
    "activeFocusOnTab",
    "KeyNavigation",
)


def accessibility_warnings(root: Path) -> list[str]:
    """Keyboard/focus contract warnings (#376), never hard failures.

    Shipped plugins predate the contract, so a mouse-only interactive
    surface must not newly fail validation; instead it is reported so
    authors and reviewers can fix it. A QML file that drives an
    action from a MouseArea click handler needs keyboard evidence in
    the same file (an Accessible name/role, a tab stop, or key
    handling), or should use the PluginKit controls (UiButton,
    UiToggle, UiSlider), which carry the contract. Files using those
    controls for their actions need no MouseArea at all.
    """
    warnings: list[str] = []
    if not root.is_dir():
        return warnings
    for path in sorted(root.rglob("*.qml")):
        if path.is_symlink() or not path.is_file():
            continue
        source = path.read_text(encoding="utf-8", errors="ignore")
        # Comments mentioning MouseArea are not mouse-only actions.
        source = re.sub(r"//[^\n]*", "", source)
        if not MOUSE_CLICK.search(source) or not CLICK_HANDLER.search(source):
            continue
        if any(token in source for token in A11Y_EVIDENCE):
            continue
        warnings.append(
            f"{path.relative_to(root)}: MouseArea click action has no "
            "keyboard/accessible evidence in the same file (no Accessible "
            "name/role, activeFocusOnTab, or Keys handling); use a "
            "PluginKit control (UiButton/UiToggle/UiSlider) or add an "
            "Accessible name and role, a tab stop, visible focus, and "
            "Enter/Space activation (docs/PLUGINS.md, accessibility "
            "and keyboard contract)"
        )
    return warnings


TIMER_INTERVAL = re.compile(r"\binterval\s*:\s*(\d+)\b")
POLLING_BUDGET_MS = 1000


def performance_warnings(root: Path) -> list[str]:
    """Excessive-polling diagnostics (#380), never hard failures.

    Plugin QML runs in-process, so the host cannot observe or preempt
    a plugin's internal Timers at runtime. The static half of the
    performance budget therefore flags literal Timer intervals below
    one second so authors and reviewers can switch to a PluginKit
    subscription/facade signal or a longer interval. Bound or
    computed intervals cannot be judged statically and are not
    flagged — this is a review aid, not enforcement (and not a
    sandbox). Runtime load timing/churn budgets live in
    services/Plugins.qml.
    """
    warnings: list[str] = []
    if not root.is_dir():
        return warnings
    for path in sorted(root.rglob("*.qml")):
        if path.is_symlink() or not path.is_file():
            continue
        source = path.read_text(encoding="utf-8", errors="ignore")
        source = re.sub(r"//[^\n]*", "", source)
        for match in TIMER_INTERVAL.finditer(source):
            interval = int(match.group(1))
            if interval < POLLING_BUDGET_MS:
                warnings.append(
                    f"{path.relative_to(root)}: Timer interval {interval}ms is below the "
                    f"{POLLING_BUDGET_MS}ms polling budget; prefer a PluginKit subscription "
                    "or facade signal, or poll at 1s or slower (docs/PLUGINS.md, "
                    "diagnostics and performance budget)"
                )
    return warnings


def validate_plugin(root: Path) -> None:
    if not root.is_dir():
        raise ValidationError("plugin path must be a directory")
    manifest_path = root / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValidationError("plugin directory must contain a regular manifest.json")
    manifest_mode = manifest_path.stat().st_mode
    if manifest_mode & (stat.S_ISUID | stat.S_ISGID | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH | stat.S_IWOTH):
        raise ValidationError("manifest.json cannot be executable, setuid, setgid, or world-writable")
    try:
        def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
            result: dict[str, object] = {}
            for key, value in pairs:
                if key in result:
                    raise ValidationError(f"manifest contains duplicate key {key!r}")
                result[key] = value
            return result

        manifest = json.loads(
            manifest_path.read_text(encoding="utf-8"), object_pairs_hook=unique_object
        )
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot read manifest.json: {error}") from error
    _validate_manifest(_object(manifest, "manifest"), root.resolve())
    _validate_payload_size(root.resolve())


# Payload size budget. In-process QML cannot be preempted, so an oversized
# source file is a start-up cost for every session that enables it; the
# largest official extension source is about 12 KiB.
MAX_SOURCE_FILE_BYTES = 256 * 1024
MAX_PAYLOAD_BYTES = 8 * 1024 * 1024


def _validate_payload_size(root: Path) -> None:
    total = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        size = path.stat().st_size
        total += size
        if path.suffix in (".qml", ".js", ".json") and size > MAX_SOURCE_FILE_BYTES:
            raise ValidationError(
                f"{path.relative_to(root)} is {size // 1024} KiB; source files are limited to "
                f"{MAX_SOURCE_FILE_BYTES // 1024} KiB (split or trim it)"
            )
    if total > MAX_PAYLOAD_BYTES:
        raise ValidationError(
            f"package is {total // (1024 * 1024)} MiB; extensions are limited to {MAX_PAYLOAD_BYTES // (1024 * 1024)} MiB"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin_dir", type=Path, nargs="?", help="directory containing manifest.json and the plugin files")
    parser.add_argument(
        "--info",
        action="store_true",
        help="print this validator's supported manifest schema versions and PluginKit API level as JSON, then exit "
        "(horneroctl uses it to pick the validator that matches the running shell)",
    )
    args = parser.parse_args(argv)
    if args.info:
        print(json.dumps({"schemaVersions": list(SCHEMA_VERSIONS), "pluginKit": PLUGINKIT_API_LEVEL}))
        return 0
    if args.plugin_dir is None:
        parser.error("plugin_dir is required unless --info is given")
    try:
        validate_plugin(args.plugin_dir.expanduser().resolve())
    except (OSError, UnicodeError, ValidationError) as error:
        print(f"plugin validation failed: {error}", file=sys.stderr)
        return 1
    print(f"plugin validation passed: {args.plugin_dir}")
    for warning in accessibility_warnings(args.plugin_dir.expanduser().resolve()):
        print(f"accessibility warning: {warning}")
    for warning in performance_warnings(args.plugin_dir.expanduser().resolve()):
        print(f"performance warning: {warning}")
    print("notice: validation is a static review aid; Quickshell plugins are not sandboxed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

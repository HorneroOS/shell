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
PLACEMENTS = ("background", "bar", "dashboard", "desktop")
# Manifest v2 surfaces. The first four have runtime hosts today;
# "launcher" (search/launcher action) and "settings" (Control Center
# settings) are validated declarations reserved for their hosts — no
# host loads them yet, and declaring one grants no privilege.
SURFACES = PLACEMENTS + ("launcher", "settings")
SCHEMA_VERSIONS = (1, 2)
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
    if schema_version != 2:
        raise ValidationError(
            "surfaces requires schemaVersion 2 (set \"schemaVersion\": 2 to declare "
            "multiple surfaces; schemaVersion 1 supports only the single "
            "placement/entrypoint surface)"
        )
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
        surface = _object(raw_surface, where)
        extra = set(surface) - {"entrypoint", "enabled"}
        if extra:
            raise ValidationError(
                f"{where} contains unknown fields: {', '.join(sorted(extra))} "
                "(a surface declares only entrypoint and optional enabled)"
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
    return effective


# Extension settings (shell#374): typed declarations in
# capabilities.settings drive the generated Control Center UI. The
# type set is closed: boolean, integer, number, string and enum (a
# string restricted to declared `options`). There is deliberately no
# path type: settings are plain Shell-owned values, never filesystem
# paths the shell would open, so no setting can escape the user's
# config dirs through this contract.
SETTING_TYPES = ("boolean", "integer", "number", "string", "enum")
SETTING_STRING_MAX = 4096
SETTING_ENUM_MAX_OPTIONS = 32
SETTING_FIELDS = {
    "type", "default", "description",
    "minimum", "maximum", "minLength", "maxLength", "options",
}
SETTING_CONSTRAINTS = {
    "boolean": frozenset(),
    "integer": frozenset({"minimum", "maximum"}),
    "number": frozenset({"minimum", "maximum"}),
    "string": frozenset({"minLength", "maxLength"}),
    "enum": frozenset({"options"}),
}


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
    elif kind == "string":
        if not isinstance(value, str) or len(value) > SETTING_STRING_MAX:
            return False
        if "minLength" in declaration and len(value) < declaration["minLength"]:
            return False
        if "maxLength" in declaration and len(value) > declaration["maxLength"]:
            return False
        return True
    elif kind == "enum":
        return isinstance(value, str) and value in declaration.get("options", [])
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
            f"(got {kind!r}; there is no path-typed setting — settings are "
            "plain Shell-owned values, never filesystem paths)"
        )
    misplaced = (set(setting) - {"type", "default", "description"}) - SETTING_CONSTRAINTS[kind]
    if misplaced:
        raise ValidationError(
            f"setting {key} of type {kind} cannot declare "
            f"{', '.join(sorted(misplaced))} (allowed constraints for "
            f"{kind}: {', '.join(sorted(SETTING_CONSTRAINTS[kind])) or 'none'})"
        )
    if "description" in setting:
        _string(setting["description"], f"setting {key} description", 160)

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
    if kind == "string":
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
    if kind == "enum":
        options = setting.get("options")
        if not isinstance(options, list) or not options or len(options) > SETTING_ENUM_MAX_OPTIONS:
            raise ValidationError(
                f"setting {key} of type enum must declare options: a list of "
                f"1 to {SETTING_ENUM_MAX_OPTIONS} allowed values"
            )
        if any(not isinstance(option, str) or not option or len(option) > 64 for option in options):
            raise ValidationError(f"setting {key} options must be non-empty strings of at most 64 characters")
        if len(options) != len(set(options)):
            raise ValidationError(f"setting {key} options must not contain duplicates")

    if not setting_value_valid(setting, setting["default"]):
        raise ValidationError(
            f"setting {key} default does not match its declared type or constraints"
        )


def _validate_manifest(manifest: dict, root: Path) -> None:
    allowed = {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "homepage", "entrypoint", "files", "capabilities", "placement",
        "signing", "surfaces",
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
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] not in SCHEMA_VERSIONS:
        raise ValidationError(
            f"schemaVersion must be 1 or 2 (got {manifest['schemaVersion']!r}); "
            "unknown manifest versions are rejected"
        )
    schema_version = manifest["schemaVersion"]
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

    capabilities = _object(manifest["capabilities"], "capabilities")
    if capabilities.keys() != {"processCommands", "networkHosts", "settings"}:
        raise ValidationError("capabilities must contain exactly processCommands, networkHosts, and settings")
    commands = _string_list(capabilities["processCommands"], "capabilities.processCommands", SAFE_COMMAND)
    if any(Path(command).name != command or command.lower() in FORBIDDEN_COMMANDS for command in commands):
        raise ValidationError("capabilities.processCommands must be executable basenames and cannot name a shell or privilege tool")
    hosts = _string_list(capabilities["networkHosts"], "capabilities.networkHosts", SAFE_HOST)

    settings = _object(capabilities["settings"], "capabilities.settings")
    for key, raw_setting in settings.items():
        if not re.fullmatch(r"[a-z][a-zA-Z0-9]{0,47}", key):
            raise ValidationError(f"invalid setting id: {key}")
        _validate_setting(key, _object(raw_setting, f"capabilities.settings.{key}"))

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
        if path.suffix.lower() in {".so", ".dll", ".dylib", ".exe", ".pyc"}:
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
        for host in URL_LITERAL.findall(source):
            hostname = host.split(":", 1)[0].lower()
            if hostname not in {item.lower() for item in hosts}:
                raise ValidationError(f"{path.relative_to(root)} contains an undeclared network host {hostname}")


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin_dir", type=Path, help="directory containing manifest.json and the plugin files")
    args = parser.parse_args(argv)
    try:
        validate_plugin(args.plugin_dir.expanduser().resolve())
    except (OSError, UnicodeError, ValidationError) as error:
        print(f"plugin validation failed: {error}", file=sys.stderr)
        return 1
    print(f"plugin validation passed: {args.plugin_dir}")
    for warning in accessibility_warnings(args.plugin_dir.expanduser().resolve()):
        print(f"accessibility warning: {warning}")
    print("notice: validation is a static review aid; Quickshell plugins are not sandboxed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

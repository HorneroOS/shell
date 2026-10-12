#!/usr/bin/env python3
"""Validate a Hornero Shell extension's manifest and conservative source rules.

This validator is a review aid. Quickshell extensions run with the user's
permissions and are not sandboxed; passing validation is not a safety proof.
"""

from __future__ import annotations

import argparse
import json
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
ALLOWED_IMPORTS = (
    "QtQuick",
    "QtQuick.Controls",
    "QtQuick.Layouts",
    "QtQml",
    "Quickshell",
    "Quickshell.Io",
    "Hornero.PluginKit",
    "Hornero.PluginKit.Singletons",
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


def _validate_manifest(manifest: dict, root: Path) -> None:
    allowed = {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "homepage", "entrypoint", "files", "capabilities",
    }
    unknown = manifest.keys() - allowed
    missing = {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "entrypoint", "files", "capabilities",
    } - manifest.keys()
    if unknown:
        raise ValidationError(f"unknown manifest fields: {', '.join(sorted(unknown))}")
    if missing:
        raise ValidationError(f"missing manifest fields: {', '.join(sorted(missing))}")
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1:
        raise ValidationError("schemaVersion must be 1")
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
        setting = _object(raw_setting, f"capabilities.settings.{key}")
        if set(setting) - {"type", "default", "description"} or not {"type", "default"} <= set(setting):
            raise ValidationError(f"setting {key} must contain type and default, with optional description")
        kind, default = setting["type"], setting["default"]
        valid = {
            "boolean": lambda x: isinstance(x, bool),
            "integer": lambda x: isinstance(x, int) and not isinstance(x, bool),
            "number": lambda x: isinstance(x, (int, float)) and not isinstance(x, bool),
            "string": lambda x: isinstance(x, str),
        }
        if kind not in valid or not valid[kind](default):
            raise ValidationError(f"setting {key} default does not match its declared type")
        if "description" in setting:
            _string(setting["description"], f"setting {key} description", 160)

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
    print("notice: validation is a static review aid; Quickshell plugins are not sandboxed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

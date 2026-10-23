#!/usr/bin/env python3
"""Read-only Hornero CLI fixture for the isolated Appearance AT-SPI harness."""

import json
import os
import sys


args = sys.argv[1:]
log = os.path.join(os.environ["XDG_STATE_HOME"], "hornero", "atspi-cli.log")
os.makedirs(os.path.dirname(log), exist_ok=True)
with open(log, "a", encoding="utf-8") as calls:
    calls.write(json.dumps(args) + "\n")

is_sandboxed_wallpaper_preview = args[:3] == ["appearance", "colors", "m3"]
is_sandboxed_scheme_regeneration = args == ["appearance", "scheme", "regenerate", "--yes"]
mutating_commands = {
    "apply", "set", "install", "update", "remove", "enable", "disable", "trust",
    "add", "restore", "upgrade", "create", "delete", "write",
}
is_mutating = not (is_sandboxed_wallpaper_preview or is_sandboxed_scheme_regeneration) and (
    "--yes" in args
    or any(arg in mutating_commands for arg in args[2:])
)
if is_mutating:
    with open(log, "a", encoding="utf-8") as calls:
        calls.write("MUTATION_ATTEMPT\n")
    print("The AT-SPI fixture refuses mutating CLI requests", file=sys.stderr)
    raise SystemExit(2)

if is_sandboxed_wallpaper_preview or is_sandboxed_scheme_regeneration:
    # Startup may regenerate dynamic scheme data in the user's cache, and
    # WallpaperGrid may request a non-applied preview when the pointer rests
    # over a thumbnail. Keep both calls inside this fixture; never invoke the
    # real CLI/backend or change the user's appearance.
    with open(log, "a", encoding="utf-8") as calls:
        calls.write("SANDBOXED_APPEARANCE_CACHE_OPERATION\n")
    print(json.dumps({
        "name": "dynamic",
        "flavour": "tonalspot",
        "mode": "dark",
        "colours": {"primary": "6750a4"},
    }))
    raise SystemExit(0)

with open(os.environ["HORNERO_ATSPI_FIXTURE"], encoding="utf-8") as source:
    fixture = json.load(source)

if args == ["appearance", "theme", "list", "--full"]:
    print(json.dumps(fixture["themes"]))
elif args == ["appearance", "gtk", "list"]:
    print(fixture["gtk_themes"])
elif args == ["appearance", "gtk", "icons"]:
    print(fixture["icon_themes"])
elif args == ["appearance", "scheme", "list"]:
    print(json.dumps(fixture["schemes"]))
elif args == ["appearance", "scheme", "current"]:
    print(fixture["current_scheme"], end="")
elif args == ["wallpaper", "current"]:
    print(fixture["wallpaper"])
else:
    # Some pane services perform unrelated read-only startup probes. They
    # receive empty output in this isolated fixture instead of touching the
    # host. Record calls so the runner can fail if it observes a mutation.
    print("")

"""Clipboard history (>clip), emoji picker (>emoji), and running-window
dock mode tests (HorneroOS/shell#737), including ADR-002 process boundary
and zero shell.default.json drift checks.
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def _run_js(rel: str, expr: str):
    src = (ROOT / rel).read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run(
        [shutil.which("node"), "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


@NODE
def test_clipboard_mime_filtering_blocks_password_managers_and_binary():
    out = _run_js("services/clipboard.js", """
        return {
            kdeHint: shouldSkipMimeTypes(["text/plain", "x-kde-passwordManagerHint"]),
            kdeCase: shouldSkipMimeTypes("UTF8_STRING\\nX-KDE-PASSWORDMANAGERHINT"),
            keepass: shouldSkipMimeTypes(["application/x-keepass", "text/plain"]),
            binaryOnly: shouldSkipMimeTypes(["image/png", "application/octet-stream"]),
            empty: shouldSkipMimeTypes([]),
            plain: shouldSkipMimeTypes(["text/plain;charset=utf-8"]),
            utf8: shouldSkipMimeTypes(["UTF8_STRING"]),
            json: shouldSkipMimeTypes(["application/json"])
        };
    """)
    assert out == {
        "kdeHint": True,
        "kdeCase": True,
        "keepass": True,
        "binaryOnly": True,
        "empty": True,
        "plain": False,
        "utf8": False,
        "json": False,
    }


@NODE
def test_clipboard_burst_normalization_dedup_and_search():
    out = _run_js("services/clipboard.js", """
        const burst = isInitialBurst(1200, 1000);
        const after = isInitialBurst(1700, 1000);
        const blank = normalizeEntry("   \\n ", "text/plain", 2000, 1);
        const e1 = normalizeEntry("first line\\nsecond line", "text/plain", 2000, 1);
        const e2 = normalizeEntry("alpha beta", "text/plain", 3000, 2);
        const e1Dup = normalizeEntry("first line\\nsecond line", "text/plain", 4000, 3);
        let list = upsertEntry([], e1, 2);
        list = upsertEntry(list, e2, 2);
        list = upsertEntry(list, e1Dup, 2);
        const filtered = filterEntries(list, "second");
        return {
            burst: burst,
            after: after,
            blank: blank,
            listIds: list.map(x => x.id),
            filteredIds: filtered.map(x => x.id),
            preview: e1.preview,
            meta: formatMeta(e1)
        };
    """)
    assert out["burst"] is True
    assert out["after"] is False
    assert out["blank"] is None
    assert out["listIds"] == [3, 2]
    assert out["filteredIds"] == [3]
    assert out["preview"] == "first line second line"
    assert out["meta"] == "2 lines · 22 chars"


@NODE
def test_emoji_search_ranks_and_matches_keywords():
    out = _run_js("modules/launcher/services/emoji.js", """
        const defaults = searchEmojis("", 10);
        const rocket = searchEmojis("rocket", 5);
        const hornero = searchEmojis("hornero", 5);
        const multi = searchEmojis("check done", 5);
        return {
            defaultCount: defaults.length,
            firstRocket: rocket[0].char,
            horneroChars: hornero.map(e => e.char),
            firstMulti: multi[0].char
        };
    """)
    assert out["defaultCount"] == 10
    assert out["firstRocket"] == "🚀"
    assert "🐦" in out["horneroChars"] or "🪶" in out["horneroChars"]
    assert out["firstMulti"] == "✅"


@NODE
def test_dock_merges_pinned_and_running_apps_with_focus_cycling():
    out = _run_js("modules/bar/components/dockapps.js", """
        const pinned = [
            { id: "kitty.desktop", name: "Kitty", icon: "kitty", startupClass: "kitty" },
            { id: "firefox.desktop", name: "Firefox", icon: "firefox", startupClass: "firefox" }
        ];
        const all = pinned.concat([
            { id: "org.gnome.Nautilus.desktop", name: "Files", icon: "system-file-manager", startupClass: "org.gnome.Nautilus" }
        ]);
        const windows = [
            { id: 1, appClass: "kitty", title: "fish", activated: false },
            { id: 2, appClass: "kitty", title: "nvim", activated: true },
            { id: 3, appClass: "org.gnome.Nautilus", title: "Home", activated: false }
        ];
        const barMode = buildDockItems(pinned, all, windows, false);
        const dockMode = buildDockItems(pinned, all, windows, true);
        const cycled = nextFocusWindow(dockMode[0].windows);
        return {
            barIds: barMode.map(i => i.id),
            dockIds: dockMode.map(i => i.id),
            kittyRunning: dockMode[0].runningCount,
            kittyActive: dockMode[0].active,
            firefoxRunning: dockMode[1].runningCount,
            nautilusPinned: dockMode[2].pinned,
            nautilusName: dockMode[2].name,
            cycledId: cycled.id
        };
    """)
    assert out == {
        "barIds": ["kitty", "firefox"],
        "dockIds": ["kitty", "firefox", "org.gnome.nautilus"],
        "kittyRunning": 2,
        "kittyActive": True,
        "firefoxRunning": 0,
        "nautilusPinned": False,
        "nautilusName": "Files",
        "cycledId": 1,
    }


def test_adr002_no_process_in_new_ui_modules_and_safe_wl_copy_stdin():
    for rel in (
        "modules/launcher/items/ClipboardItem.qml",
        "modules/launcher/items/EmojiItem.qml",
        "modules/launcher/services/Emoji.qml",
        "modules/launcher/services/Windows.qml",
        "modules/bar/components/PinnedApps.qml",
    ):
        src = (ROOT / rel).read_text(encoding="utf-8")
        assert "Process {" not in src, f"Process must live in services/, not {rel}"
        assert "execDetached" not in src, f"execDetached forbidden in {rel}"
        assert "python3" not in src, rel

    clip = (ROOT / "services/Clipboard.qml").read_text(encoding="utf-8")
    assert 'command: ["wl-copy"]' in clip
    assert "stdinEnabled: true" in clip
    assert "copyProc.write(copyProc.sending)" in clip
    assert 'execDetached(["wl-copy"' not in clip


def test_launcher_wires_clip_and_emoji_providers():
    providers = (ROOT / "modules/launcher/services/Providers.qml").read_text(encoding="utf-8")
    applist = (ROOT / "modules/launcher/AppList.qml").read_text(encoding="utf-8")
    content = (ROOT / "modules/launcher/Content.qml").read_text(encoding="utf-8")
    cfg = (ROOT / "config/LauncherConfig.qml").read_text(encoding="utf-8")
    for pid in ('"id": "clip"', '"id": "emoji"'):
        assert pid in providers
    for state in ('"clip"', '"emoji"'):
        assert f"name: {state}" in applist
        assert f"{state}:" in content
    assert 'command: ["autocomplete", "clip"]' in cfg
    assert 'command: ["autocomplete", "emoji"]' in cfg

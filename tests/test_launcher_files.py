"""File provider on the registry (shell#250 slice 2).

The bounded search logic lives in the pure filesearch.js, so the
bounds run under node against real inputs, and the find argv it
builds runs against a real fixture tree (hidden/sensitive dirs,
a symlink escaping the root, a missing root). QML contracts are
static in repo style. Structural/offscreen evidence only — no
live shell is launched.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICES = ROOT / "modules" / "launcher" / "services"
JS = SERVICES / "filesearch.js"
FILES = (SERVICES / "Files.qml").read_text()
PROVIDERS = (SERVICES / "Providers.qml").read_text()
APPLIST = (ROOT / "modules" / "launcher" / "AppList.qml").read_text()


def _run_js(driver: str):
    node = shutil.which("node")
    assert node, "node is required to execute filesearch.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + "\n" + driver],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def _find_args(roots, query, depth):
    return _run_js(
        f"console.log(JSON.stringify(buildFindArgs({json.dumps(roots)},"
        f" {json.dumps(query)}, {depth})));"
    )


# --- Registry integration ------------------------------------------------

def test_file_provider_registered_in_providers_with_files_section():
    for needle in ('"id": "file"', '"prefix": "file"', '"section": "Files"',
                   "Files.requestSearch(text)", "Files.activate(result)",
                   "Files.results.map"):
        assert needle in PROVIDERS, needle
    # Ranked registry result shape, name + parent path as title/subtitle.
    for field in ('"providerId": "file"', '"title": e.name',
                  '"subtitle": e.parent', '"payload": e'):
        assert field in PROVIDERS, field


def test_applist_routes_file_state_via_registry():
    assert 'providerState === "file"' in APPLIST
    assert 'name: "file"' in APPLIST
    assert "model.values: Providers.query(search.text)" in APPLIST
    # The pre-registry inline shell search is gone, not duplicated.
    assert "runFileSearch" not in APPLIST and "fileProc" not in APPLIST
    assert "fileResults" not in APPLIST
    # Leaving the file state cancels an in-flight search.
    assert "Files.cancel()" in APPLIST


def test_file_item_shows_name_and_parent_and_activates_via_registry():
    item = (ROOT / "modules" / "launcher" / "items" / "FileItem.qml").read_text()
    assert "Providers.activate(root.modelData, root.list)" in item
    assert "modelData?.title" in item and "modelData?.subtitle" in item


def test_activation_opens_via_existing_xdg_open_convention():
    assert 'Quickshell.execDetached(["xdg-open", path])' in FILES
    # No shell interprets the query or the path anywhere.
    assert '"sh", "-c"' not in FILES and '"sh", "-c"' not in PROVIDERS


def test_enter_on_file_row_activates_item_not_modeldata():
    content = (ROOT / "modules" / "launcher" / "Content.qml").read_text()
    assert "actionPrefix}file `" in content
    assert "currentItem.onClicked();" in content


# --- Bounds ----------------------------------------------------------------

def test_bounds_constants_and_result_cap():
    out = _run_js("""
console.log(JSON.stringify({max: MAX_RESULTS, depth: MAX_DEPTH, home: HOME_MAX_DEPTH, min: MIN_QUERY_LENGTH, debounce: DEBOUNCE_MS}));""")
    assert out == {"max": 50, "depth": 4, "home": 1, "min": 2, "debounce": 250}
    entries = [{"path": f"/home/u/Documents/notes{i}.txt"} for i in range(80)]
    out = _run_js(f"""
const roots = userRoots("/home/u", {{}});
console.log(JSON.stringify(rankResults({json.dumps(entries)}, "notes", roots).length));""")
    assert out == 50


def test_depth_cap_drops_deep_entries():
    out = _run_js("""
const roots = userRoots("/home/u", {});
const entries = [
  { path: "/home/u/Documents/a/notes.txt" },
  { path: "/home/u/Documents/a/b/c/d/notes.txt" },
  { path: "/home/u/top-notes.txt" },
  { path: "/home/u/sub/notes.txt" }
];
console.log(JSON.stringify(rankResults(entries, "notes", roots).map(e => e.path)));""")
    # Depth 5 under Documents and depth 2 under home are out of bounds.
    # Ranking: "notes.txt" is a name-prefix match, "top-notes.txt" only
    # a substring match, so the deeper prefix match ranks first.
    assert out == ["/home/u/Documents/a/notes.txt", "/home/u/top-notes.txt"]


def test_user_roots_are_xdg_dirs_plus_home_top_level():
    out = _run_js("""
console.log(JSON.stringify(userRoots("/home/u", { XDG_DOCUMENTS_DIR: "/data/docs" })));""")
    paths = [r["path"] for r in out]
    assert paths[0] == "/data/docs"
    assert "/home/u/Downloads" in paths and "/home/u/Videos" in paths
    home = [r for r in out if r["path"] == "/home/u"]
    assert home and home[0]["maxDepth"] == 1
    assert all(not p.startswith("/etc") and p != "/" for p in paths)


# --- Privacy exclusions ------------------------------------------------------

def test_hidden_and_sensitive_excluded():
    out = _run_js("""
const roots = userRoots("/home/u", {});
const entries = [
  { path: "/home/u/Documents/notes.txt" },
  { path: "/home/u/Documents/.hidden/notes.txt" },
  { path: "/home/u/Documents/.ssh/notes.txt" },
  { path: "/home/u/Documents/work/.gnupg/notes.txt" },
  { path: "/home/u/Documents/credentials/notes.txt" },
  { path: "/home/u/Documents/.config/credentials/notes.txt" },
  { path: "/home/u/Documents/id_rsa" },
  { path: "/home/u/Documents/cert.pem" },
  { path: "/home/u/Documents/.notes.txt" }
];
console.log(JSON.stringify(rankResults(entries, "notes", roots).map(e => e.path)));""")
    # Note: "notes" also matches id_rsa/cert.pem only via the query
    # gate in find; here every returned row must be the clean one,
    # and sensitive names are dropped even on an empty-ish query.
    assert "/home/u/Documents/notes.txt" in out
    assert not any(".hidden" in p or ".ssh" in p or ".gnupg" in p
                   or "credentials" in p or ".config" in p
                   or p.endswith(".notes.txt") for p in out), out
    out2 = _run_js("""
const roots = userRoots("/home/u", {});
console.log(JSON.stringify([
  isSensitivePath("/home/u/Documents/id_rsa"),
  isSensitivePath("/home/u/Documents/cert.pem"),
  isSensitivePath("/home/u/Documents/notes.txt"),
  isHiddenPath("/home/u/Documents/.cache/x")
]));""")
    assert out2 == [True, True, False, True]


def test_symlink_escape_dropped_via_resolved_path():
    out = _run_js("""
const roots = userRoots("/home/u", {});
const entries = [
  { path: "/home/u/Documents/link-notes.txt", realPath: "/etc/notes.txt" },
  { path: "/home/u/Documents/linkdir/notes.txt", realPath: "/home/u/Documents/linkdir/notes.txt" },
  { path: "/home/u/Documents/real-notes.txt", realPath: "/home/u/Documents/real-notes.txt" }
];
console.log(JSON.stringify(rankResults(entries, "notes", roots).map(e => e.path)));""")
    assert out == ["/home/u/Documents/linkdir/notes.txt",
                   "/home/u/Documents/real-notes.txt"], out


def test_outside_root_and_traversal_dropped():
    out = _run_js("""
const roots = userRoots("/home/u", {});
const entries = [
  { path: "/etc/notes.txt" },
  { path: "/home/u/Documents/../../etc/notes.txt" },
  { path: "/home/u/Documents/notes.txt" }
];
console.log(JSON.stringify(rankResults(entries, "notes", roots).map(e => e.path)));""")
    assert out == ["/home/u/Documents/notes.txt"]


# --- Ranking -------------------------------------------------------------------

def test_ranking_exact_prefix_substring_then_shallower():
    out = _run_js("""
const roots = userRoots("/home/u", {});
const entries = [
  { path: "/home/u/Documents/deep/dir/my-notes.txt" },
  { path: "/home/u/Documents/notes-old.txt" },
  { path: "/home/u/Documents/xnotes.txt" },
  { path: "/home/u/Documents/notes", isDir: true },
  { path: "/home/u/Documents/notes-archive/other.txt" }
];
console.log(JSON.stringify(rankResults(entries, "notes", roots).map(e => e.path)));""")
    assert out == [
        "/home/u/Documents/notes",          # exact name (dir)
        "/home/u/Documents/notes-old.txt",  # name prefix
        "/home/u/Documents/xnotes.txt",     # name substring
        "/home/u/Documents/deep/dir/my-notes.txt",  # name substring, deeper
        "/home/u/Documents/notes-archive/other.txt",  # parent-only match
    ], out


def test_rows_show_name_and_parent():
    out = _run_js("""
const roots = userRoots("/home/u", {});
console.log(JSON.stringify(rankResults([{ path: "/home/u/Documents/sub/report.pdf" }], "report", roots)));""")
    assert out == [{"path": "/home/u/Documents/sub/report.pdf",
                    "name": "report.pdf",
                    "parent": "/home/u/Documents/sub", "isDir": False}]


# --- Real find over a fixture tree ------------------------------------------------

def test_find_argv_is_argv_not_shell_and_escapes_glob():
    args = _find_args(["/home/u/Documents"], "a*b?[x]", 4)
    assert args[0] == "find" and "sh" not in args
    pattern = args[args.index("-iname") + 1]
    assert pattern == "*a\\*b\\?\\[x\\]*", pattern
    assert "-maxdepth" in args and args[args.index("-maxdepth") + 1] == "4"
    # Hidden/sensitive pruning and symlink-safe types are in the argv.
    assert "-prune" in args and ".*" in args
    assert args.count("-type") == 2


def test_real_find_fixture_bounds_exclusions_and_symlink_escape(tmp_path):
    home = tmp_path / "home"
    docs = home / "Documents"
    (docs / "sub").mkdir(parents=True)
    (docs / ".hidden").mkdir()
    (docs / ".ssh").mkdir()
    (docs / "notes.txt").write_text("x")
    (docs / "sub" / "notes.md").write_text("x")
    (docs / ".hidden" / "notes.txt").write_text("x")
    (docs / ".ssh" / "notes.txt").write_text("x")
    deep = docs / "a" / "b" / "c" / "d"
    deep.mkdir(parents=True)
    (deep / "notes.txt").write_text("x")
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "notes-secret.txt").write_text("x")
    (docs / "escape-dir").symlink_to(outside, target_is_directory=True)
    (docs / "escape-file.txt").symlink_to(outside / "notes-secret.txt")
    missing = home / "NoSuchDir"
    args = _find_args([str(docs), str(missing)], "notes", 4)
    proc = subprocess.run(args, capture_output=True, text=True, timeout=30)
    found = proc.stdout
    assert str(docs / "notes.txt") in found
    assert str(docs / "sub" / "notes.md") in found
    assert ".hidden" not in found and ".ssh" not in found
    assert "notes-secret" not in found, "symlink escape leaked a result"
    assert "escape-dir" not in found and "escape-file" not in found
    assert str(deep / "notes.txt") not in found, "depth cap not enforced by find"
    # The JS ranker agrees on the same output and caps/filters it.
    entries = _run_js(f"""
console.log(JSON.stringify(parseFindOutput({json.dumps(found)})));""")
    ranked = _run_js(f"""
const roots = [{{ path: {json.dumps(str(docs))}, maxDepth: 4 }}];
console.log(JSON.stringify(rankResults({json.dumps(entries)}, "notes", roots).map(e => e.path)));""")
    assert ranked == [str(docs / "notes.txt"), str(docs / "sub" / "notes.md")], ranked


def test_empty_and_missing_roots_degrade_to_no_rows():
    assert _run_js('console.log(JSON.stringify(rankResults([], "notes", userRoots("/home/u", {}))));') == []
    assert _run_js('console.log(JSON.stringify(parseFindOutput("")));') == []
    assert _run_js("""
const roots = userRoots("/home/u", {});
console.log(JSON.stringify(rankResults([{ path: "/home/u/Documents/notes.txt" }], "zzz", roots).map(e => e.path)));""") \
        == ["/home/u/Documents/notes.txt"]  # find gates by query; ranker only ranks/filters bounds


# --- Debounce / cancellation contract -------------------------------------------

def test_debounce_and_cancellation_contract():
    assert "interval: FileSearch.DEBOUNCE_MS" in FILES
    assert "debounce.restart()" in FILES
    # Idempotent per query: model re-evaluation never restarts a search.
    assert "if (q === root.requestedQuery)" in FILES
    # Cancellation kills both processes and invalidates the generation;
    # a stale generation never publishes.
    assert "root.generation++" in FILES
    assert "userDirsProc.running = false" in FILES
    assert "homeProc.running = false" in FILES
    assert "if (gen !== root.generation)" in FILES
    # Search only runs from the debounce trigger — no startup/background scan.
    assert "Component.onCompleted" not in FILES
    assert FILES.count("startSearch()") >= 1 and "onTriggered: root.startSearch()" in FILES


def test_min_query_searches_nothing():
    assert "MIN_QUERY_LENGTH" in FILES
    assert 'qsTr("Type at least 2 characters")' in FILES
    assert 'qsTr("No files found")' in FILES and 'qsTr("Searching\\u2026")' in FILES or 'qsTr("Searching…")' in FILES


def test_other_providers_unchanged():
    for pid in ('"id": "apps"', '"id": "calc"', '"id": "win"'):
        assert pid in PROVIDERS, pid
    assert "Apps.search(search.text)" in APPLIST
    assert 'name: "calc"' in APPLIST and 'name: "win"' in APPLIST and 'name: "plugin"' in APPLIST

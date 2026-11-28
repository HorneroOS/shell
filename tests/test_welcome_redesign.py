"""Unit tests for the Hornero Welcome redesign:
- services/welcome_model.js (v2 schema, v1->v2 migration, startup guard,
  typed deep links, unified discovery search)
- services/welcome_preview_tx.js (Reversible Live Preview state machine)
- services/welcome_whatsnew.js (version-aware release filter & unseen tracking)
- modules/welcome/data/features.json, releases.json, wallpapers.json
- components/motion/Choreography.qml (Signal motion tokens & helpers)
"""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WELCOME = ROOT / "modules" / "welcome"
DATA = WELCOME / "data"
GLYPHS = ROOT / "assets" / "fonts" / "hornero-glyphs.names"


def _run_js(rel_path: str, expr: str):
    node = shutil.which("node")
    assert node, "node is required for JS model tests"
    src = (ROOT / rel_path).read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, check=True, timeout=20,
    )
    return json.loads(proc.stdout)


def test_v1_to_v2_migration_never_replays_first_flight_for_existing_users():
    res = _run_js("services/welcome_model.js", """
        const optOutV1 = parseState(JSON.stringify({
            schemaVersion: 1,
            showOnLogin: false,
            contentRevision: "p1",
            lastSeenContentRevision: ""
        }));
        const seenV1 = parseState(JSON.stringify({
            schemaVersion: 1,
            showOnLogin: true,
            contentRevision: "p1",
            lastSeenContentRevision: "p1",
            firstOpenedAt: "2026-10-01T00:00:00Z"
        }));
        const freshV1 = parseState(JSON.stringify({
            schemaVersion: 1,
            showOnLogin: true,
            contentRevision: "p1",
            lastSeenContentRevision: "",
            firstOpenedAt: ""
        }));
        return { optOutV1, seenV1, freshV1 };
    """)
    assert res["optOutV1"]["schemaVersion"] == 2
    assert res["optOutV1"]["showOnLogin"] is False
    assert res["optOutV1"]["firstRunCompleted"] is True

    assert res["seenV1"]["schemaVersion"] == 2
    assert res["seenV1"]["firstRunCompleted"] is True

    assert res["freshV1"]["schemaVersion"] == 2
    assert res["freshV1"]["firstRunCompleted"] is False


def test_startup_policy_never_replays_first_flight_and_respects_opt_out():
    res = _run_js("services/welcome_model.js", """
        const fresh = evaluateStartup(defaultState(), false, false, "1.6.0", true);
        const completedNoUpdate = evaluateStartup(
            { showOnLogin: true, firstRunCompleted: true },
            false, false, "1.6.0", false
        );
        const completedWithUpdate = evaluateStartup(
            { showOnLogin: true, firstRunCompleted: true },
            false, false, "1.6.0", true
        );
        const optedOutWithUpdate = evaluateStartup(
            { showOnLogin: false, firstRunCompleted: true },
            false, false, "1.6.0", true
        );
        return { fresh, completedNoUpdate, completedWithUpdate, optedOutWithUpdate };
    """)
    assert res["fresh"]["shouldOpen"] is True
    assert res["fresh"]["mode"] == "first-flight"

    assert res["completedNoUpdate"]["shouldOpen"] is False
    assert res["completedWithUpdate"]["shouldOpen"] is True
    assert res["completedWithUpdate"]["mode"] == "whats-new"
    assert res["optedOutWithUpdate"]["shouldOpen"] is False


def test_legacy_and_new_targets_resolve_cleanly():
    res = _run_js("services/welcome_model.js", """
        const targets = [
            "start", "personalize", "apps", "javi", "navigate", "shell",
            "workspaces", "tools", "system", "settings", "learn", "shortcuts",
            "first-flight", "explore", "whats-new", "trust", "ready", "bogus"
        ];
        const out = {};
        for (const t of targets)
            out[t] = resolveOpenTarget(t, { firstRunCompleted: true });
        out["emptyCompleted"] = resolveOpenTarget("", { firstRunCompleted: true });
        out["emptyFresh"] = resolveOpenTarget("", { firstRunCompleted: false });
        return out;
    """)
    assert res["start"]["mode"] == "first-flight" and res["start"]["scene"] == "arrival"
    assert res["personalize"]["scene"] == "personalize"
    assert res["apps"]["scene"] == "workstation"
    assert res["javi"]["scene"] == "companion"
    assert res["learn"]["mode"] == "whats-new"
    assert res["shortcuts"]["mode"] == "explore" and res["shortcuts"]["view"] == "shortcuts"
    assert res["explore"]["mode"] == "explore"
    assert res["whats-new"]["mode"] == "whats-new"
    assert res["trust"]["scene"] == "trust"
    assert res["bogus"]["unknown"] is True and res["bogus"]["scene"] == "arrival"
    assert res["emptyCompleted"]["mode"] == "explore"
    assert res["emptyFresh"]["mode"] == "first-flight"


def test_typed_action_validator_rejects_arbitrary_commands_and_urls():
    res = _run_js("services/welcome_model.js", """
        return {
            okUri: validateTypedAction("controlCenter://appearance#chromatic"),
            okObj: validateTypedAction({ type: "drawer", target: "launcher" }),
            okApps: validateTypedAction("apps://discover"),
            badHttp: validateTypedAction("https://evil.example/shell"),
            badShell: validateTypedAction({ type: "exec", target: "rm -rf /" }),
            badDrawer: validateTypedAction({ type: "drawer", target: "arbitrary" }),
            badTraversal: validateTypedAction({ type: "controlCenter", target: "../etc/passwd" }),
            badAction: validateTypedAction({ type: "action", target: "curl_pipe_sh" })
        };
    """)
    assert res["okUri"]["valid"] is True and res["okUri"]["target"] == "appearance" and res["okUri"]["section"] == "chromatic"
    assert res["okObj"]["valid"] is True
    assert res["okApps"]["valid"] is True
    for bad in ("badHttp", "badShell", "badDrawer", "badTraversal", "badAction"):
        assert res[bad]["valid"] is False, f"{bad} must be rejected"


def test_unified_discovery_search_across_features_shortcuts_apps_extensions():
    features = json.loads((DATA / "features.json").read_text(encoding="utf-8"))["features"]
    res = _run_js("services/welcome_model.js", f"""
        const features = {json.dumps(features)};
        const shortcuts = [{{ id: "exec-launcher", label: "Open Launcher", keys: "SUPER + Space", group: "Launch" }}];
        const apps = [{{ id: "reaper", name: "REAPER", summary: "Digital audio workstation", categories: ["Audio"], tags: ["studio"], installed: false }}];
        const exts = [{{ id: "cpu-scope", name: "CPU Scope", description: "Bar telemetry trace", category: "Monitor", installed: true }}];
        return {{
            studioSearch: searchDiscovery("studio", features, shortcuts, apps, exts, {{ studioAudio: false }}),
            launcherSearch: searchDiscovery("launcher", features, shortcuts, apps, exts, {{ hyprland: true }}),
            scopeSearch: searchDiscovery("scope", features, shortcuts, apps, exts, {{}})
        }};
    """)
    assert any(r["id"] == "studio-audio-routing" and r["available"] is False for r in res["studioSearch"])
    assert any(r["kind"] == "app" and r["id"] == "reaper" for r in res["studioSearch"])
    assert any(r["kind"] == "shortcut" for r in res["launcherSearch"])
    assert any(r["kind"] == "extension" and r["id"] == "cpu-scope" for r in res["scopeSearch"])


def test_preview_transaction_state_machine_and_crash_recovery():
    res = _run_js("services/welcome_preview_tx.js", """
        let tx = createInitialTx();
        tx = begin(tx, {
            themeId: "hornero-signal-night",
            themeMode: "dark",
            wallpaperPath: "/w/night.png",
            layoutPreset: "cockpit",
            chromaticActive: false
        }, 12345, "2026-11-28T00:00:00Z");
        const cleanAtStart = tx.dirty;
        tx = update(tx, { themeId: "hornero-signal-day", themeMode: "light" });
        const dirtyAfterTheme = tx.dirty;
        const serialized = serialize(tx);
        const crashNeeded = needsCrashRecovery(serialized);
        const backToBaseline = update(tx, { themeId: "hornero-signal-night", themeMode: "dark" });
        const cleanAgain = backToBaseline.dirty;
        const committed = commit(tx);
        const reverted = revert(tx);
        return { cleanAtStart, dirtyAfterTheme, crashNeeded, cleanAgain, committed, reverted };
    """)
    assert res["cleanAtStart"] is False
    assert res["dirtyAfterTheme"] is True
    assert res["crashNeeded"] is True
    assert res["cleanAgain"] is False
    assert res["committed"]["persistTheme"] is True
    assert res["committed"]["targetThemeId"] == "hornero-signal-day"
    assert res["reverted"]["restoreTheme"] is True
    assert res["reverted"]["baseline"]["themeId"] == "hornero-signal-night"


def test_whatsnew_engine_versions_and_capabilities():
    releases_doc = json.loads((DATA / "releases.json").read_text(encoding="utf-8"))
    res = _run_js("services/welcome_whatsnew.js", f"""
        const doc = {json.dumps(releases_doc)};
        return {{
            unseen150: hasUnseenRelease("1.6.0", "1.5.0"),
            seen160: hasUnseenRelease("1.6.0", "1.6.0"),
            withoutStudio: filterReleases(doc, {{ studioAudio: false }}, "1.4.0"),
            withStudio: filterReleases(doc, {{ studioAudio: true }}, "1.4.0")
        }};
    """)
    assert res["unseen150"] is True
    assert res["seen160"] is False
    assert [r["version"] for r in res["withoutStudio"]] == ["1.6.0", "1.5.0", "1.4.0"]
    hl_without = [h["id"] for h in res["withoutStudio"][1]["highlights"]]
    hl_with = [h["id"] for h in res["withStudio"][1]["highlights"]]
    assert "studio-routing-kits" not in hl_without
    assert "studio-routing-kits" in hl_with


def test_declarative_data_files_valid_actions_glyphs_and_licenses():
    known_glyphs = {line.strip() for line in GLYPHS.read_text().splitlines() if line.strip() and not line.startswith("#")}
    features_doc = json.loads((DATA / "features.json").read_text(encoding="utf-8"))
    assert len(features_doc["features"]) >= 15
    for f in features_doc["features"]:
        assert f["icon"] in known_glyphs, f"features.json invalid glyph: {f['icon']}"
        v = _run_js("services/welcome_model.js", f"return validateTypedAction({json.dumps(f['action'])});")
        assert v["valid"] is True, f"features.json invalid action on {f['id']}: {v}"

    releases_doc = json.loads((DATA / "releases.json").read_text(encoding="utf-8"))
    for rel in releases_doc["releases"]:
        for h in rel["highlights"]:
            assert h["icon"] in known_glyphs, f"releases.json invalid glyph: {h['icon']}"
            v = _run_js("services/welcome_model.js", f"return validateTypedAction({json.dumps(h['action'])});")
            assert v["valid"] is True, f"releases.json invalid action on {h['id']}: {v}"

    wallpapers_doc = json.loads((DATA / "wallpapers.json").read_text(encoding="utf-8"))
    for w in wallpapers_doc["wallpapers"]:
        assert w["license"] in ("MIT", "CC BY 2.0"), f"Unverified wallpaper license in Welcome: {w}"


def test_choreography_tokens_and_helpers_present():
    text = (ROOT / "components" / "motion" / "Choreography.qml").read_text(encoding="utf-8")
    for token in ("instantMs: 90", "microMs: 160", "standardMs: 240",
                  "sceneMs: 320", "arrivalMs: 360", "staggerMs: 40",
                  "sceneTravelPx: 16", "reducedFadeMs: 90",
                  "function effectiveDuration(", "function effectiveTravel(",
                  "reducedMotion: Appearance.anim.reduced"):
        assert token in text, f"Choreography.qml missing {token}"

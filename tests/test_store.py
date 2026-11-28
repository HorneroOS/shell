"""Headless tests for services/store.js Hornero Apps data & policy helpers."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "store.js"


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/store.js"
    src = JS.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_provenance_and_backend_labels_and_tones():
    out = run_js("""
        return {
            labels: [
                provenanceLabel("vendor_official_repo"),
                provenanceLabel("vendor_official_binary"),
                provenanceLabel("arch_official"),
                provenanceLabel("flathub_verified"),
                provenanceLabel("community_package"),
                provenanceLabel("official_web_app"),
                provenanceLabel("guided_setup_required"),
                provenanceLabel("unknown_src")
            ],
            tones: [
                provenanceBadgeTone("vendor_official_repo"),
                provenanceBadgeTone("flathub_verified"),
                provenanceBadgeTone("official_web_app"),
                provenanceBadgeTone("community_package"),
                provenanceBadgeTone("guided_setup_required"),
                provenanceBadgeTone("other")
            ],
            backends: [
                backendLabel("pacman"),
                backendLabel("flatpak"),
                backendLabel("appimage"),
                backendLabel("webapp"),
                backendLabel("aur"),
                backendLabel("guided")
            ],
            statuses: [
                statusLabel("installed"),
                statusLabel("update_available"),
                statusLabel("queued"),
                statusLabel("guided"),
                statusLabel("policy_blocked")
            ]
        };
    """)
    assert out["labels"] == [
        "Official Vendor",
        "Official Vendor",
        "Arch Official",
        "Flathub Verified",
        "Community AUR",
        "Official Web App",
        "Guided Setup",
        "Unverified",
    ]
    assert out["tones"] == ["phosphor", "phosphor", "cue", "signal", "signal", "alert"]
    assert out["backends"] == [
        "Arch / pacman",
        "Flatpak",
        "AppImage",
        "Web App",
        "Community AUR",
        "Guided Setup",
    ]
    assert out["statuses"] == [
        "Installed",
        "Update available",
        "Queued",
        "Guided setup",
        "Blocked by policy",
    ]


def test_can_one_click_install_and_primary_action_honesty():
    apps = [
        {"id": "obsidian", "name": "Obsidian", "backend": "flatpak", "provenance": "flathub_verified", "is_open_source": False},
        {"id": "firefox", "name": "Firefox", "backend": "pacman", "provenance": "arch_official", "is_open_source": True, "installed": True},
        {"id": "cursor", "name": "Cursor", "backend": "aur", "provenance": "community_package", "is_open_source": False},
        {"id": "figma", "name": "Figma", "backend": "webapp", "provenance": "official_web_app", "url": "https://figma.com"},
        {"id": "davinci", "name": "DaVinci Resolve", "backend": "guided", "provenance": "guided_setup_required"},
        {"id": "vlc", "name": "VLC", "backend": "flatpak", "provenance": "flathub_verified", "is_open_source": True, "installed": True, "update_available": True},
    ]
    env = {"command": "store list", "ok": True, "message": "ok", "data": {"apps": json.dumps(apps)}}
    out = run_js(f"""
        const parsed = parseStoreList({json.dumps(env)});
        const policyOpenOnly = {{ verifiedOnly: true, openSourceOnly: true, aurPolicy: "explicit_opt_in", proprietaryPolicy: "explicit_consent", allowedSources: [] }};
        return parsed.apps.map(a => ({{
            id: a.id,
            oneClick: canOneClickInstall(a),
            actionDefault: primaryActionKind(a, null),
            actionStrict: primaryActionKind(a, policyOpenOnly)
        }}));
    """)
    by_id = {x["id"]: x for x in out}
    assert by_id["obsidian"]["oneClick"] is True
    assert by_id["obsidian"]["actionDefault"] == "install"
    assert by_id["obsidian"]["actionStrict"] == "policy_blocked"

    assert by_id["firefox"]["oneClick"] is True
    assert by_id["firefox"]["actionDefault"] == "open"

    assert by_id["cursor"]["oneClick"] is False
    assert by_id["cursor"]["actionDefault"] == "aur_review"

    assert by_id["figma"]["oneClick"] is False
    assert by_id["figma"]["actionDefault"] == "webapp"

    assert by_id["davinci"]["oneClick"] is False
    assert by_id["davinci"]["actionDefault"] == "guide"

    assert by_id["vlc"]["actionDefault"] == "update"


def test_filter_apps_and_launcher_dedup():
    apps = [
        {"id": "zen", "name": "Zen Browser", "summary": "Fast privacy browser", "publisher": "Zen", "categories": ["Internet"], "collections": ["everyday-essentials"], "aliases": ["browser"], "tags": ["web"], "backend": "flatpak", "provenance": "flathub_verified", "is_open_source": True, "installed": True, "desktop_id": "app.zen_browser.zen.desktop"},
        {"id": "gimp", "name": "GIMP", "summary": "Image editor", "publisher": "GIMP Team", "categories": ["Graphics"], "collections": ["create-something"], "aliases": ["photoshop"], "tags": ["image"], "backend": "pacman", "provenance": "arch_official", "is_open_source": True, "installed": False},
        {"id": "spotify", "name": "Spotify", "summary": "Music streaming", "publisher": "Spotify", "categories": ["Audio"], "collections": ["everyday-essentials"], "aliases": ["music"], "tags": ["streaming"], "backend": "flatpak", "provenance": "flathub_verified", "is_open_source": False, "installed": False},
        {"id": "mystery", "name": "Mystery Tool", "summary": "Custom AUR helper", "publisher": "Community", "categories": ["Utilities"], "collections": [], "backend": "aur", "provenance": "community_package", "is_open_source": True, "installed": False},
    ]
    env = {"command": "store list", "ok": True, "message": "ok", "data": {"apps": apps}}
    out = run_js(f"""
        const parsed = parseStoreList({json.dumps(env)});
        return {{
            byAlias: filterApps(parsed.apps, "photoshop", "", "", false, false).map(a => a.id),
            verifiedOpen: filterApps(parsed.apps, "", "", "", true, true).map(a => a.id),
            byCol: filterApps(parsed.apps, "", "", "everyday-essentials", false, false).map(a => a.id),
            launcherShort: filterUninstalledForLauncher(parsed.apps, [], "g", 4),
            launcherMatch: filterUninstalledForLauncher(parsed.apps, [{{"id": "gimp.desktop", "name": "GIMP"}}], "gi", 4),
            launcherSpotify: filterUninstalledForLauncher(parsed.apps, [{{"id": "gimp.desktop", "name": "GIMP"}}], "spot", 4)
        }};
    """)
    assert out["byAlias"] == ["gimp"]
    assert out["verifiedOpen"] == ["zen", "gimp"]
    assert out["byCol"] == ["zen", "spotify"]
    assert out["launcherShort"] == []
    assert out["launcherMatch"] == []
    assert len(out["launcherSpotify"]) == 1
    assert out["launcherSpotify"][0]["id"] == "spotify"
    assert out["launcherSpotify"][0]["backendPill"] == "FLATPAK"
    assert out["launcherSpotify"][0]["provenanceText"] == "Flathub Verified"


def test_parsers_handle_malformed_and_all_endpoints():
    show_env = {
        "command": "store show",
        "ok": True,
        "message": "ok",
        "data": {
            "app": json.dumps({
                "id": "ollama",
                "name": "Ollama",
                "summary": "Run local LLMs",
                "backend": "pacman",
                "provenance": "arch_official",
                "is_open_source": True,
                "recommended_source": {"backend": "pacman", "provenance": "arch_official", "reason": "Official Arch repo with GPU support"},
                "alternative_sources": [{"backend": "vendor_official", "provenance": "vendor_official_binary", "reason": "Upstream tarball"}],
            })
        },
    }
    profiles_env = {
        "command": "store profiles",
        "ok": True,
        "message": "9 profiles",
        "data": {
            "profiles": json.dumps([
                {"id": "ai-workstation", "name": "AI-native Workstation", "description": "Local models & coding agents", "apps": [{"id": "ollama", "name": "Ollama", "optional": False}, {"id": "zed", "name": "Zed", "optional": True}]}
            ])
        },
    }
    sources_env = {
        "command": "store sources",
        "ok": True,
        "message": "ok",
        "data": {"sources": json.dumps([{"id": "flatpak", "available": True, "enabled": True, "scope": "user"}])}
    }
    policy_env = {
        "command": "store policy",
        "ok": True,
        "message": "ok",
        "data": {"verified_only": "true", "open_source_only": "false", "aur_policy": "explicit_opt_in", "proprietary_policy": "explicit_consent", "allowed_sources": json.dumps(["arch_official", "flathub_verified"])}
    }
    queue_env = {
        "command": "store queue list",
        "ok": True,
        "message": "ok",
        "data": {"running": "false", "queue": json.dumps([{"id": "job-1", "app_id": "ollama", "name": "Ollama", "action": "install", "status": "queued"}])}
    }
    doctor_env = {
        "command": "store doctor",
        "ok": True,
        "message": "ok",
        "data": {"healthy": "true", "checks": json.dumps([{"id": "flathub", "name": "Flathub user remote", "ok": True, "detail": "configured"}])}
    }
    out = run_js(f"""
        return {{
            badList: parseStoreList("{{broken"),
            emptyList: parseStoreList(null),
            failList: parseStoreList({json.dumps({"ok": False, "message": "catalog missing\ndetails", "data": {}})}),
            show: parseStoreShow({json.dumps(show_env)}),
            profiles: parseStoreProfiles({json.dumps(profiles_env)}),
            sources: parseStoreSources({json.dumps(sources_env)}),
            policy: parseStorePolicy({json.dumps(policy_env)}),
            queue: parseStoreQueue({json.dumps(queue_env)}),
            doctor: parseStoreDoctor({json.dumps(doctor_env)})
        }};
    """)
    assert out["badList"]["available"] is False and out["badList"]["apps"] == []
    assert out["emptyList"]["available"] is False
    assert out["failList"]["available"] is False and out["failList"]["error"] == "catalog missing"
    assert out["show"]["available"] is True
    assert out["show"]["app"]["recommendedSource"]["reason"] == "Official Arch repo with GPU support"
    assert len(out["show"]["app"]["alternativeSources"]) == 1
    assert out["profiles"]["available"] is True and len(out["profiles"]["profiles"][0]["apps"]) == 2
    assert out["sources"]["sources"][0]["available"] is True
    assert out["policy"]["policy"]["verifiedOnly"] is True
    assert out["policy"]["policy"]["allowedSources"] == ["arch_official", "flathub_verified"]
    assert out["queue"]["items"][0]["appId"] == "ollama"
    assert out["doctor"]["healthy"] is True and out["doctor"]["checks"][0]["ok"] is True


def test_apps_ui_and_integration_contracts():
    apps_dir = ROOT / "modules" / "apps"
    store_qml = (apps_dir / "AppsStore.qml").read_text(encoding="utf-8")
    window_qml = (apps_dir / "AppsWindow.qml").read_text(encoding="utf-8")
    detail_qml = (apps_dir / "AppDetailView.qml").read_text(encoding="utf-8")
    card_qml = (apps_dir / "AppCard.qml").read_text(encoding="utf-8")

    # Single-writer rule: no direct pacman/flatpak/shell commands in apps UI.
    import re
    for src in (store_qml, window_qml, detail_qml, card_qml):
        code_only = "\n".join(l for l in src.splitlines() if not l.strip().startswith("//"))
        assert "sh -c" not in code_only
        assert not re.search(r'\[\s*"(?:pacman|flatpak|yay|paru)"', code_only)
    for qml in apps_dir.glob("*.qml"):
        text = qml.read_text(encoding="utf-8")
        assert not re.search(r"#[0-9a-fA-F]{3,8}\b", text), f"hardcoded color in {qml.name}"

    assert '"horneroctl", "--json", "store", "list"' in store_qml
    assert '"horneroctl", "--json", "store", "search"' in store_qml
    assert '"horneroctl", "--json", "store", "show"' in store_qml
    assert '"horneroctl", "--json", "store", "profiles"' in store_qml
    assert '"horneroctl", "--json", "store", "installed"' in store_qml
    assert '"horneroctl", "--json", "store", "queue", "add"' in store_qml
    assert '"horneroctl", "--json", "store", "policy", "set"' in store_qml
    assert '"horneroctl", "--json", "store", "appimage", "import"' in store_qml
    assert '"horneroctl", "--json", "store", "webapp", "add"' in store_qml

    for view in ("discover", "ai", "categories", "collections", "installed", "updates", "queue", "sources"):
        assert f'"{view}"' in window_qml

    assert "Not sandboxed by default" in detail_qml
    assert "User data is preserved" in detail_qml
    assert "Manage in Flatseal" in detail_qml
    assert "Review AUR PKGBUILD" in detail_qml
    assert "View Setup Guide" in detail_qml
    assert "Open Web App" in detail_qml

    shortcuts = (ROOT / "modules" / "Shortcuts.qml").read_text(encoding="utf-8")
    assert 'target: "apps"' in shortcuts
    assert "AppsStore.open" in shortcuts

    launcher_apps = (ROOT / "modules" / "launcher" / "services" / "Apps.qml").read_text(encoding="utf-8")
    launcher_item = (ROOT / "modules" / "launcher" / "items" / "AppItem.qml").read_text(encoding="utf-8")
    assert "CatalogApps.search" in launcher_apps
    assert "Available in Hornero Apps" in launcher_item
    assert "AppsStore.open" in launcher_item

    welcome_page = (ROOT / "modules" / "welcome" / "pages" / "AppsPage.qml").read_text(encoding="utf-8")
    welcome_panel = (ROOT / "modules" / "welcome" / "AppsProfilePanel.qml").read_text(encoding="utf-8")
    assert "AppsProfilePanel" in welcome_page
    assert "Actions.queueAppIds" in welcome_panel
    assert 'Actions.openApps("queue")' in welcome_panel


pragma Singleton

import "../../services/welcome_model.js" as WelcomeModel
import Quickshell
import qs.modules.welcome as WelcomeModule
import QtQuick

// Welcome controller: owns the top-level 3-mode window lifecycle,
// First Flight 9-scene rail, Explore hub, What's New view, and 100%
// backwards-compatible IPC routing for legacy page IDs.
Singleton {
    id: root

    readonly property list<string> modes: ["first-flight", "explore", "whats-new"]
    readonly property list<string> scenes: [
        "arrival",
        "personalize",
        "workstation",
        "companion",
        "practice",
        "extensions",
        "showcase",
        "trust",
        "ready"
    ]
    readonly property list<string> coreScenes: [
        "arrival",
        "personalize",
        "workstation",
        "companion",
        "ready"
    ]
    // Preserved legacy + new page list for pageValid() and IPC callers.
    readonly property list<string> pages: [
        "start", "navigate", "shell", "workspaces", "personalize", "tools",
        "apps", "javi", "settings", "system", "learn", "shortcuts",
        "first-flight", "explore", "whats-new",
        "arrival", "workstation", "companion", "practice", "extensions",
        "showcase", "trust", "ready"
    ]

    property string mode: "first-flight"
    property string currentScene: "arrival"
    property string exploreSubView: "features"
    property string exploreCategory: ""
    property string currentPage: "start"
    property int navDirection: 1
    property bool opened: false
    property var _win: null

    readonly property int sceneIndex: Math.max(0, root.scenes.indexOf(root.currentScene))

    function pageValid(page: string): bool {
        return WelcomeModel.isValidTarget(page);
    }

    function open(page: string): void {
        const raw = (page ?? "").toString().trim().toLowerCase();
        const resolved = WelcomeModel.resolveOpenTarget(raw, WelcomeModule.State.snapshotObject());
        if (raw !== "" && resolved.unknown)
            console.warn(`[welcome] Unknown page "${page}" — opening arrival`);

        root.mode = resolved.mode;
        if (resolved.mode === "first-flight") {
            const nextScene = resolved.scene || "arrival";
            const oldIdx = root.sceneIndex;
            const newIdx = Math.max(0, root.scenes.indexOf(nextScene));
            root.navDirection = newIdx >= oldIdx ? 1 : -1;
            root.currentScene = nextScene;
            WelcomeModule.State.setLastVisitedScene(nextScene);
        } else if (resolved.mode === "explore") {
            root.exploreSubView = resolved.view || "features";
            root.exploreCategory = resolved.category || "";
        } else if (resolved.mode === "whats-new") {
            WelcomeModule.State.markReleaseSeen("");
        }

        root.currentPage = raw !== "" && !resolved.unknown ? raw : (resolved.mode === "first-flight" ? root.currentScene : resolved.mode);

        // Every opening (automatic or manual) records the session sighting.
        WelcomeModule.Session.noteAlreadySeen();

        if (root._win !== null) {
            root.opened = true;
            return;
        }
        const comp = Qt.createComponent(Qt.resolvedUrl("Window.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("[welcome] Could not load Window.qml:", comp.errorString());
            return;
        }
        root._win = comp.createObject();
        if (root._win === null) {
            console.warn("[welcome] Could not create welcome window");
            return;
        }
        root.opened = true;
    }

    function setMode(nextMode: string): void {
        const m = (nextMode ?? "").toString().trim().toLowerCase();
        if (root.modes.indexOf(m) === -1)
            return;
        root.mode = m;
        if (m === "explore" && root.exploreSubView === "")
            root.exploreSubView = "features";
        if (m === "whats-new")
            WelcomeModule.State.markReleaseSeen("");
        root.currentPage = m === "first-flight" ? root.currentScene : m;
    }

    function goToScene(sceneId: string): void {
        const s = (sceneId ?? "").toString().trim().toLowerCase();
        const idx = root.scenes.indexOf(s);
        if (idx === -1)
            return;
        root.navDirection = idx >= root.sceneIndex ? 1 : -1;
        root.mode = "first-flight";
        root.currentScene = s;
        root.currentPage = s;
        WelcomeModule.State.setLastVisitedScene(s);
    }

    function nextScene(): void {
        const idx = root.sceneIndex;
        if (idx < root.scenes.length - 1)
            root.goToScene(root.scenes[idx + 1]);
        else
            root.completeFirstFlight();
    }

    function prevScene(): void {
        const idx = root.sceneIndex;
        if (idx > 0)
            root.goToScene(root.scenes[idx - 1]);
    }

    function skipToDesktop(): void {
        WelcomeModule.State.markFirstRunCompleted();
        root.close();
    }

    function completeFirstFlight(): void {
        WelcomeModule.State.markFirstRunCompleted();
        root.close();
    }

    function close(): void {
        if (WelcomeModule.PreviewTransaction.dirty)
            WelcomeModule.PreviewTransaction.revert();
        root.opened = false;
        if (root._win !== null) {
            const w = root._win;
            root._win = null;
            w.destroy();
        }
    }

    function toggle(page: string): void {
        if (root.opened)
            root.close();
        else
            root.open(page);
    }

    function status(): var {
        return {
            open: root.opened,
            mode: root.mode,
            scene: root.currentScene,
            page: root.currentPage,
            showOnLogin: WelcomeModule.State.showOnLogin,
            firstRunCompleted: WelcomeModule.State.firstRunCompleted,
            previewDirty: WelcomeModule.PreviewTransaction.dirty
        };
    }
}

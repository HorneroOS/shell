pragma Singleton

import "../../services/store.js" as Store
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Hornero Apps controller & single-writer backend bridge.
// Owns the standalone FloatingWindow lifecycle (open/close/toggle/status)
// and every `horneroctl --json store ...` invocation via fixed argv arrays.
// Never invokes pacman, flatpak, aur helpers, or shell scripts directly.
Singleton {
    id: root

    readonly property list<string> views: ["discover", "ai", "categories", "collections", "installed", "updates", "queue", "sources"]

    property string currentView: "discover"
    property string selectedAppId: ""
    property bool opened: false
    property var _win: null

    // Catalog & search state (shared with Launcher & Welcome)
    property bool catalogLoading: false
    property bool catalogLoaded: false
    property bool catalogAvailable: true
    property string catalogError: ""
    property var catalogApps: []
    property var categories: []
    property var collections: []
    property var profiles: []
    property bool profilesLoading: false
    property string profilesError: ""

    property string searchQuery: ""
    property bool searchLoading: false
    property var searchResults: []
    property bool searchActive: false

    // Selected app detail
    property var selectedApp: null
    property bool detailLoading: false
    property string detailError: ""
    property var selectedPermissions: ({
            "available": false,
            "sandboxed": false,
            "permissions": [],
            "note": "",
            "error": ""
        })

    // Installed / Updates / Queue / Sources / Policy / Doctor
    property var installedApps: []
    property bool installedLoading: false
    property string installedError: ""

    property var updates: []
    property bool updatesLoading: false
    property string updatesError: ""

    property var queueItems: []
    property bool queueRunning: false
    property bool queueLoading: false
    property string queueError: ""

    property var sources: []
    property bool sourcesLoading: false
    property string sourcesError: ""

    property var policy: ({
            "verifiedOnly": false,
            "openSourceOnly": false,
            "aurPolicy": "explicit_opt_in",
            "proprietaryPolicy": "explicit_consent",
            "flatpakDefaultScope": "user",
            "allowedSources": []
        })
    property bool policyAvailable: false
    property string policyError: ""

    property var doctorReport: ({
            "available": false,
            "healthy": false,
            "checks": [],
            "error": ""
        })
    property bool doctorLoading: false

    // Single-writer mutation queue
    property bool busy: false
    property string activeJobLabel: ""
    property string activeJobTarget: ""
    property string lastError: ""
    property string lastSuccess: ""
    property var _retrySpec: null

    function viewValid(view: string): bool {
        return root.views.includes(view);
    }

    function open(appIdOrView: string): void {
        const arg = (appIdOrView ?? "").toString().trim();
        const lower = arg.toLowerCase();
        if (lower === "" || lower === "explore") {
            root.currentView = "discover";
            root.selectedAppId = "";
            root.selectedApp = null;
        } else if (root.viewValid(lower)) {
            root.currentView = lower;
            root.selectedAppId = "";
            root.selectedApp = null;
        } else {
            root.selectApp(arg);
        }

        if (!root.catalogLoaded && !root.catalogLoading)
            root.refreshAll();

        if (root._win !== null) {
            root.opened = true;
            return;
        }
        const comp = Qt.createComponent(Qt.resolvedUrl("AppsWindow.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("[apps] Could not load AppsWindow.qml:", comp.errorString());
            return;
        }
        root._win = comp.createObject();
        if (root._win === null) {
            console.warn("[apps] Could not create Hornero Apps window");
            return;
        }
        root.opened = true;
    }

    function close(): void {
        root.opened = false;
        if (root._win !== null) {
            const w = root._win;
            root._win = null;
            w.destroy();
        }
    }

    function toggle(appIdOrView: string): void {
        if (root.opened && (!appIdOrView || appIdOrView.trim() === ""))
            root.close();
        else
            root.open(appIdOrView ?? "");
    }

    function status(): var {
        return {
            open: root.opened,
            view: root.currentView,
            selectedAppId: root.selectedAppId,
            busy: root.busy,
            queueCount: root.queueItems.length
        };
    }

    function clearMessages(): void {
        root.lastError = "";
        root.lastSuccess = "";
    }

    function appById(appId: string): var {
        const key = (appId ?? "").trim();
        if (key === "")
            return null;
        for (let i = 0; i < root.catalogApps.length; i++) {
            if (root.catalogApps[i].id === key)
                return root.catalogApps[i];
        }
        for (let j = 0; j < root.installedApps.length; j++) {
            if (root.installedApps[j].id === key)
                return root.installedApps[j];
        }
        return null;
    }

    function selectApp(appId: string): void {
        const key = (appId ?? "").trim();
        root.selectedAppId = key;
        root.detailError = "";
        root.lastError = "";
        root.lastSuccess = "";
        if (key === "") {
            root.selectedApp = null;
            return;
        }
        const cached = root.appById(key);
        if (cached)
            root.selectedApp = cached;
        root.loadAppDetail(key);
    }

    function clearSelectedApp(): void {
        root.selectedAppId = "";
        root.selectedApp = null;
        root.detailError = "";
    }

    function ensureCatalogLoaded(): void {
        if (!root.catalogLoaded && !root.catalogLoading)
            root.refreshCatalog();
    }

    function refreshAll(): void {
        root.refreshCatalog();
        root.refreshCategories();
        root.refreshCollections();
        root.refreshProfiles();
        root.refreshInstalled();
        root.refreshUpdates();
        root.refreshQueue();
        root.refreshSources();
        root.refreshPolicy();
        root.refreshDoctor();
    }

    function refreshCatalog(): void {
        if (catalogProc.running)
            return;
        root.catalogLoading = true;
        root.catalogError = "";
        catalogProc.command = ["horneroctl", "--json", "store", "list"];
        catalogProc.running = true;
    }

    function searchCatalog(queryText: string): void {
        const q = (queryText ?? "").trim();
        root.searchQuery = q;
        if (q.length === 0) {
            root.searchActive = false;
            root.searchResults = [];
            return;
        }
        root.searchActive = true;
        root.searchResults = Store.filterApps(
            root.catalogApps,
            q,
            "",
            "",
            root.policy.verifiedOnly === true,
            root.policy.openSourceOnly === true
        );
        if (searchProc.running)
            searchProc.running = false;
        root.searchLoading = true;
        searchProc.targetQuery = q;
        searchProc.command = ["horneroctl", "--json", "store", "search", q];
        searchProc.running = true;
    }

    function loadAppDetail(appId: string): void {
        const id = (appId ?? "").trim();
        if (id === "")
            return;
        if (showProc.running)
            showProc.running = false;
        root.detailLoading = true;
        root.detailError = "";
        showProc.targetId = id;
        showProc.command = ["horneroctl", "--json", "store", "show", id];
        showProc.running = true;

        if (permsProc.running)
            permsProc.running = false;
        permsProc.targetId = id;
        permsProc.command = ["horneroctl", "--json", "store", "permissions", id];
        permsProc.running = true;
    }

    function refreshCategories(): void {
        if (categoriesProc.running)
            return;
        categoriesProc.command = ["horneroctl", "--json", "store", "categories"];
        categoriesProc.running = true;
    }

    function refreshCollections(): void {
        if (collectionsProc.running)
            return;
        collectionsProc.command = ["horneroctl", "--json", "store", "collections"];
        collectionsProc.running = true;
    }

    function refreshProfiles(): void {
        if (profilesProc.running)
            return;
        root.profilesLoading = true;
        root.profilesError = "";
        profilesProc.command = ["horneroctl", "--json", "store", "profiles"];
        profilesProc.running = true;
    }

    function refreshInstalled(): void {
        if (installedProc.running)
            return;
        root.installedLoading = true;
        root.installedError = "";
        installedProc.command = ["horneroctl", "--json", "store", "installed"];
        installedProc.running = true;
    }

    function refreshUpdates(): void {
        if (updatesProc.running)
            return;
        root.updatesLoading = true;
        root.updatesError = "";
        updatesProc.command = ["horneroctl", "--json", "store", "update", "--all", "--dry-run"];
        updatesProc.running = true;
    }

    function refreshQueue(): void {
        if (queueProc.running)
            return;
        root.queueLoading = true;
        root.queueError = "";
        queueProc.command = ["horneroctl", "--json", "store", "queue", "list"];
        queueProc.running = true;
    }

    function refreshSources(): void {
        if (sourcesProc.running)
            return;
        root.sourcesLoading = true;
        root.sourcesError = "";
        sourcesProc.command = ["horneroctl", "--json", "store", "sources"];
        sourcesProc.running = true;
    }

    function refreshPolicy(): void {
        if (policyProc.running)
            return;
        root.policyError = "";
        policyProc.command = ["horneroctl", "--json", "store", "policy"];
        policyProc.running = true;
    }

    function refreshDoctor(): void {
        if (doctorProc.running)
            return;
        root.doctorLoading = true;
        doctorProc.command = ["horneroctl", "--json", "store", "doctor"];
        doctorProc.running = true;
    }

    function _runMutation(kind: string, target: string, label: string, argv: var): void {
        if (root.busy || mutProc.running)
            return;
        root.busy = true;
        root.activeJobLabel = label;
        root.activeJobTarget = target;
        root.lastError = "";
        root.lastSuccess = "";
        root._retrySpec = {
            kind: kind,
            target: target,
            label: label,
            argv: argv
        };
        mutProc.mutKind = kind;
        mutProc.targetId = target;
        mutProc.command = argv;
        mutProc.running = true;
    }

    function retryLastAction(): void {
        if (!root._retrySpec || root.busy)
            return;
        const spec = root._retrySpec;
        root._runMutation(spec.kind, spec.target, spec.label, spec.argv);
    }

    function installApp(appId: string, sourceId: string, acceptProprietary: bool, acceptAur: bool): void {
        const id = (appId ?? "").trim();
        if (id === "")
            return;
        const argv = ["horneroctl", "--json", "store", "install", id];
        if (sourceId && sourceId.trim() !== "") {
            argv.push("--source", sourceId.trim());
        }
        if (acceptProprietary)
            argv.push("--accept-proprietary");
        if (acceptAur)
            argv.push("--accept-aur");
        argv.push("--yes");
        root._runMutation("install", id, qsTr("Installing %1…").arg(id), argv);
    }

    function removeApp(appId: string): void {
        const id = (appId ?? "").trim();
        if (id === "")
            return;
        root._runMutation("remove", id, qsTr("Removing %1…").arg(id), ["horneroctl", "--json", "store", "remove", id, "--yes"]);
    }

    function updateApp(appId: string): void {
        const id = (appId ?? "").trim();
        if (id === "")
            return;
        root._runMutation("update", id, qsTr("Updating %1…").arg(id), ["horneroctl", "--json", "store", "update", id, "--yes"]);
    }

    function updateAll(): void {
        root._runMutation("update", "all", qsTr("Updating all applications…"), ["horneroctl", "--json", "store", "update", "--all", "--yes"]);
    }

    function queueAdd(appIds: var): void {
        if (!Array.isArray(appIds) || appIds.length === 0)
            return;
        const clean = appIds.map(x => String(x || "").trim()).filter(x => x.length > 0);
        if (clean.length === 0)
            return;
        const argv = ["horneroctl", "--json", "store", "queue", "add"];
        for (let i = 0; i < clean.length; i++)
            argv.push(clean[i]);
        argv.push("--yes");
        root._runMutation("queue-add", clean.join(","), qsTr("Adding %1 app(s) to queue…").arg(clean.length), argv);
    }

    function queueRun(): void {
        root._runMutation("queue-run", "queue", qsTr("Running installation queue…"), ["horneroctl", "--json", "store", "queue", "run", "--yes"]);
    }

    function queueClear(): void {
        root._runMutation("queue-clear", "queue", qsTr("Clearing installation queue…"), ["horneroctl", "--json", "store", "queue", "clear", "--yes"]);
    }

    function importAppImage(filePath: string, appName: string): void {
        const p = (filePath ?? "").trim();
        if (p === "")
            return;
        const argv = ["horneroctl", "--json", "store", "appimage", "import", p];
        const n = (appName ?? "").trim();
        if (n !== "")
            argv.push("--name", n);
        argv.push("--yes");
        root._runMutation("appimage-import", p, qsTr("Importing AppImage…"), argv);
    }

    function addWebApp(name: string, url: string, profile: string): void {
        const n = (name ?? "").trim();
        const u = (url ?? "").trim();
        if (n === "" || u === "")
            return;
        const argv = ["horneroctl", "--json", "store", "webapp", "add", "--name", n, "--url", u];
        const prof = (profile ?? "").trim();
        if (prof !== "")
            argv.push("--profile", prof);
        argv.push("--yes");
        root._runMutation("webapp-add", n, qsTr("Creating Web App %1…").arg(n), argv);
    }

    function updatePolicy(nextPolicy: var): void {
        if (!nextPolicy || typeof nextPolicy !== "object")
            return;
        const argv = [
            "horneroctl", "--json", "store", "policy", "set",
            "--verified-only", nextPolicy.verifiedOnly ? "true" : "false",
            "--open-source-only", nextPolicy.openSourceOnly ? "true" : "false",
            "--aur-policy", String(nextPolicy.aurPolicy || "explicit_opt_in"),
            "--proprietary-policy", String(nextPolicy.proprietaryPolicy || "explicit_consent"),
            "--yes"
        ];
        root._runMutation("policy-set", "policy", qsTr("Updating software policy…"), argv);
    }

    function exportManifest(outputPath: string): void {
        const p = (outputPath ?? "").trim();
        if (p === "")
            return;
        root._runMutation("manifest-export", p, qsTr("Exporting application manifest…"), ["horneroctl", "--json", "store", "manifest", "export", p, "--yes"]);
    }

    function importManifest(inputPath: string): void {
        const p = (inputPath ?? "").trim();
        if (p === "")
            return;
        root._runMutation("manifest-import", p, qsTr("Importing application manifest…"), ["horneroctl", "--json", "store", "manifest", "import", p, "--yes"]);
    }

    function launchApp(app: var): void {
        if (!app)
            return;
        const desktopId = String(app.desktopId || "");
        if (desktopId !== "") {
            const entry = DesktopEntries.byId(desktopId) ?? DesktopEntries.byId(desktopId.replace(/\.desktop$/, ""));
            if (entry) {
                entry.execute();
                return;
            }
        }
        const id = String(app.id || "");
        if (id !== "")
            root._runMutation("launch", id, qsTr("Opening %1…").arg(app.name || id), ["horneroctl", "--json", "store", "launch", id]);
    }

    function openExternalUrl(url: string): void {
        const u = (url ?? "").trim();
        if (u.startsWith("https://"))
            Quickshell.execDetached(["xdg-open", u]);
    }

    function openFlatseal(): void {
        const entry = DesktopEntries.byId("com.github.tchx84.Flatseal") ?? DesktopEntries.byId("com.github.tchx84.Flatseal.desktop");
        if (entry) {
            entry.execute();
            return;
        }
        root.lastError = qsTr("Flatseal is not installed. Search for Flatseal in Hornero Apps to manage Flatpak permissions visually.");
    }

    // ── Processes ───────────────────────────────────────────────────────────

    Process {
        id: catalogProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreList(text, Language.uiLocale);
                root.catalogAvailable = res.available;
                root.catalogError = res.available ? "" : res.error;
                if (res.available)
                    root.catalogApps = res.apps;
                root.catalogLoaded = true;
                root.catalogLoading = false;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.catalogLoading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && !root.catalogLoaded) {
                root.catalogAvailable = false;
                root.catalogError = qsTr("Hornero Apps backend is unavailable (horneroctl store exited %1).").arg(exitCode);
            }
        }
    }

    Process {
        id: searchProc

        property string targetQuery: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProc.targetQuery !== root.searchQuery)
                    return;
                const res = Store.parseStoreSearch(text, Language.uiLocale);
                root.searchLoading = false;
                if (res.available)
                    root.searchResults = res.apps;
            }
        }
        onExited: () => {
            root.searchLoading = false;
        }
    }

    Process {
        id: showProc

        property string targetId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (showProc.targetId !== root.selectedAppId)
                    return;
                const res = Store.parseStoreShow(text, Language.uiLocale);
                root.detailLoading = false;
                if (res.available && res.app) {
                    root.selectedApp = res.app;
                    root.detailError = "";
                } else if (!root.selectedApp) {
                    root.detailError = res.error || qsTr("Could not load application details.");
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.detailLoading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && !root.selectedApp && root.detailError === "")
                root.detailError = qsTr("Could not load application details (exit %1).").arg(exitCode);
        }
    }

    Process {
        id: permsProc

        property string targetId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (permsProc.targetId !== root.selectedAppId)
                    return;
                root.selectedPermissions = Store.parseStorePermissions(text);
            }
        }
    }

    Process {
        id: categoriesProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreCategories(text, Language.uiLocale);
                if (res.available)
                    root.categories = res.categories;
            }
        }
    }

    Process {
        id: collectionsProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreCollections(text, Language.uiLocale);
                if (res.available)
                    root.collections = res.collections;
            }
        }
    }

    Process {
        id: profilesProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreProfiles(text);
                root.profilesLoading = false;
                if (res.available) {
                    root.profiles = res.profiles;
                    root.profilesError = "";
                } else {
                    root.profilesError = res.error;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.profilesLoading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.profiles.length === 0 && root.profilesError === "")
                root.profilesError = qsTr("Workstation profiles unavailable (exit %1).").arg(exitCode);
        }
    }

    Process {
        id: installedProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreInstalled(text, Language.uiLocale);
                root.installedLoading = false;
                if (res.available) {
                    root.installedApps = res.apps;
                    root.installedError = "";
                } else {
                    root.installedError = res.error;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.installedLoading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.installedApps.length === 0 && root.installedError === "")
                root.installedError = qsTr("Could not check installed applications.");
        }
    }

    Process {
        id: updatesProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreUpdates(text);
                root.updatesLoading = false;
                if (res.available) {
                    root.updates = res.updates;
                    root.updatesError = "";
                } else {
                    root.updatesError = res.error;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.updatesLoading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.updates.length === 0 && root.updatesError === "")
                root.updatesError = qsTr("Could not check for application updates.");
        }
    }

    Process {
        id: queueProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreQueue(text);
                root.queueLoading = false;
                if (res.available) {
                    root.queueItems = res.items;
                    root.queueRunning = res.running;
                    root.queueError = "";
                } else {
                    root.queueError = res.error;
                }
            }
        }
        onExited: () => {
            root.queueLoading = false;
        }
    }

    Process {
        id: sourcesProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreSources(text);
                root.sourcesLoading = false;
                if (res.available) {
                    root.sources = res.sources;
                    root.sourcesError = "";
                } else {
                    root.sourcesError = res.error;
                }
            }
        }
        onExited: () => {
            root.sourcesLoading = false;
        }
    }

    Process {
        id: policyProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStorePolicy(text);
                root.policyAvailable = res.available;
                if (res.available) {
                    root.policy = res.policy;
                    root.policyError = "";
                } else {
                    root.policyError = res.error;
                }
            }
        }
    }

    Process {
        id: doctorProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.doctorLoading = false;
                root.doctorReport = Store.parseStoreDoctor(text);
            }
        }
        onExited: () => {
            root.doctorLoading = false;
        }
    }

    Process {
        id: mutProc

        property string mutKind: ""
        property string targetId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Store.parseStoreAction(text);
                if (!res.ok) {
                    root.lastError = res.error || qsTr("Action failed.");
                } else {
                    root.lastSuccess = res.message || qsTr("Completed.");
                    root._retrySpec = null;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.lastError === "" && root.lastSuccess === "")
                    root.lastError = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            root.activeJobLabel = "";
            root.activeJobTarget = "";
            if ((exitCode !== 0 || exitStatus !== 0) && root.lastError === "" && root.lastSuccess === "")
                root.lastError = qsTr("Operation failed (exit %1).").arg(exitCode);
            root.refreshCatalog();
            root.refreshInstalled();
            root.refreshUpdates();
            root.refreshQueue();
            root.refreshPolicy();
            if (root.selectedAppId !== "")
                root.loadAppDetail(root.selectedAppId);
        }
    }
}

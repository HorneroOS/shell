pragma Singleton

import "../../services/welcome_model.js" as WelcomeModel
import qs.config
import qs.modules.apps
import qs.modules.companion
import qs.modules.controlcenter
import qs.modules.welcome as WelcomeModule
import qs.services
import Quickshell
import QtQuick

// Allowlisted in-shell actions and typed deep-link dispatcher for the
// Welcome Center. Scenes and views trigger ONLY these functions: no ad-hoc
// execDetached, no Process, no arbitrary shell commands, no external URLs.
Singleton {
    id: root

    readonly property bool hasFullscreen: Compositor.hasFullscreenOnFocusedOutput()

    // Reactive Hornero Apps bindings (read-only view into AppsStore).
    readonly property var appProfiles: AppsStore.profiles
    readonly property bool appProfilesLoading: AppsStore.profilesLoading
    readonly property string appProfilesError: AppsStore.profilesError
    readonly property bool appsBusy: AppsStore.busy
    readonly property string appsLastError: AppsStore.lastError
    readonly property string appsLastSuccess: AppsStore.lastSuccess
    readonly property var catalogApps: AppsStore.catalogApps
    readonly property var storeCollections: AppsStore.collections
    readonly property var storeDoctor: AppsStore.doctorReport

    // Reactive Extensions bindings.
    readonly property var extensionCatalogue: ExtensionStore.catalogue
    readonly property bool extensionCatalogueLoading: ExtensionStore.catalogueLoading
    readonly property string extensionCatalogueError: ExtensionStore.catalogueError
    readonly property bool extensionBusy: ExtensionStore.busy
    readonly property var installedPlugins: Plugins.entries

    function openLauncher(): void {
        if (root.hasFullscreen)
            return;
        const v = Visibilities.getForActive();
        if (v)
            v.launcher = true;
    }

    function openDashboard(): void {
        if (root.hasFullscreen)
            return;
        const v = Visibilities.getForActive();
        if (v)
            v.dashboard = true;
    }

    function openSessionMenu(): void {
        if (root.hasFullscreen)
            return;
        const v = Visibilities.getForActive();
        if (v)
            v.session = true;
    }

    function openUtilities(): void {
        if (root.hasFullscreen)
            return;
        const v = Visibilities.getForActive();
        if (v)
            v.utilities = true;
    }

    function openLayoutPicker(): void {
        if (root.hasFullscreen)
            return;
        const v = Visibilities.getForActive();
        if (v)
            v.layoutPicker = true;
    }

    function openControlCenter(pane: string, keepWelcomeOpen: bool): void {
        const raw = (pane ?? "").toString().trim();
        const resolved = raw !== "" ? PaneRegistry.resolveTarget(raw) : null;
        const opened = resolved
            ? WindowFactory.create(null, { pane: resolved.pane, section: resolved.section })
            : WindowFactory.create();
        if (opened && !keepWelcomeOpen)
            WelcomeModule.Welcome.close();
    }

    function openControlCenterSection(pane: string, section: string): void {
        const p = (pane ?? "").toString().trim();
        const s = (section ?? "").toString().trim();
        const valid = p !== "" && PaneRegistry.getById(p);
        const opened = valid
            ? WindowFactory.create(null, { pane: p, section: s })
            : WindowFactory.create();
        if (opened)
            WelcomeModule.Welcome.close();
    }

    function shellQuote(arg: var): string {
        return `'${String(arg).replace(/'/g, `'\"'\"'`)}'`;
    }

    function openTerminal(): void {
        const quoted = [...Config.general.apps.terminal].map(a => root.shellQuote(a)).join(" ");
        const script = `if command -v app2unit >/dev/null 2>&1; then exec app2unit -- ${quoted}; else exec ${quoted}; fi`;
        Quickshell.execDetached({
            command: ["sh", "-lc", script]
        });
    }

    function openWelcome(page: string): void {
        WelcomeModule.Welcome.open(page ?? "start");
    }

    function openApps(viewOrAppId: string): void {
        AppsStore.open(viewOrAppId ?? "discover");
    }

    function ensureAppProfiles(): void {
        if (AppsStore.profiles.length === 0 && !AppsStore.profilesLoading)
            AppsStore.refreshProfiles();
        if (AppsStore.collections.length === 0)
            AppsStore.refreshCollections();
    }

    function refreshAppProfiles(): void {
        AppsStore.refreshProfiles();
    }

    function ensureCatalogApps(): void {
        AppsStore.ensureCatalogLoaded();
    }

    function queueAppIds(appIds: var): void {
        AppsStore.queueAdd(appIds);
    }

    function importAppsManifest(filePath: string): void {
        AppsStore.importManifest(filePath);
    }

    function ensureExtensionsLoaded(): void {
        if (ExtensionStore.catalogue.length === 0 && !ExtensionStore.catalogueLoading)
            ExtensionStore.refreshCatalogue();
    }

    function refreshExtensions(): void {
        ExtensionStore.refreshCatalogue();
    }

    function installExtension(pluginId: string, name: string): bool {
        return ExtensionStore.run("install", pluginId, name);
    }

    function toggleExtension(pluginId: string, enable: bool, name: string): bool {
        return ExtensionStore.run(enable ? "enable" : "disable", pluginId, name);
    }

    function openKeybindsOverlay(query: string): void {
        Keybinds.openOverlay(query ?? "");
    }

    function setExperienceMode(modeId: string): string {
        return Experience.set(modeId, "welcome");
    }

    function setLanguage(langCode: string): void {
        const next = (langCode ?? "").trim();
        if (next !== "en" && next !== "es_AR" && next !== "auto")
            return;
        Config.general.language = next;
        Config.save();
    }

    function setReducedMotion(enabled: bool): void {
        Config.appearance.reducedMotion = enabled === true;
        Config.save();
    }

    function setHighContrast(enabled: bool): void {
        Config.appearance.highContrast = enabled === true;
        Config.save();
    }

    function setMascotEnabled(enabled: bool): void {
        CompanionStore.enabled = enabled === true;
        CompanionStore.markDirty();
        WelcomeModule.State.setMascotEnabled(enabled === true);
    }

    function setCompanionSkin(skinId: string): void {
        if (Companion.isKnownSkin(skinId)) {
            CompanionStore.skin = skinId;
            CompanionStore.markDirty();
        }
    }

    function setFullscreenGamingAuto(enabled: bool): void {
        Experience.setAuto(enabled === true);
    }

    function refreshStoreDoctor(): void {
        AppsStore.refreshDoctor();
    }

    function executeTypedAction(actionOrUri: var): bool {
        const parsed = WelcomeModel.validateTypedAction(actionOrUri);
        if (!parsed.valid) {
            console.warn("[welcome] Rejected typed action:", parsed.reason);
            return false;
        }
        if (parsed.type === "welcome") {
            root.openWelcome(parsed.target);
            return true;
        }
        if (parsed.type === "controlCenter") {
            if (parsed.section !== "")
                root.openControlCenterSection(parsed.target, parsed.section);
            else
                root.openControlCenter(parsed.target, false);
            return true;
        }
        if (parsed.type === "drawer") {
            if (parsed.target === "launcher")
                root.openLauncher();
            else if (parsed.target === "dashboard")
                root.openDashboard();
            else if (parsed.target === "utilities")
                root.openUtilities();
            else if (parsed.target === "session")
                root.openSessionMenu();
            else if (parsed.target === "layoutPicker")
                root.openLayoutPicker();
            return true;
        }
        if (parsed.type === "apps") {
            root.openApps(parsed.target);
            return true;
        }
        if (parsed.type === "action") {
            if (parsed.target === "openTerminal")
                root.openTerminal();
            else if (parsed.target === "openKeybindsOverlay")
                root.openKeybindsOverlay("");
            else if (parsed.target === "openApps")
                root.openApps("discover");
            else if (parsed.target === "refreshDiagnostics")
                root.refreshStoreDoctor();
            return true;
        }
        return false;
    }
}

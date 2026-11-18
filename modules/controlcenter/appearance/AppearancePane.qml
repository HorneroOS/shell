pragma ComponentBehavior: Bound

import ".."
import "../components"
import "./sections"
import "../../launcher/services"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.components.images
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import qs.modules.controlcenter
import Hornero
import Hornero.Models
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../services/chromaticcli.js" as Cli

Item {
    id: root

    required property Session session

    property real animDurationsScale: Config.appearance.anim.durations.scale ?? 1
    property string fontFamilyMono: Config.appearance.font.family.mono ?? "IBM Plex Mono"
    property string fontFamilySans: Config.appearance.font.family.sans ?? "IBM Plex Sans"
    property string fontFamilyDisplay: Config.appearance.font.family.display ?? "IBM Plex Sans Condensed"
    property real fontSizeScale: Config.appearance.font.size.scale ?? 1
    property real paddingScale: Config.appearance.padding.scale ?? 1
    property real roundingScale: Config.appearance.rounding.scale ?? 1
    property real spacingScale: Config.appearance.spacing.scale ?? 1
    property bool transparencyEnabled: Config.appearance.transparency.enabled ?? false
    property real transparencyBase: Config.appearance.transparency.base ?? 0.85
    property real transparencyLayers: Config.appearance.transparency.layers ?? 0.4
    property var transparencyElements: Config.appearance.transparency.elements ?? ({})
    property real borderRounding: Config.border.rounding ?? 1
    property real borderThickness: Config.border.thickness ?? 1

    // Section disclosure: which sections start expanded. Persisted in
    // Config.controlCenter.appearanceOpenSections (default: Themes).
    // _sectionsReady guards write-back while initial state is restored.
    property bool _sectionsReady: false
    // Section order (docs/APPEARANCE-PANE.md): what you pick first comes
    // first. Colour (Themes, then Chromatic, then the tools that adjust the
    // palette in use), Wallpaper, Look & feel, Type & motion, Apps, Health.
    readonly property var _sectionKeys: ["themes", "chromatic", "accent", "themeEditor", "background", "look", "atmosphere", "transparency", "border", "fonts", "scales", "animations", "gtkTheme", "gtkColorScheme", "iconTheme", "health"]
    property var sectionItems: ({})
    property var sectionScroll: null

    function isSectionExpanded(key: string): bool {
        return Config.controlCenter.appearanceOpenSections.indexOf(key) !== -1;
    }

    function persistSection(key: string, expanded: bool): void {
        if (!root._sectionsReady)
            return;
        const list = Config.controlCenter.appearanceOpenSections.slice();
        const i = list.indexOf(key);
        if (expanded && i === -1)
            list.push(key);
        if (!expanded && i !== -1)
            list.splice(i, 1);
        Config.controlCenter.appearanceOpenSections = list;
        Config.save();
    }

    function setAllSections(expand: bool): void {
        root._sectionsReady = false;
        for (let i = 0; i < root._sectionKeys.length; i++) {
            const section = root.sectionItems[root._sectionKeys[i]];
            if (section)
                section.expanded = expand;
        }
        root._sectionsReady = true;
        Config.controlCenter.appearanceOpenSections = expand ? root._sectionKeys.slice() : [];
        Config.save();
    }

    function revealSection(key: string): void {
        const section = root.sectionItems[key];
        if (!section)
            return;
        section.expanded = true;
        root.persistSection(key, true);
        Qt.callLater(() => {
            const flickable = root.sectionScroll;
            if (flickable)
                flickable.contentY = Math.max(0, section.y - Appearance.padding.normal);
            if (root.session.requestedSection === key)
                root.session.requestedSection = "";
        });
    }

    Connections {
        target: root.session
        function onRequestedSectionChanged(): void {
            if (root.session.active === "appearance" && root.session.requestedSection)
                root.revealSection(root.session.requestedSection);
        }
        function onActiveChanged(): void {
            if (root.session.active === "appearance" && root.session.requestedSection)
                root.revealSection(root.session.requestedSection);
        }
    }

    // Single root completion handler: enabling section write-back
    // and resetting staged selections. (Two handlers here is a
    // compile error — "Property value set multiple times" — which
    // fails the whole pane load with a blank page.)
    Component.onCompleted: {
        root._sectionsReady = true;
        resetPendingSelections();
        syncCurrentThemePreview();
        if (root.session.active === "appearance" && root.session.requestedSection)
            Qt.callLater(() => root.revealSection(root.session.requestedSection));
    }

    // The preview has three states the user can tell apart at a glance
    // (AppearancePreviewPane banner, NowUsingStrip note):
    //   "now"        it shows what is applied
    //   "previewing" it shows something you are pointing at or focusing;
    //                nothing is applied until you click
    //   "applying"   a click is being applied
    readonly property bool hoverPreviewEnabled: Config.controlCenter.appearanceHoverPreview
    readonly property bool previewIsApplied: {
        if (!previewActive || previewSource === "current")
            return true;
        if (previewSource === "theme")
            return !!previewThemeId && previewThemeId === Signal.themeId && !Signal.previewing;
        if (previewSource === "wallpaper")
            return previewWallpaperPath === Wallpapers.actualCurrent;
        if (previewSource === "gtk-color-scheme")
            return normalizeGtkColorScheme(previewGtkColorScheme) === normalizeGtkColorScheme(GtkSettings.liveColorScheme || pendingGtkColorScheme);
        return false;
    }
    readonly property bool chromaticPointed: ChromaticPreview.hoveredVariant !== ""
    readonly property string previewState: (ThemePipeline.busy || ChromaticPreview.applying) ? "applying" : chromaticPointed ? "previewing" : previewIsApplied ? "now" : "previewing"

    // A hover/focus preview ended: go back to showing what is applied
    // (never to an empty card), unless something else took over.
    // A pointed Chromatic tile shows on the live desktop (ChromaticPreview).
    function endPreviewFor(source: string): void {
        if (previewSource !== source)
            return;
        clearPreview();
        syncCurrentThemePreview();
    }

    // Hover/focus entry points honour the user's preview-on-hover setting.
    function hoverThemePreview(modelData: var, resolvedWallpaper: string, readinessDetails: string): void {
        if (hoverPreviewEnabled)
            startThemePreview(modelData, resolvedWallpaper, readinessDetails);
    }

    function syncCurrentThemePreview(): void {
        if (!Signal.themeStateReady)
            return;

        // Keep an explicit hover/focus preview authoritative. This refresh
        // is for the idle/current preview only; a catalogue or wallpaper
        // update must not replace the item the user is exploring.
        if (previewActive && previewSource !== "current") {
            const previewIsAppliedTheme = previewSource === "theme"
                && !!Signal.themeId
                && previewThemeId === Signal.themeId;
            if (!previewIsAppliedTheme)
                return;
        }

        // Chromatic has no catalogue card: show its applied palette by name.
        if (Signal.themeId === "hornero-chromatic") {
            previewActive = true;
            previewSource = "current";
            resetPreviewRecipe();
            previewTitle = qsTr("Chromatic");
            const style = Cli.appliedStyle(Signal.chromatic);
            previewSubtitle = style ? qsTr("%1 · built from your wallpaper or colour").arg(Cli.styleLabel(style)) : qsTr("Built from your wallpaper or colour");
            previewMode = Signal.light ? "light" : "dark";
            previewWallpaperPath = Wallpapers.actualCurrent;
            previewWallpaperLabel = previewWallpaperPath ? previewWallpaperPath.split("/").pop() : "";
            previewPalette = root.liveColors();
            previewTerminal = root.liveTerminal();
            return;
        }

        if (!ThemeCatalogue.loaded)
            return;

        const theme = Signal.themeId ? Themes.themeById(Signal.themeId) : null;
        if (theme) {
            if (previewSource === "theme" && previewThemeId === theme.id)
                return;
            startThemePreview(theme, Themes.palettePreviewPathFor(theme, true), "");
            return;
        }

        // A live scheme from an external writer has no catalogue card.
        // Keep the preview truthful by showing the live roles.
        previewActive = true;
        previewSource = "current";
        previewTitle = qsTr("Custom appearance");
        previewSubtitle = qsTr("Your current look");
        previewMode = Signal.light ? "light" : "dark";
        previewWallpaperPath = Wallpapers.actualCurrent;
        previewWallpaperLabel = previewWallpaperPath ? previewWallpaperPath.split("/").pop() : "";
        previewGtkTheme = pendingGtkTheme;
        previewIconTheme = pendingIconTheme;
        previewGtkColorScheme = pendingGtkColorScheme;
        previewGtkPrefer = pendingGtkColorScheme;
        previewThemeId = "";
        previewTags = [];
        previewWallpaperCount = 0;
        previewPalette = root.liveColors();
        previewTerminal = root.liveTerminal();
    }

    // The applied roles (Signal's pre-preview snapshot while a Chromatic
    // style is shown on the live shell).
    function liveColors(): var {
        const snap = Signal.previewing ? Signal._snapshot : null;
        const colors = {};
        for (const role of Signal.roles)
            colors[role] = snap ? snap.palette[role] : String(Signal.current[role]);
        return colors;
    }

    function liveTerminal(): var {
        const snap = Signal.previewing ? Signal._snapshot : null;
        if (snap)
            return snap.terminal ?? [];
        const t = [];
        for (let i = 0; i < 16; i++)
            t.push(String(Signal.current[`term${i}`]));
        return t;
    }

    // Signal role table a theme would apply, for the preview swatches.
    function paletteForTheme(theme: var): var {
        if (!theme)
            return ({});
        if (Signal.isBuiltInTheme(theme.id))
            return Signal.builtInThemes[theme.id].palette;
        // Registry listings carry a partial preview `swatch`; the preview
        // falls back to live roles for anything it does not name.
        return Signal.isCompletePalette(theme.palette) ? theme.palette : (theme.swatch ?? ({}));
    }

    // The theme's own 16 terminal colours (schema v2 `terminal`), [] when
    // the listing carries none (a registry swatch is roles only).
    function terminalForTheme(theme: var): var {
        if (!theme)
            return [];
        if (Signal.isBuiltInTheme(theme.id))
            return Signal.builtInThemes[theme.id].terminal ?? [];
        return Array.isArray(theme.terminal) ? theme.terminal : [];
    }

    Connections {
        target: ThemeCatalogue
        function onThemesChanged(): void {
            root.syncCurrentThemePreview();
        }
        function onLoadedChanged(): void {
            root.syncCurrentThemePreview();
        }
    }

    Connections {
        target: Signal
        function onThemeIdChanged(): void {
            root.syncCurrentThemePreview();
        }
        function onThemeStateReadyChanged(): void {
            root.syncCurrentThemePreview();
        }
        function onChromaticChanged(): void {
            if (root.previewSource === "current")
                root.syncCurrentThemePreview();
        }
    }

    property bool desktopClockEnabled: Config.background.desktopClock.enabled ?? false
    property real desktopClockScale: Config.background.desktopClock.scale ?? 1
    property string desktopClockPosition: Config.background.desktopClock.position ?? "bottom-right"
    property bool desktopClockShadowEnabled: Config.background.desktopClock.shadow.enabled ?? true
    property real desktopClockShadowOpacity: Config.background.desktopClock.shadow.opacity ?? 0.7
    property real desktopClockShadowBlur: Config.background.desktopClock.shadow.blur ?? 0.4
    property bool desktopClockBackgroundEnabled: Config.background.desktopClock.background.enabled ?? false
    property real desktopClockBackgroundOpacity: Config.background.desktopClock.background.opacity ?? 0.7
    property bool desktopClockBackgroundBlur: Config.background.desktopClock.background.blur ?? false
    property bool desktopClockInvertColors: Config.background.desktopClock.invertColors ?? false
    property bool backgroundEnabled: Config.background.enabled ?? true
    property bool wallpaperEnabled: Config.background.wallpaperEnabled ?? true
    property bool visualiserEnabled: Config.background.visualiser.enabled ?? false
    property bool visualiserAutoHide: Config.background.visualiser.autoHide ?? true
    property real visualiserRounding: Config.background.visualiser.rounding ?? 1
    property real visualiserSpacing: Config.background.visualiser.spacing ?? 1
    property string pendingThemeId: ""
    property string pendingWallpaperPath: Wallpapers.actualCurrent
    property string stagedThemeWallpaper: ""
    property string pendingGtkTheme: ""
    property string pendingIconTheme: ""
    property string pendingGtkColorScheme: "follow"
    property string wallpaperScopeDir: ""
    property bool wallpaperShowAll: false
    property bool themeDirty: false
    property bool wallpaperDirty: false
    property bool gtkDirty: false
    property bool iconDirty: false
    property bool gtkColorSchemeDirty: false
    property string deferredGtk: ""
    property string deferredIcon: ""
    property string deferredGtkColorScheme: ""
    property string applyStatusMessage: ""
    property bool applyFailed: false
    readonly property bool hasPendingChanges: themeDirty || wallpaperDirty || gtkDirty || iconDirty || gtkColorSchemeDirty
    readonly property bool pipelineBusy: ThemePipeline.busy
    readonly property bool canApply: hasPendingChanges && !pipelineBusy
    readonly property string footerStatusText: {
        if (pipelineBusy)
            return qsTr("Applying appearance…");
        if (applyFailed && applyStatusMessage)
            return applyStatusMessage;
        if (hasPendingChanges)
            return qsTr("Pending — will apply when the current job finishes");
        return qsTr("Choices apply as you make them");
    }
    property bool previewActive: false
    property string previewSource: ""
    property string previewTitle: ""
    property string previewSubtitle: ""
    property string previewReadinessDetails: ""
    property string previewMode: ""
    property string previewWallpaperPath: ""
    property string previewGtkTheme: ""
    property string previewIconTheme: ""
    property string previewGtkPrefer: ""
    property string previewGtkColorScheme: ""
    property string previewWallpaperLabel: ""
    property string previewThemeId: ""
    property var previewTags: []
    property int previewWallpaperCount: 0
    property var previewPalette: ({})
    property var previewTerminal: []

    anchors.fill: parent

    function normalizeGtkColorScheme(value: string): string {
        return ThemePipeline.normalizeGtkColorScheme(value) || "follow";
    }

    function gtkColorSchemeLabel(value: string): string {
        switch (normalizeGtkColorScheme(value)) {
        case "follow":
            return qsTr("Follow theme mode");
        case "default":
            return qsTr("Auto (apps decide)");
        case "prefer-light":
            return qsTr("Prefer light");
        case "prefer-dark":
            return qsTr("Prefer dark");
        default:
            return value || "—";
        }
    }

    function resetPreviewRecipe(): void {
        previewGtkTheme = "";
        previewIconTheme = "";
        previewGtkPrefer = "";
        previewGtkColorScheme = "";
        previewWallpaperLabel = "";
        previewThemeId = "";
        previewTags = [];
        previewWallpaperCount = 0;
    }

    function startGtkColorSchemePreview(policy: string): void {
        const normalized = normalizeGtkColorScheme(policy);
        previewActive = true;
        previewSource = "gtk-color-scheme";
        previewTitle = gtkColorSchemeLabel(normalized);
        previewSubtitle = qsTr("GTK color scheme");
        previewGtkColorScheme = normalized;
        previewGtkPrefer = normalized;
        previewMode = Signal.light ? "light" : "dark";
        previewGtkTheme = pendingGtkTheme;
        previewIconTheme = pendingIconTheme;
        previewWallpaperPath = previewWallpaperPath || pendingWallpaperPath;
        previewWallpaperLabel = pendingWallpaperPath ? pendingWallpaperPath.split("/").pop() : "";
        previewPalette = liveColors();
        previewTerminal = liveTerminal();
    }

    // Wallpapers never recolour the shell: the preview keeps the current
    // (or previewed theme's) roles and only swaps the image.
    function startWallpaperPreview(path: string, label: string): void {
        if (!path)
            return;

        const keepThemeRecipe = previewSource === "theme" && !!previewThemeId;

        previewActive = true;
        if (!keepThemeRecipe) {
            previewSource = "wallpaper";
            previewTitle = label || path.split("/").pop();
            previewSubtitle = qsTr("Wallpaper");
            resetPreviewRecipe();
            previewMode = Signal.light ? "light" : "dark";
            previewGtkTheme = pendingGtkTheme;
            previewIconTheme = pendingIconTheme;
            previewGtkColorScheme = pendingGtkColorScheme;
            previewGtkPrefer = pendingGtkColorScheme;
            previewPalette = liveColors();
            previewTerminal = liveTerminal();
        }
        previewWallpaperPath = path;
        previewWallpaperLabel = label || path.split("/").pop();
    }

    function startThemePreview(modelData: var, resolvedWallpaper: string, readinessDetails: string): void {
        if (!modelData)
            return;

        previewActive = true;
        previewSource = "theme";
        previewTitle = modelData.name ?? modelData.id ?? qsTr("Theme");
        previewSubtitle = modelData.description ?? qsTr("Theme pack");
        previewReadinessDetails = readinessDetails;
        previewMode = modelData.darkMode ? "dark" : "light";
        previewWallpaperPath = resolvedWallpaper || Wallpapers.actualCurrent || "";
        if (!modelData.colorOnly
                && !Themes.hasAvailableWallpaper(modelData)
                && previewWallpaperPath === Wallpapers.actualCurrent
                && previewWallpaperPath)
            previewSubtitle += ` · ${qsTr("previewing with your current wallpaper")}`;
        previewGtkTheme = modelData.gtkTheme || "";
        previewIconTheme = modelData.iconTheme || "";
        previewGtkColorScheme = modelData.gtkColorScheme || ThemePipeline.resolveGtkColorScheme(modelData, !!modelData.darkMode);
        previewGtkPrefer = previewGtkColorScheme;
        previewWallpaperLabel = previewWallpaperPath ? previewWallpaperPath.split("/").pop() : "";
        previewThemeId = modelData.id || "";
        previewTags = modelData.tags ?? [];
        previewWallpaperCount = Array.isArray(modelData.wallpapers) ? modelData.wallpapers.length : 0;
        previewPalette = paletteForTheme(modelData);
        previewTerminal = terminalForTheme(modelData);
    }

    function clearPreviewFor(source: string): void {
        endPreviewFor(source);
    }

    function clearPreview(): void {
        previewActive = false;
        previewSource = "";
        previewTitle = "";
        previewSubtitle = "";
        previewReadinessDetails = "";
        previewMode = "";
        previewWallpaperPath = "";
        resetPreviewRecipe();
        previewPalette = {};
        previewTerminal = [];
    }

    // What Undo puts back for the apply now running (services/Undo.qml).
    property var undoSnap: null
    property string undoTitle: ""

    function _captureUndo(kinds: var): void {
        root.undoSnap = {
            "theme": Signal.themeId,
            "wallpaper": Wallpapers.actualCurrent,
            "gtk": GtkSettings.liveGtkTheme,
            "icons": GtkSettings.liveIconTheme,
            "scheme": GtkSettings.liveColorScheme,
            "kinds": kinds
        };
        root.undoTitle = kinds.theme ? (Themes.themeById(root.pendingThemeId)?.name ?? qsTr("Theme")) : kinds.wallpaper ? qsTr("Wallpaper") : kinds.gtk ? qsTr("GTK theme") : kinds.icons ? qsTr("Icon theme") : qsTr("GTK colour scheme");
    }

    function commitSelection(): void {
        // ThemePipeline.applyTheme applies a complete Signal role table
        // (plus the theme's wallpaper/GTK recipe). GTK/icon overrides only
        // run when the user explicitly staged them, and only after apply
        // finishes (avoids racing the GTK finalize step).
        const appliedTheme = themeDirty && pendingThemeId;
        const appliedWallpaper = !appliedTheme && wallpaperDirty && pendingWallpaperPath;
        const pipelineJob = appliedTheme || appliedWallpaper;
        _captureUndo({
            "theme": !!appliedTheme,
            "wallpaper": !!appliedWallpaper,
            "gtk": gtkDirty && !!pendingGtkTheme,
            "icons": iconDirty && !!pendingIconTheme,
            "scheme": gtkColorSchemeDirty && !!pendingGtkColorScheme
        });
        deferredGtk = "";
        deferredIcon = "";

        if (appliedTheme)
            ThemePipeline.applyTheme(pendingThemeId, stagedThemeWallpaper || "");
        else if (appliedWallpaper)
            ThemePipeline.setWallpaper(pendingWallpaperPath);

        if (gtkDirty && pendingGtkTheme) {
            if (pipelineJob)
                deferredGtk = pendingGtkTheme;
            else
                ThemePipeline.setGtk(pendingGtkTheme);
        }
        if (iconDirty && pendingIconTheme) {
            if (pipelineJob)
                deferredIcon = pendingIconTheme;
            else
                ThemePipeline.setIcons(pendingIconTheme);
        }
        if (gtkColorSchemeDirty && pendingGtkColorScheme) {
            if (pipelineJob)
                deferredGtkColorScheme = pendingGtkColorScheme;
            else
                ThemePipeline.setGtkColorScheme(pendingGtkColorScheme);
        }

        // If a pipeline job is in flight, wait for applyFinished. If already idle, flush now.
        if ((deferredGtk || deferredIcon || deferredGtkColorScheme) && !ThemePipeline.busy)
            root._flushDeferredPipelineExtras();

        themeDirty = false;
        wallpaperDirty = false;
        gtkDirty = false;
        iconDirty = false;
        gtkColorSchemeDirty = false;
        stagedThemeWallpaper = "";
        // Keep showing the clicked choice: the banner reads "Applying…"
        // and then "Now using" once it is live (previewIsApplied).
    }

    // Apply staged changes immediately (click-to-apply). If the pipeline is busy,
    // keep the selection staged and retry from onApplyFinished.
    function commitPending(): void {
        if (!hasPendingChanges)
            return;
        if (pipelineBusy)
            return;
        applyFailed = false;
        applyStatusMessage = "";
        commitSelection();
        saveConfig();
    }

    function _flushDeferredPipelineExtras(): void {
        if (deferredGtk) {
            const theme = deferredGtk;
            deferredGtk = "";
            ThemePipeline.setGtk(theme);
        }
        if (deferredIcon) {
            const theme = deferredIcon;
            deferredIcon = "";
            ThemePipeline.setIcons(theme);
        }
        if (deferredGtkColorScheme) {
            const policy = deferredGtkColorScheme;
            deferredGtkColorScheme = "";
            ThemePipeline.setGtkColorScheme(policy);
        }
    }

    function stageThemeApply(themeId: string): void {
        pendingThemeId = themeId;
        stagedThemeWallpaper = "";
        themeDirty = !!themeId;
        wallpaperDirty = false;
        const theme = Themes.themeById(themeId);
        if (theme) {
            wallpaperScopeDir = theme.wallpaperDir || themeId;
            wallpaperShowAll = false;
            // Colour-only themes (every built-in) keep the user's current
            // background; colour never depends on it.
            stagedThemeWallpaper = Themes.wallpaperOverrideFor(theme);
            if (theme.wallpaperPath)
                pendingWallpaperPath = theme.wallpaperPath;
            if (theme.gtkTheme)
                pendingGtkTheme = theme.gtkTheme;
            if (theme.iconTheme)
                pendingIconTheme = theme.iconTheme;
            if (theme.gtkColorScheme)
                pendingGtkColorScheme = theme.gtkColorScheme;
        }
    }

    function stageThemeApplyWithWallpaper(themeId: string, wallpaperPath: string): void {
        stageThemeApply(themeId);
        pendingWallpaperPath = wallpaperPath;
        stagedThemeWallpaper = wallpaperPath;
        themeDirty = true;
        wallpaperDirty = false;
    }

    function stageGtkTheme(theme: string): void {
        pendingGtkTheme = theme;
        gtkDirty = !!theme;
    }

    function stageIconTheme(theme: string): void {
        pendingIconTheme = theme;
        iconDirty = !!theme;
    }

    function stageGtkColorScheme(policy: string): void {
        pendingGtkColorScheme = normalizeGtkColorScheme(policy);
        gtkColorSchemeDirty = !!pendingGtkColorScheme;
    }

    function stageWallpaperApply(path: string): void {
        pendingWallpaperPath = path;
        wallpaperDirty = path !== Wallpapers.actualCurrent;
        // With a theme staged, the click overrides the theme wallpaper.
        stagedThemeWallpaper = themeDirty ? path : "";
    }

    function resetPendingSelections(): void {
        pendingThemeId = "";
        pendingWallpaperPath = Wallpapers.actualCurrent;
        stagedThemeWallpaper = "";
        wallpaperScopeDir = "";
        wallpaperShowAll = false;
        themeDirty = false;
        deferredGtk = "";
        deferredIcon = "";
        deferredGtkColorScheme = "";
        wallpaperDirty = false;
        gtkDirty = false;
        iconDirty = false;
        gtkColorSchemeDirty = false;
        // Seed live GTK/icon so section checkmarks reflect current state.
        // Do not overwrite a user-staged selection if a previous seed is still in flight.
        // Native gsettings reads first (GtkSettings); the horneroctl gtk
        // queries below are fallbacks that yield when native wins.
        GtkSettings.refreshLive();
        liveGtkProc.running = true;
        liveIconProc.running = true;
        liveGtkColorSchemeProc.running = true;
        applyFailed = false;
        applyStatusMessage = "";
        if (!previewActive) {
            previewWallpaperPath = pendingWallpaperPath;
            previewMode = Signal.light ? "light" : "dark";
        }
    }

    function saveConfig() {
        Config.appearance.anim.durations.scale = root.animDurationsScale;

        Config.appearance.font.family.mono = root.fontFamilyMono;
        Config.appearance.font.family.sans = root.fontFamilySans;
        Config.appearance.font.family.display = root.fontFamilyDisplay;
        Config.appearance.font.size.scale = root.fontSizeScale;

        Config.appearance.padding.scale = root.paddingScale;
        Config.appearance.rounding.scale = root.roundingScale;
        Config.appearance.spacing.scale = root.spacingScale;

        Config.appearance.transparency.enabled = root.transparencyEnabled;
        Config.appearance.transparency.base = root.transparencyBase;
        Config.appearance.transparency.layers = root.transparencyLayers;
        Config.appearance.transparency.elements = root.transparencyElements;

        Config.background.desktopClock.enabled = root.desktopClockEnabled;
        Config.background.enabled = root.backgroundEnabled;
        Config.background.desktopClock.scale = root.desktopClockScale;
        Config.background.desktopClock.position = root.desktopClockPosition;
        Config.background.desktopClock.shadow.enabled = root.desktopClockShadowEnabled;
        Config.background.desktopClock.shadow.opacity = root.desktopClockShadowOpacity;
        Config.background.desktopClock.shadow.blur = root.desktopClockShadowBlur;
        Config.background.desktopClock.background.enabled = root.desktopClockBackgroundEnabled;
        Config.background.desktopClock.background.opacity = root.desktopClockBackgroundOpacity;
        Config.background.desktopClock.background.blur = root.desktopClockBackgroundBlur;
        Config.background.desktopClock.invertColors = root.desktopClockInvertColors;

        Config.background.wallpaperEnabled = root.wallpaperEnabled;

        Config.background.visualiser.enabled = root.visualiserEnabled;
        Config.background.visualiser.autoHide = root.visualiserAutoHide;
        Config.background.visualiser.rounding = root.visualiserRounding;
        Config.background.visualiser.spacing = root.visualiserSpacing;

        Config.border.rounding = root.borderRounding;
        Config.border.thickness = root.borderThickness;

        Config.save();
    }

    Component {
        id: appearanceRightContentComponent

        Item {
            id: rightAppearanceFlickable

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 0

                Instruments.Eyebrow {
                    Layout.bottomMargin: Appearance.spacing.small
                    label: qsTr("Preview")
                }

                AppearancePreviewPane {
                    Layout.fillWidth: true
                    // Large and stable: the specimen gets most of the column
                    // and never jumps in size between "now" and "previewing".
                    Layout.preferredHeight: Math.max(540, rightAppearanceFlickable.height * 0.7)
                    Layout.bottomMargin: Appearance.spacing.normal

                    previewState: root.previewState
                    hoverEnabled: root.hoverPreviewEnabled

                    active: root.previewActive
                    source: root.previewSource
                    titleText: root.previewTitle
                    subtitleText: root.previewSubtitle
                    readinessDetails: root.previewReadinessDetails
                    modeText: root.previewMode
                    wallpaperPath: root.previewWallpaperPath || root.pendingWallpaperPath
                    gtkThemeText: root.previewGtkTheme
                    iconThemeText: root.previewIconTheme
                    gtkPreferText: root.previewGtkPrefer
                    wallpaperLabel: root.previewWallpaperLabel
                    themeIdText: root.previewThemeId
                    tags: root.previewTags
                    wallpaperCount: root.previewWallpaperCount
                    rootPane: root
                }

                Loader {
                    id: wallpaperLoader

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.bottomMargin: -Appearance.padding.large * 2

                    active: {
                        const appearanceIndex = PaneRegistry.getIndexByLabel("appearance");
                        const isActive = root.session.activeIndex === appearanceIndex;
                        const isAdjacent = Math.abs(root.session.activeIndex - appearanceIndex) === 1;
                        const splitLayout = root.children[0];
                        const loader = splitLayout && splitLayout.rightLoader ? splitLayout.rightLoader : null;
                        const shouldActivate = loader && loader.item !== null && (isActive || isAdjacent);
                        return shouldActivate;
                    }

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.error("[AppearancePane] Wallpaper loader error!");
                        }
                    }

                    sourceComponent: WallpaperGrid {
                        session: root.session
                        previewController: root
                        wallpaperScopeDir: root.wallpaperScopeDir
                        wallpaperUsesCurrentThemeFallback: root.previewSource === "theme"
                            && !!root.previewWallpaperPath
                            && root.previewWallpaperPath === Wallpapers.actualCurrent
                            && !Themes.hasAvailableWallpaper(Themes.themeById(root.previewThemeId))
                        showAllWallpapers: root.wallpaperShowAll
                        onToggleShowAllRequested: root.wallpaperShowAll = !root.wallpaperShowAll
                    }
                }
            }
        }
    }

    SplitPaneLayout {
        anchors.fill: parent

        leftContent: Component {

            ColumnLayout {
                id: leftColumn

                spacing: Appearance.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.smaller

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Appearance")
                        font.pointSize: Appearance.font.size.large
                        font.weight: Appearance.font.weight.medium
                        Accessible.role: Accessible.Heading
                    }

                    IconButton {
                        icon: sidebarLayout.allSectionsExpanded ? "fold" : "selector"
                        accessibleName: sidebarLayout.allSectionsExpanded ? qsTr("Collapse all sections") : qsTr("Expand all sections")
                        type: IconButton.Text
                        label.animate: true
                        onClicked: {
                            // Assigns all sections + persists once. The
                            // allSectionsExpanded binding refreshes the icon.
                            root.setAllSections(!sidebarLayout.allSectionsExpanded);
                        }
                    }
                }

                // Pinned: always visible while the sections scroll below.
                NowUsingStrip {
                    Layout.fillWidth: true
                    rootPane: root
                }

                StyledFlickable {
                    id: sidebarFlickable

                    readonly property var rootPane: root

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    contentHeight: sidebarLayout.height

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: sidebarFlickable
                    }

                    ColumnLayout {
                        id: sidebarLayout

                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: implicitHeight
                        spacing: Appearance.spacing.small

                        readonly property var rootPane: sidebarFlickable.rootPane
                        readonly property var sections: ({
                                themes: themesSection,
                                chromatic: chromaticSection,
                                accent: accentSection,
                                themeEditor: themeEditorSection,
                                background: backgroundSection,
                                look: lookSection,
                                atmosphere: atmosphereSection,
                                transparency: transparencySection,
                                border: borderSection,
                                fonts: fontsSection,
                                scales: scalesSection,
                                animations: animationsSection,
                                gtkTheme: gtkThemeSection,
                                gtkColorScheme: gtkColorSchemeSection,
                                iconTheme: iconThemeSection,
                                health: healthSection
                            })

                        readonly property bool allSectionsExpanded: themesSection.expanded && chromaticSection.expanded && accentSection.expanded && themeEditorSection.expanded && backgroundSection.expanded && lookSection.expanded && atmosphereSection.expanded && transparencySection.expanded && borderSection.expanded && fontsSection.expanded && scalesSection.expanded && animationsSection.expanded && gtkThemeSection.expanded && gtkColorSchemeSection.expanded && iconThemeSection.expanded && healthSection.expanded

                        Component.onCompleted: {
                            root.sectionItems = sidebarLayout.sections;
                            root.sectionScroll = sidebarFlickable;
                            if (root.session.active === "appearance" && root.session.requestedSection)
                                Qt.callLater(() => root.revealSection(root.session.requestedSection));
                        }

                        AppearanceGroupLabel {
                            label: qsTr("Colour")
                            first: true
                        }
                        ThemesSection {
                            id: themesSection
                            objectName: "appearanceSection"
                            property string sectionKey: "themes"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("themes")
                            onExpandedChanged: root.persistSection("themes", expanded)
                        }
                        ChromaticSection {
                            id: chromaticSection
                            objectName: "appearanceSection"
                            property string sectionKey: "chromatic"
                            session: root.session
                            previewController: root
                            // Open by default while Chromatic is the active theme,
                            // unless the user collapsed it (remembered as the
                            // "chromatic:closed" marker next to the open list).
                            Component.onCompleted: expanded = root.isSectionExpanded("chromatic") || (Config.appearance.theme === "hornero-chromatic" && !root.isSectionExpanded("chromatic:closed"))
                            onExpandedChanged: {
                                root.persistSection("chromatic", expanded);
                                root.persistSection("chromatic:closed", !expanded);
                            }
                        }
                        AccentSection {
                            id: accentSection
                            objectName: "appearanceSection"
                            property string sectionKey: "accent"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("accent")
                            onExpandedChanged: root.persistSection("accent", expanded)
                        }
                        ThemeEditorSection {
                            id: themeEditorSection
                            objectName: "appearanceSection"
                            property string sectionKey: "themeEditor"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("themeEditor")
                            onExpandedChanged: root.persistSection("themeEditor", expanded)
                        }
                        AppearanceGroupLabel {
                            label: qsTr("Wallpaper & desktop")
                        }
                        BackgroundSection {
                            id: backgroundSection
                            objectName: "appearanceSection"
                            property string sectionKey: "background"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("background")
                            onExpandedChanged: root.persistSection("background", expanded)
                        }
                        AppearanceGroupLabel {
                            label: qsTr("Look & feel")
                        }
                        LookSection {
                            id: lookSection
                            objectName: "appearanceSection"
                            property string sectionKey: "look"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("look")
                            onExpandedChanged: root.persistSection("look", expanded)
                        }
                        AtmosphereSection {
                            id: atmosphereSection
                            objectName: "appearanceSection"
                            property string sectionKey: "atmosphere"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("atmosphere")
                            onExpandedChanged: root.persistSection("atmosphere", expanded)
                        }
                        TransparencySection {
                            id: transparencySection
                            objectName: "appearanceSection"
                            property string sectionKey: "transparency"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("transparency")
                            onExpandedChanged: root.persistSection("transparency", expanded)
                        }
                        BorderSection {
                            id: borderSection
                            objectName: "appearanceSection"
                            property string sectionKey: "border"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("border")
                            onExpandedChanged: root.persistSection("border", expanded)
                        }
                        AppearanceGroupLabel {
                            label: qsTr("Type & motion")
                        }
                        FontsSection {
                            id: fontsSection
                            objectName: "appearanceSection"
                            property string sectionKey: "fonts"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("fonts")
                            onExpandedChanged: root.persistSection("fonts", expanded)
                        }
                        ScalesSection {
                            id: scalesSection
                            objectName: "appearanceSection"
                            property string sectionKey: "scales"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("scales")
                            onExpandedChanged: root.persistSection("scales", expanded)
                        }
                        AnimationsSection {
                            id: animationsSection
                            objectName: "appearanceSection"
                            property string sectionKey: "animations"
                            rootPane: sidebarFlickable.rootPane
                            Component.onCompleted: expanded = root.isSectionExpanded("animations")
                            onExpandedChanged: root.persistSection("animations", expanded)
                        }
                        AppearanceGroupLabel {
                            label: qsTr("Apps: GTK, Qt and icons")
                        }
                        GtkThemeSection {
                            id: gtkThemeSection
                            objectName: "appearanceSection"
                            property string sectionKey: "gtkTheme"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("gtkTheme")
                            onExpandedChanged: root.persistSection("gtkTheme", expanded)
                        }
                        GtkColorSchemeSection {
                            id: gtkColorSchemeSection
                            objectName: "appearanceSection"
                            property string sectionKey: "gtkColorScheme"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("gtkColorScheme")
                            onExpandedChanged: root.persistSection("gtkColorScheme", expanded)
                        }
                        IconThemeSection {
                            id: iconThemeSection
                            objectName: "appearanceSection"
                            property string sectionKey: "iconTheme"
                            session: root.session
                            previewController: root
                            Component.onCompleted: expanded = root.isSectionExpanded("iconTheme")
                            onExpandedChanged: root.persistSection("iconTheme", expanded)
                        }
                        AppearanceGroupLabel {
                            label: qsTr("Health")
                        }
                        HealthSection {
                            id: healthSection
                            objectName: "appearanceSection"
                            property string sectionKey: "health"
                            session: root.session
                            Component.onCompleted: expanded = root.isSectionExpanded("health")
                            onExpandedChanged: root.persistSection("health", expanded)
                        }

                        RowLayout {
                            // Changes apply on click; progress lives in the
                            // "Now using" strip. Only a failure stays here.
                            visible: root.applyFailed
                            Layout.fillWidth: true
                            Layout.topMargin: Appearance.spacing.normal
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: root.footerStatusText
                                color: Signal.palette.alert
                                font.pointSize: Appearance.font.size.small
                                wrapMode: Text.WordWrap
                                Accessible.role: Accessible.AlertMessage
                            }
                        }
                    }
                }
            }
        }

        rightContent: appearanceRightContentComponent
    }

    // horneroctl gtk live-query fallback. Yields to the native GtkSettings
    // reads; kept for hosts without gsettings.
    Process {
        id: liveGtkProc
        command: ["horneroctl", "appearance", "gtk", "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Never clobber a staged GTK selection with a late live-seed result.
                if (root.gtkDirty)
                    return;
                // Native GtkSettings read wins when available.
                if (GtkSettings.liveGtkTheme)
                    return;
                const name = text.trim();
                if (name && name !== "Unknown")
                    root.pendingGtkTheme = name;
            }
        }
    }

    // horneroctl gtk live-query fallback; see above.
    Process {
        id: liveIconProc
        command: ["horneroctl", "appearance", "gtk", "current-icon"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.iconDirty)
                    return;
                if (GtkSettings.liveIconTheme)
                    return;
                const name = text.trim();
                if (name && name !== "Unknown")
                    root.pendingIconTheme = name;
            }
        }
    }

    // horneroctl gtk live-query fallback; see above.
    Process {
        id: liveGtkColorSchemeProc
        command: ["horneroctl", "appearance", "gtk", "current-color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gtkColorSchemeDirty)
                    return;
                if (GtkSettings.liveColorScheme)
                    return;
                const policy = root.normalizeGtkColorScheme(text.trim());
                if (policy)
                    root.pendingGtkColorScheme = policy;
            }
        }
    }

    // Native live seeds (issue #2, step (c)): gsettings reads via
    // GtkSettings populate pending selections unless the user staged one.
    Connections {
        target: GtkSettings

        function onLiveGtkThemeChanged(): void {
            if (!root.gtkDirty && GtkSettings.liveGtkTheme) {
                root.pendingGtkTheme = GtkSettings.liveGtkTheme;
                if (root.previewSource === "current")
                    root.previewGtkTheme = GtkSettings.liveGtkTheme;
            }
        }

        function onLiveIconThemeChanged(): void {
            if (!root.iconDirty && GtkSettings.liveIconTheme) {
                root.pendingIconTheme = GtkSettings.liveIconTheme;
                if (root.previewSource === "current")
                    root.previewIconTheme = GtkSettings.liveIconTheme;
            }
        }

        function onLiveColorSchemeChanged(): void {
            if (!root.gtkColorSchemeDirty && GtkSettings.liveColorScheme) {
                root.pendingGtkColorScheme = GtkSettings.liveColorScheme;
                if (root.previewSource === "current") {
                    root.previewGtkColorScheme = GtkSettings.liveColorScheme;
                    root.previewGtkPrefer = GtkSettings.liveColorScheme;
                }
            }
        }
    }

    Connections {
        target: Wallpapers
        function onActualCurrentChanged(): void {
            if (root.previewSource === "current")
                root.syncCurrentThemePreview();
        }
    }

    Connections {
        target: root.session

        function onActiveIndexChanged(): void {
            if (root.session.activeIndex !== PaneRegistry.getIndexByLabel("appearance"))
                root.clearPreview();
        }
    }

    // Undo writes Config directly; pull the pane's working copies back so a
    // later saveConfig() cannot write the old values again.
    function resyncFromConfig(): void {
        root.animDurationsScale = Config.appearance.anim.durations.scale ?? 1;
        root.fontSizeScale = Config.appearance.font.size.scale ?? 1;
        root.paddingScale = Config.appearance.padding.scale ?? 1;
        root.roundingScale = Config.appearance.rounding.scale ?? 1;
        root.spacingScale = Config.appearance.spacing.scale ?? 1;
    }

    Connections {
        target: Undo

        function onUndone(key: string): void {
            root.resyncFromConfig();
        }
    }

    Connections {
        target: ThemePipeline

        function onApplyFinished(ok: bool): void {
            // Offer Undo for the change that just finished (one offer per
            // commit; a replay of an Undo never offers another).
            if (ok && root.undoSnap) {
                const snap = root.undoSnap;
                root.undoSnap = null;
                // The restore runs in ThemePipeline, so it still works after
                // this pane is unloaded or the window closes.
                Undo.offerCalls("appearance", root.undoTitle, [[ThemePipeline, "restoreAppearance", [snap]]], "");
            } else if (!ok && root.undoSnap) {
                root.undoSnap = null;
                Undo.report("appearance", qsTr("Appearance was not changed"), ThemePipeline.lastError || qsTr("Appearance apply failed"));
            }
            if (!ok) {
                root.deferredGtk = "";
                root.deferredIcon = "";
                root.deferredGtkColorScheme = "";
                root.applyFailed = true;
                root.applyStatusMessage = ThemePipeline.lastError || qsTr("Appearance apply failed");
                return;
            }
            root.applyFailed = false;
            root.applyStatusMessage = "";
            root._flushDeferredPipelineExtras();
            // Refresh live GTK/icon checkmarks after a successful pipeline apply.
            if (!root.gtkDirty)
                liveGtkProc.running = true;
            if (!root.iconDirty)
                liveIconProc.running = true;
            if (!root.gtkColorSchemeDirty)
                liveGtkColorSchemeProc.running = true;
            // User selected something else while we were busy — apply it now.
            if (root.hasPendingChanges)
                root.commitPending();
        }
    }

    Component.onDestruction: clearPreview()
}

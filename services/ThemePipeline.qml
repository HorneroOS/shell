pragma Singleton

import qs.services
import qs.utils
import Hornero
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // User packs override package catalogues. State writes use XDG Hornero paths.
    readonly property string wallpapersDir: `${Paths.data}/wallpapers`
    readonly property string picturesWallpapers: `${Paths.pictures}/Wallpapers`
    readonly property string wallpaperPointer: Paths.wallpaperPointer
    // M3 palette generation runs through horneroctl (its backend resolves
    // the python synthesizer via HORNERO_M3_PYTHON_BIN / HORNERO_M3_SCRIPT,
    // so pyenv shims cannot hide Arch python-materialyoucolor).
    // GTK application is native-first via GtkSettings (gsettings) with the
    // horneroctl gtk fallback there. See docs/NATIVE-APPEARANCE.md.
    readonly property var m3Base: ["horneroctl", "appearance", "colors", "m3", "--yes", "--"]
    // Canonical scheme.json (written by m3Proc below).
    readonly property string schemeJson: `${Paths.cache}/smart-colors/scheme.json`

    // User-facing apply requests go through horneroctl so the stable product
    // boundary owns verification and persisted appearance state. The CLI
    // routes back through the IPC-only enqueue path below.
    readonly property bool busy: _cliApplying || _busy || _queue.length > 0
    property bool _cliApplying: false
    property string _cliThemeId: ""
    property string _cliWallpaper: ""
    property var _cliNextRequest: null
    property bool _busy: false
    property var _queue: []
    property string _jobKind: ""
    property string _pendingWallpaper: ""
    property string _pendingSchemeType: "tonal-spot"
    property bool _pendingDarkMode: true
    property string _pendingGtkTheme: ""
    property string _pendingIconTheme: ""
    property string _pendingThemeName: ""
    property string _pendingThemeId: ""
    // "true" | "false" | "" (infer from gtk theme name / shell mode)
    property string _pendingGtkPreferDark: ""
    // follow | default | prefer-light | prefer-dark | "" (wallpaper jobs sync live policy)
    property string _pendingGtkColorScheme: ""
    property bool _syncAfterWallpaperPointer: false
    property bool _runThemeSideEffects: false
    property string _lastError: ""
    readonly property string lastError: _lastError
    property bool _startupRestored: false
    // True while a GTK apply is delegated to the native GtkSettings layer.
    property bool _awaitingGtk: false

    signal applyFinished(bool ok)

    function resolveGtkPreferDark(cfg: var, darkMode: bool): string {
        const scheme = root.resolveGtkColorScheme(cfg, darkMode);
        return scheme === "prefer-light" || scheme === "default" ? "false" : "true";
    }

    function resolveGtkPreferFromName(gtkTheme: string, darkMode: bool): string {
        const gtk = (gtkTheme || "").toLowerCase();
        if (gtk.indexOf("light") >= 0)
            return "false";
        if (gtk.indexOf("dark") >= 0)
            return "true";
        return darkMode ? "true" : "false";
    }

    function normalizeGtkColorScheme(value: string): string {
        const raw = (value ?? "").toLowerCase().replace(/_/g, "-");
        switch (raw) {
        case "follow":
        case "follow-mode":
        case "follow-theme":
        case "follow-theme-mode":
            return "follow";
        case "default":
        case "auto":
        case "apps":
        case "apps-decide":
            return "default";
        case "prefer-light":
        case "light":
        case "false":
        case "0":
        case "no":
            return "prefer-light";
        case "prefer-dark":
        case "dark":
        case "true":
        case "1":
        case "yes":
            return "prefer-dark";
        default:
            return "";
        }
    }

    function resolveGtkColorScheme(cfg: var, darkMode: bool): string {
        const fromField = root.normalizeGtkColorScheme((cfg && cfg.gtkColorScheme) ? String(cfg.gtkColorScheme) : "");
        if (fromField)
            return fromField;
        if (cfg && cfg.gtkPreferDark !== undefined && cfg.gtkPreferDark !== null && cfg.gtkPreferDark !== "")
            return cfg.gtkPreferDark ? "prefer-dark" : "prefer-light";
        const gtk = ((cfg && cfg.gtkTheme) ? cfg.gtkTheme : "").toLowerCase();
        if (gtk.indexOf("light") >= 0)
            return "prefer-light";
        if (gtk.indexOf("dark") >= 0)
            return "prefer-dark";
        return darkMode ? "prefer-dark" : "prefer-light";
    }

    function applyTheme(id: string, wallpaperPath: string): void {
        if (!id)
            return;
        if (_cliApplying) {
            _cliNextRequest = { id, wallpaperPath: wallpaperPath || "" };
            return;
        }
        _cliThemeId = id;
        _cliWallpaper = wallpaperPath || "";
        _lastError = "";
        _cliApplying = true;
        applyThemeCliProc.running = true;
    }

    function applyThemeFromIpc(id: string, wallpaperPath: string): void {
        if (!id)
            return;
        _enqueue({
            kind: "theme",
            themeId: id,
            wallpaper: wallpaperPath || ""
        });
    }

    function reload(): void {
        _enqueue({
            kind: "reload"
        });
    }

    function setWallpaper(path: string): void {
        if (!path)
            return;
        _enqueue({
            kind: "wallpaper",
            wallpaper: path
        });
    }

    function setGtk(theme: string): void {
        if (!theme)
            return;
        _enqueue({
            kind: "gtk",
            gtkTheme: theme
        });
    }

    function setGtkColorScheme(policy: string): void {
        const normalized = root.normalizeGtkColorScheme(policy);
        if (!normalized)
            return;
        _enqueue({
            kind: "gtk-color-scheme",
            gtkColorScheme: normalized
        });
    }

    function setIcons(theme: string): void {
        if (!theme)
            return;
        _enqueue({
            kind: "icons",
            iconTheme: theme
        });
    }

    function _enqueue(job: var): void {
        const tail = _queue.length ? _queue[_queue.length - 1] : null;
        if (tail && tail.kind === job.kind && tail.themeId === job.themeId && tail.wallpaper === job.wallpaper && tail.gtkTheme === job.gtkTheme && tail.iconTheme === job.iconTheme && tail.gtkColorScheme === job.gtkColorScheme)
            return;
        _queue = _queue.concat([job]);
        _pump();
    }

    function _pump(): void {
        if (_busy || _queue.length === 0)
            return;
        const job = _queue[0];
        if (job.kind === "theme" && !Colours.isBuiltInTheme(job.themeId || "") && !ThemeCatalogue.loaded)
            return;
        _queue = _queue.slice(1);
        _busy = true;
        _lastError = "";
        _jobKind = job.kind || "";
        _runThemeSideEffects = false;
        _pendingGtkTheme = "";
        _pendingIconTheme = "";
        _pendingThemeName = "";
        _pendingThemeId = "";
        _pendingGtkPreferDark = "";
        _pendingGtkColorScheme = "";
        _syncAfterWallpaperPointer = false;

        if (job.kind === "theme") {
            _runThemeSideEffects = true;
            _pendingThemeId = job.themeId || "";
            if (Colours.isBuiltInTheme(job.themeId || "")) {
                root._applyBuiltInTheme(job.themeId, job.wallpaper || "");
                return;
            }
            themeLoader.themeId = job.themeId || "";
            const cfg = ThemeCatalogue.themeById(job.themeId);
            if (!cfg) {
                root._finishJob(false, `theme ${job.themeId} is unavailable or invalid`);
                return;
            }
            root._handleThemeConfig(cfg, job.wallpaper || "");
        } else if (job.kind === "wallpaper") {
            _pendingWallpaper = job.wallpaper;
            _pendingSchemeType = Colours.flavour || "tonal-spot";
            _pendingDarkMode = !Colours.currentLight;
            m3Proc.running = true;
        } else if (job.kind === "reload") {
            _pendingWallpaper = Wallpapers.actualCurrent || "";
            _pendingSchemeType = Colours.flavour || "tonal-spot";
            _pendingDarkMode = !Colours.currentLight;
            if (_pendingWallpaper)
                m3Proc.running = true;
            else
                _finishJob(false, "no current wallpaper is available to regenerate colours");
        } else if (job.kind === "gtk") {
            _awaitingGtk = true;
            GtkSettings.applyGtkTheme(job.gtkTheme || "");
        } else if (job.kind === "gtk-color-scheme") {
            _awaitingGtk = true;
            GtkSettings.applyColorScheme(job.gtkColorScheme || "follow", !Colours.currentLight);
        } else if (job.kind === "icons") {
            _awaitingGtk = true;
            GtkSettings.applyIconTheme(job.iconTheme || "");
        } else {
            _finishJob(false, "unknown job kind");
        }
    }

    // First-class built-in themes (hornero-dark / hornero-light): the full
    // semantic palette lives in Colours, so built-in theme apply needs no
    // wallpaper-driven M3 round-trip — correct switching with no mode leakage. GTK
    // follows through the shared theme registry (the pack's gtkTheme and
    // iconTheme are real installed themes): the theme id resolves via
    // `horneroctl appearance gtk theme`, which writes the gtk2/3/4 ini
    // files that `horneroctl appearance theme set` verifies. Without the
    // id the GTK theme name would never switch and verify would refuse
    // the split state. Optional theme integrations (snappy switcher packs) are
    // skipped for built-ins.
    function _applyBuiltInTheme(id: string, wallpaper: string): void {
        const darkMode = id !== "hornero-light";
        Colours.applyBuiltInTheme(id);
        _pendingThemeName = darkMode ? "Hornero Dark" : "Hornero Light";
        _pendingSchemeType = "tonal-spot";
        _pendingDarkMode = darkMode;
        _pendingGtkTheme = "";
        _pendingIconTheme = "";
        _pendingGtkPreferDark = darkMode ? "true" : "false";
        _pendingGtkColorScheme = darkMode ? "prefer-dark" : "prefer-light";
        if (wallpaper) {
            _pendingWallpaper = wallpaper;
            writeWallpaperPointer.running = true;
        }
        Colours.persistBuiltInTheme(id, _pendingGtkColorScheme);
    }

    function _continueBuiltInThemeApply(id: string, ok: bool, error: string): void {
        if (id !== _pendingThemeId)
            return;
        if (!ok) {
            _finishJob(false, `could not persist ${id}: ${error}`);
            return;
        }
        syncBuiltInStateProc.running = true;
    }

    function _finishBuiltInThemeApply(exitCode: int): void {
        if (exitCode !== 0) {
            _finishJob(false, "could not synchronize built-in theme state");
            return;
        }
        hyprlockProc.running = true;
        hyprReloadProc.running = true;
        _awaitingGtk = true;
        GtkSettings.applyFull("", "", _pendingThemeId, _pendingGtkColorScheme, _pendingDarkMode);
    }

    function _finishJob(ok: bool, err: string): void {
        if (ok && _jobKind === "theme" && _pendingThemeName) {
            notifyProc.themeName = _pendingThemeName;
            notifyProc.running = true;
        }
        if (!ok) {
            _lastError = err || "appearance apply failed";
            console.warn("ThemePipeline:", _lastError);
            notifyFailProc.message = _lastError;
            notifyFailProc.running = true;
        }
        _busy = false;
        _runThemeSideEffects = false;
        root.applyFinished(ok);
        Qt.callLater(() => root._pump());
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (!root._startupRestored) {
                root._startupRestored = true;
                ensureSchemeProc.running = true;
            }
        });
    }

    // Native scheme persistence: M3 regenerate from the wallpaper pointer.
    Process {
        id: applyThemeCliProc
        command: {
            const args = ["horneroctl", "appearance", "theme", "apply", root._cliThemeId];
            if (root._cliWallpaper)
                args.push("--wallpaper", root._cliWallpaper);
            args.push("--yes");
            return args;
        }
        stderr: StdioCollector { id: applyThemeCliStderr }
        stdout: StdioCollector { id: applyThemeCliStdout }
        onExited: (exitCode, exitStatus) => {
            root._cliApplying = false;
            if (exitCode !== 0) {
                root._lastError = applyThemeCliStderr.text.trim() || applyThemeCliStdout.text.trim() || "theme apply failed (exit " + exitCode + ")";
                console.warn("ThemePipeline:", root._lastError);
                Toaster.toast("Theme could not be applied", root._lastError, "error");
            }
            if (root._cliNextRequest) {
                const next = root._cliNextRequest;
                root._cliNextRequest = null;
                Qt.callLater(() => root.applyTheme(next.id, next.wallpaperPath));
            }
        }
    }

    Process {
        id: ensureSchemeProc
        command: ["horneroctl", "appearance", "scheme", "regenerate", "--yes"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("ThemePipeline: scheme regeneration failed (exit", exitCode, ")");
        }
    }

    // Built-in semantic palettes persist their selected identity before GTK
    // verification, so status and the next Shell start agree with the UI.
    Process {
        id: syncBuiltInStateProc
        command: ["horneroctl", "appearance", "scheme", "sync-state", "--yes"]
        onExited: (exitCode, exitStatus) => root._finishBuiltInThemeApply(exitCode)
    }

    QtObject {
        id: themeLoader
        property string themeId: ""
        property string resolvedWallpaper: ""
        property var pendingConfig: ({})
    }

    // Theme metadata and resolved system/user wallpaper paths come from
    // horneroctl's canonical catalogue reader. This keeps user overrides
    // and read-only system pack precedence in one place.
    function _handleThemeConfig(cfg: var, wallpaperOverride: string): void {
        themeLoader.pendingConfig = cfg;
        root._pendingSchemeType = cfg.schemeType || "tonal-spot";
        root._pendingDarkMode = cfg.darkMode !== undefined ? !!cfg.darkMode : true;
        root._pendingGtkTheme = cfg.gtkTheme || "";
        root._pendingIconTheme = cfg.iconTheme || "";
        root._pendingThemeName = cfg.name || themeLoader.themeId;
        root._pendingGtkPreferDark = root.resolveGtkPreferDark(cfg, root._pendingDarkMode);
        root._pendingGtkColorScheme = root.resolveGtkColorScheme(cfg, root._pendingDarkMode);

        const defaultPath = cfg.wallpaperPath || cfg.wallpaperPaths?.[cfg.defaultWallpaper] || "";
        const wallpaper = wallpaperOverride || defaultPath;
        if (wallpaper) {
            themeLoader.resolvedWallpaper = wallpaper;
            root._pendingWallpaper = wallpaper;
            root._startPaletteFromTheme();
            return;
        }
        if (cfg.colorOnly) {
            themeLoader.resolvedWallpaper = Wallpapers.actualCurrent || "";
            root._pendingWallpaper = themeLoader.resolvedWallpaper;
            root._startPaletteFromTheme();
            return;
        }
        root._finishJob(false, `no wallpapers available for theme ${themeLoader.themeId}`);
    }

    Connections {
        target: ThemeCatalogue
        function onLoadedChanged(): void {
            root._pump();
        }
    }

    Process {
        id: resolveWallpaperProc
        command: ["sh", "-c", `
cfg_default="$HORNERO_DEFAULT_WALLPAPER"
theme_dir="$HORNERO_WALLPAPER_DIR"
// Resolve editable user media after the catalogue has checked package assets.
for base in "$HORNERO_PICTURES_WALLPAPERS/$theme_dir" "$HORNERO_DATA_WALLPAPERS/$theme_dir"; do
  if [ -n "$cfg_default" ] && [ -f "$base/$cfg_default" ]; then
    readlink -f "$base/$cfg_default"
    exit 0
  fi
done
for base in "$HORNERO_PICTURES_WALLPAPERS/$theme_dir" "$HORNERO_DATA_WALLPAPERS/$theme_dir"; do
  [ -d "$base" ] || continue
  find -L "$base" -maxdepth 1 \\( -type f -o -type l \\) \\( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \
    -o -iname "*.gif" -o -iname "*.bmp" \
  \\) 2>/dev/null | sort | head -n 1
  break
done
`]
        environment: ({
            "HORNERO_DEFAULT_WALLPAPER": themeLoader.pendingConfig.defaultWallpaper || "",
            "HORNERO_WALLPAPER_DIR": themeLoader.pendingConfig.wallpaperDir || themeLoader.themeId,
            "HORNERO_PICTURES_WALLPAPERS": root.picturesWallpapers,
            "HORNERO_DATA_WALLPAPERS": root.wallpapersDir,
        })

        stdout: StdioCollector {
            onStreamFinished: {
                const wp = text.trim();
                if (wp) {
                    themeLoader.resolvedWallpaper = wp;
                    root._startPaletteFromTheme();
                } else {
                    root._finishJob(false, `no wallpapers found for theme ${themeLoader.themeId}`);
                }
            }
        }
    }

    function _startPaletteFromTheme(): void {
        _pendingWallpaper = themeLoader.resolvedWallpaper;
        const cfg = themeLoader.pendingConfig || {};
        _pendingSchemeType = cfg.schemeType || "tonal-spot";
        _pendingDarkMode = cfg.darkMode !== undefined ? !!cfg.darkMode : true;
        _pendingGtkPreferDark = root.resolveGtkPreferDark(cfg, _pendingDarkMode);
        _pendingGtkColorScheme = root.resolveGtkColorScheme(cfg, _pendingDarkMode);
        m3Proc.running = true;
    }

    Process {
        id: writeWallpaperPointer
        command: ["sh", "-c", 'mkdir -p "$(dirname "$HORNERO_WALLPAPER_POINTER")" && tmp="$HORNERO_WALLPAPER_POINTER.tmp.$$" && printf "%s\\n" "$HORNERO_WALLPAPER_PATH" > "$tmp" && mv -f "$tmp" "$HORNERO_WALLPAPER_POINTER"']
        environment: ({
            "HORNERO_WALLPAPER_POINTER": root.wallpaperPointer,
            "HORNERO_WALLPAPER_PATH": root._pendingWallpaper
        })
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root._finishJob(false, `could not save wallpaper selection (exit ${exitCode})`);
                return;
            }
            if (root._syncAfterWallpaperPointer) {
                root._syncAfterWallpaperPointer = false;
                syncStateProc.running = true;
            }
        }
    }

    // Full M3 palette generation runs through horneroctl (materialyoucolor
    // backend); the native ImageAnalyser layer (WallpaperAnalysis,
    // Colours.wallLuminance/wallDominantColour) covers instant tone analysis.
    Process {
        id: m3Proc
        readonly property string image: root._pendingWallpaper || Wallpapers.actualCurrent
        readonly property string mode: root._pendingDarkMode ? "dark" : "light"
        readonly property string schemeType: root._pendingSchemeType || "tonal-spot"
        command: [
            ...root.m3Base,
            "--image", image,
            "--scheme-type", schemeType,
            "--mode", mode,
            "--output", root.schemeJson
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root._finishJob(false, `M3 colour generation failed (exit ${exitCode})`);
                return;
            }
            root._syncAfterWallpaperPointer = true;
            writeWallpaperPointer.running = true;
        }
    }

    // Native scheme persistence: adopt the live scheme meta into state.
    Process {
        id: syncStateProc
        command: root._pendingThemeId
            ? ["horneroctl", "appearance", "scheme", "sync-state", "--theme-id", root._pendingThemeId, "--yes"]
            : ["horneroctl", "appearance", "scheme", "sync-state", "--yes"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root._finishJob(false, `sync-state failed (exit ${exitCode})`);
                return;
            }
            touchSchemeProc.running = true;
            root._runSideEffects();
            // Finalize GTK through the native GtkSettings layer (gsettings
            // first, horneroctl gtk fallback inside). Completes via
            // the GtkSettings connection below.
            root._awaitingGtk = true;
            GtkSettings.applyFull(root._runThemeSideEffects ? (root._pendingGtkTheme || "") : "", root._runThemeSideEffects ? (root._pendingIconTheme || "") : "", root._runThemeSideEffects ? (root._pendingThemeId || "") : "", root._runThemeSideEffects ? (root._pendingGtkColorScheme || "") : "", root._pendingDarkMode);
        }
    }

    Process {
        id: touchSchemeProc
        command: ["touch", root.schemeJson]
    }

    // GTK applies run through the native GtkSettings layer (gsettings first,
    // horneroctl gtk fallback inside) and complete via its signal.
    Connections {
        target: GtkSettings

        function onApplyFinished(ok: bool, error: string): void {
            if (!root._awaitingGtk)
                return;
            root._awaitingGtk = false;
            root._finishJob(ok, error);
        }
    }

    Connections {
        target: Colours

        function onBuiltInThemePersisted(id: string, ok: bool, error: string): void {
            root._continueBuiltInThemeApply(id, ok, error);
        }
    }

    function _runSideEffects(): void {
        hyprlockProc.running = true;
        hyprReloadProc.running = true;

        if (root._runThemeSideEffects && root._pendingThemeId) {
            snappyProc.themeId = root._pendingThemeId;
            snappyProc.running = true;
        }

    }

    Process {
        id: hyprReloadProc
        command: ["hyprctl", "reload"]
    }

    // Snappy theme side effect runs through horneroctl (backend-owned).
    Process {
        id: snappyProc
        property string themeId: ""
        command: ["horneroctl", "apps", "switcher", "apply-theme-pack", snappyProc.themeId, "--yes"]
    }

    Process {
        id: hyprlockProc
        command: ["horneroctl", "appearance", "hyprlock", "--yes"]
    }

    Process {
        id: notifyProc
        property string themeName: ""
        command: ["notify-send", "Hornero Shell", `${notifyProc.themeName} theme applied`]
    }

    Process {
        id: notifyFailProc
        property string message: ""
        command: ["notify-send", "-u", "critical", "Hornero Shell", notifyFailProc.message || "Appearance apply failed"]
    }

    IpcHandler {
        target: "appearance"

        function applyTheme(id: string, wallpaper: string): void {
            root.applyThemeFromIpc(id, wallpaper || "");
        }

        function reload(): void {
            root.reload();
        }

        function setWallpaper(path: string): void {
            root.setWallpaper(path);
        }

        function setGtk(theme: string): void {
            root.setGtk(theme);
        }

        function setGtkColorScheme(policy: string): void {
            root.setGtkColorScheme(policy);
        }

        function setIcons(theme: string): void {
            root.setIcons(theme);
        }

        function isBusy(): string {
            return root._busy ? "1" : "0";
        }

        function lastError(): string {
            return root._lastError;
        }

        function status(): string {
            return Wallpapers.actualCurrent || "";
        }
    }
}

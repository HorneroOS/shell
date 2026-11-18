pragma Singleton

import qs.config
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // User packs override package catalogues. State writes use XDG Hornero paths.
    readonly property string wallpapersDir: `${Paths.data}/wallpapers`
    readonly property string picturesWallpapers: `${Paths.pictures}/Wallpapers`
    readonly property string wallpaperPointer: Paths.wallpaperPointer
    // Colours never come from the wallpaper (RFC 0001). A theme is a
    // complete Signal role table: built-ins live in services/Signal.qml,
    // catalogue themes carry a schema-v2 `palette`. Applying one writes the
    // live scheme (Paths.signalScheme) that Signal watches. GTK application
    // is native-first via GtkSettings (gsettings) with the horneroctl gtk
    // fallback there. See docs/NATIVE-APPEARANCE.md.

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
    property bool _pendingDarkMode: true
    property string _pendingGtkTheme: ""
    property string _pendingIconTheme: ""
    property string _pendingThemeName: ""
    property string _pendingThemeId: ""
    // "true" | "false" | "" (infer from gtk theme name / shell mode)
    property string _pendingGtkPreferDark: ""
    // follow | default | prefer-light | prefer-dark | "" (wallpaper jobs sync live policy)
    property string _pendingGtkColorScheme: ""
    property bool _runThemeSideEffects: false
    property string _lastError: ""
    readonly property string lastError: _lastError
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

    // Built-in Signal themes are owned by the shell, so they apply
    // directly. Catalogue themes go through horneroctl, which owns
    // verification and persisted appearance state and writes the live
    // scheme (or routes back through the IPC enqueue path below).
    function applyTheme(id: string, wallpaperPath: string): void {
        if (!id)
            return;
        if (Signal.isBuiltInTheme(id)) {
            applyThemeFromIpc(id, wallpaperPath);
            return;
        }
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

    // Undo of an Appearance change (services/Undo.qml): put back exactly
    // what was live before it, through the same jobs. `snap` = {theme,
    // wallpaper, gtk, icons, scheme, kinds:{theme,wallpaper,gtk,icons,scheme}}.
    // Busy while a job runs, so the Undo waits instead of racing it.
    function restoreAppearance(snap: var): var {
        if (root.busy)
            return Undo.busy;
        const k = snap.kinds;
        if (k.theme && snap.theme === "hornero-chromatic") {
            // A Chromatic palette is derived, not a catalogue theme: rebuild it.
            const back = ChromaticPreview._restoreSnapshot({
                "active": true,
                "request": ChromaticPreview.request
            });
            if (back !== true)
                return back;
        } else if (k.theme && snap.theme) {
            root.applyTheme(snap.theme, snap.wallpaper);
        } else if (k.wallpaper && snap.wallpaper) {
            root.setWallpaper(snap.wallpaper);
        }
        if (k.gtk && snap.gtk)
            root.setGtk(snap.gtk);
        if (k.icons && snap.icons)
            root.setIcons(snap.icons);
        if (k.scheme && snap.scheme)
            root.setGtkColorScheme(snap.scheme);
        return true;
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

    // Re-read the live scheme file (e.g. after an external writer).
    function reload(): void {
        _enqueue({
            kind: "reload"
        });
    }

    // Wallpaper is independent of colour: only the pointer changes.
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

    // Schema-v2 scheme object for a theme id, or null when the theme is
    // unknown or carries no complete Signal palette.
    function schemeFor(id: string): var {
        if (Signal.isBuiltInTheme(id))
            return Signal.builtInThemes[id];
        const cfg = ThemeCatalogue.themeById(id);
        if (!cfg || !Signal.isCompletePalette(cfg.palette))
            return null;
        return {
            "id": id,
            "name": cfg.name || id,
            "mode": cfg.mode === "light" ? "light" : "dark",
            "palette": cfg.palette,
            "terminal": Array.isArray(cfg.terminal) ? cfg.terminal : []
        };
    }

    function _pump(): void {
        if (_busy || _queue.length === 0)
            return;
        const job = _queue[0];
        if (job.kind === "theme" && !Signal.isBuiltInTheme(job.themeId || "") && !ThemeCatalogue.loaded)
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

        if (job.kind === "theme") {
            root._applyTheme(job.themeId || "", job.wallpaper || "");
        } else if (job.kind === "wallpaper") {
            _pendingWallpaper = job.wallpaper;
            writeWallpaperPointer.running = true;
        } else if (job.kind === "reload") {
            Signal.reloadFromDisk();
            _finishJob(true, "");
        } else if (job.kind === "gtk") {
            _awaitingGtk = true;
            GtkSettings.applyGtkTheme(job.gtkTheme || "");
        } else if (job.kind === "gtk-color-scheme") {
            _awaitingGtk = true;
            GtkSettings.applyColorScheme(job.gtkColorScheme || "follow", !Signal.light);
        } else if (job.kind === "icons") {
            _awaitingGtk = true;
            GtkSettings.applyIconTheme(job.iconTheme || "");
        } else {
            _finishJob(false, "unknown job kind");
        }
    }

    function _applyTheme(id: string, wallpaper: string): void {
        const cfg = ThemeCatalogue.themeById(id);
        const scheme = root.schemeFor(id);
        // A registry theme listed without its full palette (only the
        // preview swatch): horneroctl owns writing its live scheme, so
        // re-read it and continue with wallpaper/GTK.
        const externalScheme = !scheme && !!cfg && ThemeCatalogue.isSignalTheme(cfg);
        if (!scheme && !externalScheme) {
            root._finishJob(false, `theme ${id} is unavailable or has no Signal palette`);
            return;
        }
        const darkMode = scheme ? scheme.mode !== "light" : cfg.mode !== "light";
        _runThemeSideEffects = !Signal.isBuiltInTheme(id);
        _pendingThemeId = id;
        _pendingThemeName = (scheme && scheme.name) || (cfg && cfg.name) || id;
        _pendingDarkMode = darkMode;
        _pendingGtkTheme = cfg && cfg.gtkTheme ? cfg.gtkTheme : "";
        _pendingIconTheme = cfg && cfg.iconTheme ? cfg.iconTheme : "";
        _pendingGtkColorScheme = cfg ? root.resolveGtkColorScheme(cfg, darkMode) : (darkMode ? "prefer-dark" : "prefer-light");
        _pendingGtkPreferDark = _pendingGtkColorScheme === "prefer-light" || _pendingGtkColorScheme === "default" ? "false" : "true";
        _pendingWallpaper = wallpaper || (cfg ? (cfg.wallpaperPath || cfg.wallpaperPaths?.[cfg.defaultWallpaper] || "") : "");
        if (Config.appearance.theme !== id) {
            Config.appearance.theme = id;
            Config.save();
        }
        if (externalScheme) {
            Signal.reloadFromDisk();
            root._continueThemeApply(id, true, "");
            return;
        }
        Signal.applyScheme(scheme);
        Signal.persistScheme(scheme);
    }

    function _continueThemeApply(id: string, ok: bool, error: string): void {
        if (_jobKind !== "theme" || id !== _pendingThemeId)
            return;
        if (!ok) {
            _finishJob(false, `could not persist ${id}: ${error}`);
            return;
        }
        if (_pendingWallpaper) {
            writeWallpaperPointer.running = true;
            return;
        }
        _finishThemeApply();
    }

    function _finishThemeApply(): void {
        touchSchemeProc.running = true;
        _runSideEffects();
        _awaitingGtk = true;
        // Theme-pack GTK/icon recipes resolve through the shared registry
        // only for ids horneroctl knows; a built-in that the registry does
        // not (yet) list still sets the light/dark preference natively.
        if (ThemeCatalogue.themeById(_pendingThemeId)?.inRegistry === true || _runThemeSideEffects)
            GtkSettings.applyFull(_pendingGtkTheme, _pendingIconTheme, _pendingThemeId, _pendingGtkColorScheme, _pendingDarkMode);
        else
            GtkSettings.applyColorScheme(_pendingGtkColorScheme, _pendingDarkMode);
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
                Toaster.toast("Theme could not be applied", root._lastError, "alert-circle");
            }
            if (root._cliNextRequest) {
                const next = root._cliNextRequest;
                root._cliNextRequest = null;
                Qt.callLater(() => root.applyTheme(next.id, next.wallpaperPath));
            }
        }
    }

    Connections {
        target: ThemeCatalogue
        function onLoadedChanged(): void {
            root._pump();
        }
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
            if (root._jobKind === "theme")
                root._finishThemeApply();
            else
                root._finishJob(true, "");
        }
    }

    // Nudge file watchers that key off mtime (hyprlock/hyprland renderers).
    Process {
        id: touchSchemeProc
        command: ["touch", Signal.schemePath]
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
        target: Signal

        function onBuiltInThemePersisted(id: string, ok: bool, error: string): void {
            root._continueThemeApply(id, ok, error);
        }
    }

    function _runSideEffects(): void {
        if (Compositor.isHyprland) {
            hyprlockProc.running = true;
            hyprlandProc.running = true;
        }

        if (root._runThemeSideEffects && root._pendingThemeId) {
            snappyProc.themeId = root._pendingThemeId;
            snappyProc.running = true;
        }
    }

    Process {
        id: hyprReloadProc
        command: ["hyprctl", "reload"]
    }

    // Border colours: regenerate colors-hyprland.lua from the live
    // scheme before reloading Hyprland, or the reload keeps the old
    // (or factory) palette. horneroctl owns the rendering.
    Process {
        id: hyprlandProc
        command: ["horneroctl", "appearance", "hyprland", "--yes"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                notifyFailProc.message = "Could not regenerate Hyprland border colours";
                notifyFailProc.running = true;
            }
            if (Compositor.isHyprland)
                hyprReloadProc.running = true;
        }
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

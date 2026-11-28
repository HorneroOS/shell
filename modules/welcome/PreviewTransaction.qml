pragma Singleton

import "../../services/welcome_preview_tx.js" as TxModel
import qs.config
import qs.services
import qs.utils
import Hornero
import Quickshell
import Quickshell.Io
import QtQuick

// Reversible Live Preview Transaction owner for Welcome Personalize.
// - Captures baseline { themeId, themeMode, wallpaperPath, layoutPreset, chromaticActive }.
// - Uses zero-write live previews (Signal.beginPreview / Wallpapers.preview) where supported.
// - Persists active disk-mutating preview transactions to
//   `$XDG_STATE_HOME/hornero/welcome-preview-tx.json` via FileView so an unexpected
//   crash restores the baseline at next Startup.qml evaluation.
Singleton {
    id: root

    readonly property string txFilePath: `${Paths.state}/welcome-preview-tx.json`

    property var _tx: TxModel.createInitialTx()
    property bool ready: false
    property bool applying: false
    property string lastStatus: ""
    property string currentLayoutPreset: ""
    property bool _layoutChangedOnDisk: false
    property bool _themeChangedOnDisk: false

    readonly property bool active: _tx.active === true
    readonly property bool dirty: _tx.dirty === true
    readonly property var baseline: _tx.baseline
    readonly property var staged: _tx.staged

    function _writeTxFile(): void {
        txFile.setText(TxModel.serialize(root._tx));
    }

    function _baselineSnapshot(): var {
        return {
            themeId: Signal.themeId || Config.appearance.theme || "hornero-signal-night",
            themeMode: Signal.themeMode || "dark",
            wallpaperPath: Wallpapers.actualCurrent || "",
            layoutPreset: root.currentLayoutPreset || "",
            chromaticActive: Signal.themeId === "hornero-chromatic"
        };
    }

    function beginIfNeeded(): void {
        if (root.active)
            return;
        root._layoutChangedOnDisk = false;
        root._themeChangedOnDisk = false;
        const snap = root._baselineSnapshot();
        root._tx = TxModel.begin(root._tx, snap, Date.now(), new Date().toISOString());
        root._writeTxFile();
    }

    function previewTheme(themeId: string): void {
        const id = (themeId ?? "").trim();
        if (id === "")
            return;
        root.beginIfNeeded();
        const scheme = ThemePipeline.schemeFor(id);
        let mode = "dark";
        if (scheme) {
            mode = scheme.mode === "light" ? "light" : "dark";
            Signal.beginPreview(scheme);
        } else {
            const meta = ThemeCatalogue.themeById(id);
            mode = meta && meta.mode === "light" ? "light" : "dark";
            root._themeChangedOnDisk = true;
            ThemePipeline.applyTheme(id, "");
        }
        root._tx = TxModel.update(root._tx, {
            themeId: id,
            themeMode: mode,
            chromaticActive: false
        });
        root._writeTxFile();
        root.lastStatus = qsTr("Previewing %1").arg((scheme && scheme.name) || id);
    }

    function previewWallpaper(path: string): void {
        const p = (path ?? "").trim();
        if (p === "")
            return;
        root.beginIfNeeded();
        Wallpapers.preview(p);
        root._tx = TxModel.update(root._tx, { wallpaperPath: p });
        root._writeTxFile();
        root.lastStatus = qsTr("Previewing wallpaper");
    }

    function previewLayout(presetName: string): void {
        const name = (presetName ?? "").trim();
        if (name === "")
            return;
        root.beginIfNeeded();
        root._layoutChangedOnDisk = true;
        root._tx = TxModel.update(root._tx, { layoutPreset: name });
        root._writeTxFile();
        root.currentLayoutPreset = name;
        PresetApply.apply(name, name, false);
        root.lastStatus = qsTr("Previewing layout %1").arg(name);
    }

    function previewChromaticVariant(variant: string): void {
        const v = (variant ?? "").trim();
        if (v === "")
            return;
        root.beginIfNeeded();
        if (ChromaticPreview.set)
            ChromaticPreview.set("variant", v);
        root._tx = TxModel.update(root._tx, {
            themeId: "hornero-chromatic",
            chromaticActive: true
        });
        root._writeTxFile();
        root.lastStatus = qsTr("Previewing Chromatic (%1)").arg(v);
    }

    function apply(): void {
        if (!root.active)
            return;
        root.applying = true;
        const plan = TxModel.commit(root._tx);
        if (plan.persistTheme) {
            Signal.commitPreview();
            ThemePipeline.applyTheme(plan.targetThemeId, plan.persistWallpaper ? plan.targetWallpaperPath : "");
        } else {
            Signal.commitPreview();
            if (plan.persistWallpaper)
                Wallpapers.setWallpaper(plan.targetWallpaperPath);
        }
        if (!plan.persistWallpaper && Wallpapers.showPreview)
            Wallpapers.stopPreview();
        root._tx = plan.tx;
        root._layoutChangedOnDisk = false;
        root._themeChangedOnDisk = false;
        root._writeTxFile();
        root.applying = false;
        root.lastStatus = qsTr("Changes applied");
        Toaster.toast(qsTr("Hornero Welcome"), qsTr("Desktop personalization applied."), "circle-check", Toast.Success);
    }

    function revert(): void {
        if (!root.active)
            return;
        const plan = TxModel.revert(root._tx);
        Signal.cancelPreview();
        Wallpapers.stopPreview();
        if (plan.baseline) {
            if (root._themeChangedOnDisk && plan.baseline.themeId)
                ThemePipeline.applyTheme(plan.baseline.themeId, "");
            if (root._layoutChangedOnDisk && plan.baseline.layoutPreset) {
                root.currentLayoutPreset = plan.baseline.layoutPreset;
                PresetApply.apply(plan.baseline.layoutPreset, plan.baseline.layoutPreset, false);
            }
        }
        root._tx = plan.tx;
        root._layoutChangedOnDisk = false;
        root._themeChangedOnDisk = false;
        root._writeTxFile();
        root.lastStatus = qsTr("Reverted to previous look");
    }

    function checkAndRecoverOnStartup(): bool {
        if (!TxModel.needsCrashRecovery(root._tx))
            return false;
        const b = root._tx.baseline;
        if (b.themeId && b.themeId !== "hornero-chromatic")
            ThemePipeline.applyTheme(b.themeId, b.wallpaperPath || "");
        else if (b.wallpaperPath)
            Wallpapers.setWallpaper(b.wallpaperPath);
        if (b.layoutPreset) {
            root.currentLayoutPreset = b.layoutPreset;
            PresetApply.apply(b.layoutPreset, b.layoutPreset, false);
        }
        root._tx = TxModel.createInitialTx();
        root._writeTxFile();
        Toaster.toast(
            qsTr("Hornero Welcome"),
            qsTr("Restored your previous desktop look after an interrupted Welcome preview."),
            "refresh-alert",
            Toast.Info
        );
        return true;
    }

    FileView {
        id: txFile

        path: root.txFilePath
        onLoaded: {
            root._tx = TxModel.parse(text());
            root.ready = true;
        }
        onLoadFailed: {
            root._tx = TxModel.createInitialTx();
            root.ready = true;
        }
    }

    FileView {
        id: presetPointerFile

        path: `${Paths.state}/current-shell-preset`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.currentLayoutPreset = text().trim()
        onLoadFailed: root.currentLayoutPreset = ""
    }
}

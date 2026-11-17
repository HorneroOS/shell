import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.config
import qs.components
import qs.modules.controlcenter.appearance
import qs.modules.controlcenter.appearance.sections

// Offscreen palette-picker probe, driven by tests/test_appearance_palettes.py
// (and by hand for evidence PNGs). HSCENE: "gallery" renders every colour
// chooser of the Appearance pane over a panel and reports what they show.
// HTHEME picks the built-in theme (default Signal Night), HOUT a PNG path.
ShellRoot {
    id: root

    property var out: ({})

    function emit(): void {
        console.log("HRESULT " + JSON.stringify(root.out));
        Qt.quit();
    }

    QtObject {
        id: controller

        property string pendingGtkColorScheme: "prefer-dark"
        property string pendingThemeId: Signal.themeId
        property bool themeDirty: false
        property var previews: []

        function paletteForTheme(theme: var): var {
            return Signal.isBuiltInTheme(theme.id) ? Signal.builtInThemes[theme.id].palette : (Signal.isCompletePalette(theme.palette) ? theme.palette : (theme.swatch ?? ({})));
        }
        function terminalForTheme(theme: var): var {
            return Signal.isBuiltInTheme(theme.id) ? Signal.builtInThemes[theme.id].terminal : (Array.isArray(theme.terminal) ? theme.terminal : []);
        }
        function startGtkColorSchemePreview(id: string): void {
            previews = previews.concat([id]);
        }
        function stageGtkColorScheme(id: string): void {
            pendingGtkColorScheme = id;
        }
        function commitPending(): void {
        }
        function startThemePreview(): void {
        }
        function startWallpaperPreview(): void {
        }
        function stageThemeApply(): void {
        }
        function stageThemeApplyWithWallpaper(): void {
        }
    }

    QtObject {
        id: session

        function navigateTo(): void {
        }
    }

    Window {
        id: win

        visible: true
        width: 900
        height: 2600
        color: Signal.palette.ground

        Flickable {
            anchors.fill: parent
            contentHeight: col.implicitHeight

            ColumnLayout {
                id: col

                width: win.width - 32
                x: 16
                spacing: 16

                Repeater {
                    model: ["hornero-signal-night", "hornero-signal-day", "hornero-signal-contrast"]

                    ThemeSwatch {
                        required property string modelData

                        Layout.preferredWidth: 220
                        showTerminal: true
                        palette: Signal.builtInThemes[modelData]?.palette ?? ({})
                        terminal: Signal.builtInThemes[modelData]?.terminal ?? []
                    }
                }

                ChromaticVariantGallery {
                    id: gallery

                    Layout.fillWidth: true
                    current: "balanced"
                    resolved: "balanced"
                }

                GtkColorSchemeSection {
                    id: gtk

                    Layout.fillWidth: true
                    previewController: controller
                    session: session
                    expanded: true
                }

                ThemeEditorSection {
                    id: editor

                    Layout.fillWidth: true
                    previewController: controller
                    session: session
                    expanded: true
                }

                ThemesSection {
                    id: themes

                    Layout.fillWidth: true
                    previewController: controller
                    session: session
                    expanded: true
                }
            }
        }
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            Signal.applyBuiltInTheme(Quickshell.env("HTHEME") || "hornero-signal-night");
            ChromaticPreview.probe();
            ChromaticPreview.setSource("seed", ["#E8A33D"]);
            settle.start();
        }
    }

    property int ticks: 0

    Timer {
        id: settle

        interval: 250
        repeat: true
        onTriggered: {
            root.ticks++;
            const n = Object.keys(ChromaticPreview.variantSchemes).length + Object.keys(ChromaticPreview.variantFailed).length;
            if (n >= 8 || root.ticks > 60) {
                settle.stop();
                root.out.variantSchemes = Object.keys(ChromaticPreview.variantSchemes).sort();
                root.out.variantFailed = Object.keys(ChromaticPreview.variantFailed).sort();
                root.out.themeId = Signal.themeId;
                root.out.dbg = [ChromaticPreview.helperAvailable, ChromaticPreview.helperChecked, ChromaticPreview.busy, ChromaticPreview.variantPreviewsWanted, ChromaticPreview.errorCode, ChromaticPreview._variantSig.length, ChromaticPreview._variantCurrent];
                if (Quickshell.env("HMANAGE") === "1") {
                    root.manageScenario();
                    return;
                }
                if (Quickshell.env("HEDIT") === "1") {
                    root.editScenario();
                    return;
                }
                root.finish();
            }
        }
    }

    function editScenario(): void {
        const o = root.out;
        editor.chooseSource("hornero-signal-night");
        o.sourceEditable = editor.editable;
        editor.setRole("signal", "#FF00AA");
        editor.setRole("term3", "#112233");
        editor.setRole("ink", "not-a-colour");
        o.edit = {"count": editor.editCount, "signal": editor.scheme.palette.signal, "onSignal": editor.scheme.palette.onSignal, "term3": editor.scheme.terminal[3], "ink": editor.scheme.palette.ink, "glow": editor.scheme.palette.glow};
        editor.setPreviewing(true);
        o.previewing = Signal.previewing;
        o.previewSignal = String(Signal.palette.signal);
        editor.nameText = "My Neon Copy";
        editor.run("new");
        editWait.start();
    }

    property int manageStep: 0

    // The fake horneroctl cannot list themes, so every reload drops the
    // user theme; put it back (the real CLI keeps it on disk).
    function injectUserTheme(): void {
        if (ThemeCatalogue.themeById("my-dusk"))
            return;
        const night = Signal.builtInThemes["hornero-signal-night"];
        ThemeCatalogue.themes = ThemeCatalogue.themes.concat([{"id": "my-dusk", "name": "My Dusk", "collection": "user", "mode": "dark", "palette": night.palette, "terminal": night.terminal}]);
    }

    function manageScenario(): void {
        injectUserTheme();
        editor.sourceId = "";
        editor.chooseSource("my-dusk");
        root.out.isUser = editor.sourceIsUser;
        editor.renameSaved();
        manageWait.start();
    }

    Timer {
        id: manageWait

        interval: 200
        repeat: true
        onTriggered: {
            if (editor.busy)
                return;
            const o = root.out;
            root.injectUserTheme();
            if (root.manageStep === 0) {
                o.renamed = editor.status;
                editor.sourceId = "my-dusk";
                editor.confirmingDelete = true;
                editor.deleteSaved();
                root.manageStep = 1;
            } else if (root.manageStep === 1) {
                o.deleted = editor.status;
                o.trashed = editor.trash ? editor.trash.id : "";
                o.sourceAfterDelete = editor.sourceId;
                root.injectUserTheme();
                editor.undoDelete();
                root.manageStep = 2;
            } else {
                manageWait.stop();
                o.restored = editor.status;
                o.trashAfter = editor.trash === null;
                root.finish();
            }
        }
    }

    Timer {
        id: editWait

        interval: 200
        repeat: true
        onTriggered: {
            if (editor.busy)
                return;
            editWait.stop();
            root.out.status = editor.status;
            root.out.statusIsError = editor.statusIsError;
            editor.setRole("signal", "#00FF00");
            editor.resetRole("signal");
            root.out.afterReset = editor.scheme.palette.signal === Signal.builtInThemes["hornero-signal-night"].palette.signal;
            editor.setPreviewing(false);
            root.out.previewingAfter = Signal.previewing;
            root.finish();
        }
    }

    function finish(): void {
        const path = Quickshell.env("HOUT");
        if (path) {
            win.contentItem.grabToImage(img => {
                root.out.saved = img.saveToFile(path);
                root.emit();
            });
        } else {
            root.emit();
        }
    }
}

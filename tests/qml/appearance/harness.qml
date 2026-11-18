import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.config
import qs.modules.controlcenter
import qs.modules.controlcenter.appearance
import qs.modules.launcher.services

// Offscreen probe of the REAL Appearance pane, driven by
// tests/test_appearance_ux.py (and by hand for evidence PNGs).
// HSCENE picks what to do before the report:
//   idle          nothing (what a first-time user sees)
//   preview-theme point at Signal Day (theme hover preview)
//   preview-end   point at Signal Day, then leave it again
//   preview-variant open Chromatic, point at the Vibrant variant tile
//   collapsed     every section closed, tall window (section order)
// HOUT is an optional PNG path, HWIDTH/HHEIGHT the window size.
// The report lists the section titles in on-screen order, what the
// "Now using" strip and the preview banner say, and every visible button
// label, so a test can prove there is no Apply button.
ShellRoot {
    id: root

    readonly property string scene: Quickshell.env("HSCENE") || "idle"
    property string variantHovered: ""

    function walk(item: var, fn: var): void {
        if (!item)
            return;
        fn(item);
        const kids = item.children ?? [];
        for (let i = 0; i < kids.length; i++)
            root.walk(kids[i], fn);
    }

    function absY(item: var): real {
        return item.mapToItem(null, 0, 0).y;
    }

    function shown(item: var): bool {
        for (let it = item; it; it = it.parent) {
            if (!it.visible || it.opacity === 0)
                return false;
        }
        return true;
    }

    function texts(): var {
        const t = [];
        root.walk(pane, it => {
            if (typeof it.text === "string" && it.text !== "" && root.shown(it) && t.length < 12)
                t.push([it.text.slice(0, 30), Math.round(it.mapToItem(null, 0, 0).x), Math.round(it.mapToItem(null, 0, 0).y)]);
        });
        return t;
    }

    function report(): void {
        const sections = [];
        const buttons = [];
        let strip = null;
        let banner = null;
        root.walk(win.contentItem, it => {
            if (it.objectName === "appearanceSection" && root.shown(it))
                sections.push({
                    "key": it.sectionKey ?? "",
                    "title": it.title,
                    "y": root.absY(it)
                });
            if (it.objectName === "nowUsingStrip")
                strip = {
                    "visible": root.shown(it),
                    "title": it.nowTitle ?? "",
                    "detail": it.nowDetail ?? "",
                    "kind": it.nowKind ?? "",
                    "previewName": it.previewName ?? "",
                    "accessibleName": it.Accessible.name ?? ""
                };
            if (it.objectName === "previewBanner")
                banner = {
                    "visible": root.shown(it),
                    "state": it.bannerState ?? "",
                    "text": it.bannerText ?? ""
                };
            if (root.shown(it) && typeof it.text === "string" && it.text !== "" && (typeof it.clicked === "function") && it.width > 0)
                buttons.push(it.text);
        });
        // Legacy sections (no objectName) still report their order through
        // the CollapsibleSection API, so the before/after runs compare.
        if (sections.length === 0) {
            root.walk(win.contentItem, it => {
                if (typeof it.title === "string" && typeof it.expanded === "boolean" && typeof it.toggleRequested === "function" && root.shown(it))
                    sections.push({
                        "key": "",
                        "title": it.title,
                        "y": root.absY(it)
                    });
            });
        }
        sections.sort((a, b) => a.y - b.y);
        const out = {
            "scene": root.scene,
            "sections": sections.map(s => s.key || s.title),
            "titles": sections.map(s => s.title),
            "nowUsing": strip,
            "banner": banner,
            "buttons": buttons,
            "previewSource": pane.previewSource,
            "previewActive": pane.previewActive,
            "previewState": pane.previewState,
            "variantHovered": root.variantHovered,
            "paneSize": [pane.width, pane.height, pane.visible, pane.opacity],
            "texts": root.texts()
        };
        const outPath = Quickshell.env("HOUT");
        if (outPath) {
            stage.grabToImage(img => {
                out.saved = img.saveToFile(outPath);
                console.log("HRESULT " + JSON.stringify(out));
                Qt.quit();
            });
        } else {
            console.log("HRESULT " + JSON.stringify(out));
            Qt.quit();
        }
    }

    Session {
        id: session

        root: root
        active: "appearance"
    }

    Window {
        id: win

        visible: true
        width: Number(Quickshell.env("HWIDTH")) || 1180
        height: Number(Quickshell.env("HHEIGHT")) || (root.scene === "collapsed" ? 1700 : 820)
        color: Signal.palette.ground

        Rectangle {
            id: stage

            anchors.fill: parent
            color: Signal.palette.ground

            AppearancePane {
                id: pane

                anchors.fill: parent
                session: session
            }
        }
    }

    Timer {
        id: step1

        interval: 2500
        running: true
        onTriggered: {
            if (root.scene === "collapsed")
                pane.setAllSections(false);
            if (root.scene === "preview-variant")
                pane.revealSection("chromatic");
            if (root.scene === "preview-theme" || root.scene === "preview-end") {
                const day = Themes.themeById("hornero-signal-day");
                if (day)
                    pane.startThemePreview(day, Themes.palettePreviewPathFor(day, true), "");
            }
            step2.start();
        }
    }

    Timer {
        id: step2

        interval: root.scene === "preview-variant" ? 6000 : 1200
        onTriggered: {
            if (root.scene === "preview-variant") {
                ChromaticPreview.hoverVariant("vibrant");
                root.variantHovered = ChromaticPreview.hoveredVariant;
            }
            if (root.scene === "preview-end")
                pane.endPreviewFor ? pane.endPreviewFor("theme") : pane.clearPreviewFor("theme");
            step3.start();
        }
    }

    Timer {
        id: step3

        interval: 900
        onTriggered: root.report()
    }

    Timer {
        interval: 60000
        running: true
        onTriggered: {
            console.log("HRESULT " + JSON.stringify({
                "error": "timeout"
            }));
            Qt.quit();
        }
    }
}

pragma ComponentBehavior: Bound

import "../../launcher/services"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts
import "../../../services/chromaticcli.js" as Cli

// The one answer to "what am I using right now?" (docs/APPEARANCE-PANE.md).
// Pinned above the Appearance sections, it always names what is APPLIED:
// the theme, or Chromatic with its style, mode and source, over the
// applied colours. A hover/focus preview never changes it (while the live
// shell shows a candidate it reads Signal's pre-preview snapshot); it only
// gains a "Previewing …" note, so the user can always compare. When the
// last change can still be undone, the Undo sits right here next to the
// thing it would put back (the global strip at the bottom shows the same
// offer; both call services/Undo.qml).
StyledRect {
    id: root

    // AppearancePane: previewState / previewTitle for the note.
    property var rootPane: null

    readonly property var snap: Signal.previewing ? Signal._snapshot : null
    readonly property string appliedId: snap ? (snap.id ?? "") : Signal.themeId
    readonly property bool appliedLight: snap ? snap.mode === "light" : Signal.themeMode === "light"
    readonly property var appliedChromatic: snap ? snap.chromatic : Signal.chromatic
    readonly property bool contrastOverride: Config.appearance.highContrast

    readonly property string nowKind: contrastOverride ? "contrast" : appliedId === "hornero-chromatic" ? "chromatic" : appliedTheme ? "theme" : "custom"
    readonly property var appliedTheme: appliedId && appliedId !== "hornero-chromatic" ? Themes.themeById(appliedId) : null

    readonly property string modeLabel: appliedLight ? qsTr("Day") : qsTr("Night")

    function sourceLabel(): string {
        const req = ChromaticPreview.request;
        switch (req.source) {
        case "image":
            return qsTr("from %1").arg(Strings.wallpaperDisplayName(req.path) || qsTr("an image"));
        case "seed":
            return qsTr("from colour %1").arg((req.seeds ?? [])[0] ?? "");
        case "house":
            return qsTr("from the Signal house palette");
        default:
            return Wallpapers.actualCurrent ? qsTr("from wallpaper %1").arg(Strings.wallpaperDisplayName(Wallpapers.actualCurrent)) : qsTr("from your wallpaper");
        }
    }

    readonly property string nowTitle: {
        switch (nowKind) {
        case "contrast":
            return qsTr("High contrast");
        case "chromatic":
            return qsTr("Chromatic");
        case "theme":
            return appliedTheme.name ?? appliedId;
        default:
            return qsTr("Custom appearance");
        }
    }

    readonly property string nowDetail: {
        switch (nowKind) {
        case "contrast":
            return qsTr("Accessibility override is on; your look returns when it is off");
        case "chromatic":
            {
                const style = Cli.appliedStyle(appliedChromatic);
                const parts = [];
                if (style)
                    parts.push(Cli.styleLabel(style));
                parts.push(modeLabel);
                parts.push(sourceLabel());
                return parts.join(" · ");
            }
        case "theme":
            {
                const coll = appliedTheme.collection === "hornero-originals" ? qsTr("Hornero Original") : appliedTheme.collection === "user" ? qsTr("Your palette") : qsTr("Theme pack");
                return `${modeLabel} · ${coll}`;
            }
        default:
            return qsTr("%1 · colours set outside the theme list").arg(modeLabel);
        }
    }

    function role(name: string): color {
        if (snap && snap.palette && snap.palette[name])
            return snap.palette[name];
        return contrastOverride ? Signal.contrastPalette[name] : Signal.current[name];
    }

    readonly property bool busy: ThemePipeline.busy || ChromaticPreview.applying
    readonly property string previewName: {
        const pointed = ChromaticPreview.hoveredVariant;
        if (pointed !== "")
            return qsTr("Chromatic · %1").arg(Cli.styleLabel(pointed));
        if (rootPane && rootPane.previewState === "previewing")
            return rootPane.previewTitle;
        return "";
    }
    readonly property bool previewing: previewName !== ""
    readonly property var undoKeys: ["appearance", "chromatic", "look", "atmosphere-reset", "theme-delete"]
    readonly property bool canUndoHere: Undo.canUndo && undoKeys.indexOf(Undo.key) >= 0

    objectName: "nowUsingStrip"
    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
    radius: Config.appearance.cozyChips ? Appearance.rounding.normal : Appearance.rounding.small
    color: Signal.layer(Signal.palette.raised, 1)
    border.width: 1
    border.color: Signal.palette.ruleStrong

    Accessible.role: Accessible.StaticText
    Accessible.name: `${Microcopy.plainLine("appearance.now")}: ${nowTitle}. ${nowDetail}` + (previewing ? `. ${Microcopy.plainLine("appearance.previewing")}: ${previewName}` : "") + (busy ? `. ${Microcopy.plainLine("appearance.applying")}` : "")

    // Left signal rail: the strip reads as the panel's "status line".
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1
        width: 3
        radius: 1.5 // fixed: 3 px status rail end rounding, not a theme corner
        color: root.busy ? Signal.palette.cue : Signal.palette.signal
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.normal + 3
        anchors.rightMargin: Appearance.padding.normal
        spacing: Appearance.spacing.normal

        // The applied colours, never a preview: ground, panel, ink, signal,
        // cue, phosphor in one stacked chip.
        Grid {
            Layout.alignment: Qt.AlignVCenter
            columns: 3
            spacing: 2
            Accessible.ignored: true

            Repeater {
                model: ["ground", "panel", "ink", "signal", "cue", "phosphor"]

                Rectangle {
                    required property string modelData

                    width: 12
                    height: 12
                    radius: Config.appearance.cozyChips ? 6 : 2 // fixed: 12 px colour dot (round when cozy), not a theme corner
                    color: root.role(modelData)
                    border.width: 1
                    border.color: Signal.palette.rule
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1

            Eyebrow {
                label: Microcopy.line("appearance.now")
            }

            StyledText {
                Layout.fillWidth: true
                text: root.nowTitle
                font.pointSize: Appearance.font.size.normal
                font.weight: Appearance.font.weight.strong
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.nowDetail
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            // Hover/focus preview note: the strip itself never changes.
            StyledText {
                Layout.fillWidth: true
                visible: root.previewing && !root.busy
                text: `${Microcopy.line("appearance.previewing")}: ${root.previewName}`
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.cue
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.busy
                text: Microcopy.line("appearance.applying")
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.cue
                elide: Text.ElideRight
            }
        }

        TextButton {
            visible: root.canUndoHere
            Layout.alignment: Qt.AlignVCenter
            type: TextButton.Tonal
            text: qsTr("Undo")
            Accessible.name: qsTr("Undo %1").arg(Undo.title)
            onClicked: Undo.undo()
        }
    }
}

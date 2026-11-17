pragma ComponentBehavior: Bound

import ".."
import "../../../launcher/services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var previewController
    required property var session

    title: qsTr("GTK color scheme")
    description: qsTr("Libadwaita / portals — independent from Theme mode. Auto lets apps decide.")
    showBackground: true

    readonly property var schemeOptions: [
        {
            id: "follow",
            icon: "refresh",
            name: qsTr("Follow theme mode"),
            note: qsTr("Light or dark with the theme")
        },
        {
            id: "default",
            icon: "contrast",
            name: qsTr("Auto (apps decide)"),
            note: qsTr("No preference sent")
        },
        {
            id: "prefer-light",
            icon: "sun",
            name: qsTr("Prefer light"),
            note: qsTr("Signal Day colours")
        },
        {
            id: "prefer-dark",
            icon: "moon",
            name: qsTr("Prefer dark"),
            note: qsTr("Signal Night colours")
        }
    ]

    readonly property string themeDefaultScheme: {
        const id = previewController.pendingThemeId;
        if (!id)
            return "";
        const theme = Themes.themeById(id);
        if (!theme)
            return "";
        return theme.gtkColorScheme || "";
    }

    readonly property bool schemeDivergesFromTheme: themeDefaultScheme !== "" && previewController.pendingGtkColorScheme !== themeDefaultScheme

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: root.schemeOptions

            delegate: PaletteOption {
                id: option

                required property var modelData
                // Light and dark show the real Signal Day and Night tables;
                // Follow and Auto have no palette of their own, so they show
                // the live roles (an empty table falls back to Signal.palette).
                readonly property var scheme: modelData.id === "prefer-light" ? Signal.builtInThemes["hornero-signal-day"] : modelData.id === "prefer-dark" ? Signal.builtInThemes["hornero-signal-night"] : null

                Layout.fillWidth: true
                horizontal: true
                title: modelData.name
                note: modelData.note
                selected: modelData.id === previewController.pendingGtkColorScheme
                kind: "button"
                palette: scheme ? scheme.palette : ({})
                terminal: scheme ? scheme.terminal : []
                paletteLabel: scheme ? qsTr("Palette preview: %1").arg(modelData.name) : qsTr("Palette preview: your current theme")
                onActivated: {
                    previewController.startGtkColorSchemePreview(modelData.id);
                    previewController.stageGtkColorScheme(modelData.id);
                    previewController.commitPending();
                }
                onPreviewStarted: previewController.startGtkColorSchemePreview(modelData.id)
            }
        }

        StyledText {
            visible: root.schemeDivergesFromTheme
            text: qsTr("Differs from theme default (%1)").arg(root.themeDefaultScheme)
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }
    }
}

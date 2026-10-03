pragma ComponentBehavior: Bound

import ".."
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

    title: qsTr("GTK theme")
    description: qsTr("Application chrome theme — applies on click")
    showBackground: true

    readonly property var themeNames: ThemeCatalogue.gtkThemes

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: root.themeNames

            delegate: StyledRect {
                required property string modelData

                Layout.fillWidth: true

                readonly property bool isCurrent: modelData === previewController.pendingGtkTheme

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Appearance.rounding.normal
                border.width: isCurrent ? 1 : 0
                border.color: Colours.palette.m3primary

                StateLayer {
                    function onClicked(): void {
                        previewController.stageGtkTheme(modelData);
                        previewController.commitPending();
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.padding.normal

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData
                        font.pointSize: Appearance.font.size.normal
                    }

                    MaterialIcon {
                        visible: isCurrent
                        text: "check"
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.large
                    }
                }

                implicitHeight: Appearance.padding.normal * 2 + Appearance.font.size.normal * 1.4
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: ThemeCatalogue.gtkThemesLoaded && root.themeNames.length === 0
            text: ThemeCatalogue.gtkThemesFailed
                ? qsTr("Hornero couldn't load the installed GTK styles.")
                : qsTr("No GTK styles are available. Install a GTK theme to style your apps.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }
}

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

    title: qsTr("Icon theme")
    description: qsTr("Desktop icon set — applies on click")
    showBackground: true

    readonly property var iconNames: ThemeCatalogue.iconThemes

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        Repeater {
            model: root.iconNames

            delegate: StyledRect {
                required property string modelData

                Layout.fillWidth: true

                readonly property bool isCurrent: modelData === previewController.pendingIconTheme

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Appearance.rounding.normal
                border.width: isCurrent ? 1 : 0
                border.color: Colours.palette.m3primary

                StateLayer {
                    function onClicked(): void {
                        previewController.stageIconTheme(modelData);
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
            visible: !ThemeCatalogue.iconThemesLoaded
            text: qsTr("Checking installed icon styles…")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true
            visible: ThemeCatalogue.iconThemesLoaded && root.iconNames.length === 0
            text: ThemeCatalogue.iconThemesFailed
                ? qsTr("Hornero couldn't load the installed icon styles.")
                : qsTr("No icon styles are available. Install an icon theme to restore app icons.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        TextButton {
            Layout.alignment: Qt.AlignLeft
            visible: ThemeCatalogue.iconThemesLoaded && ThemeCatalogue.iconThemesFailed && !ThemeCatalogue.appearanceChoicesLoading
            text: qsTr("Try again")
            type: TextButton.Text
            onClicked: ThemeCatalogue.loadAppearanceChoices()
        }
    }
}

pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var dialog

    implicitWidth: inner.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: inner.implicitHeight + Appearance.padding.normal * 2

    color: Signal.tPalette.panel

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        Item {
            implicitWidth: implicitHeight
            implicitHeight: upIcon.implicitHeight + Appearance.padding.small * 2

            StateLayer {
                radius: Appearance.rounding.small
                disabled: root.dialog.cwd.length === 1

                function onClicked(): void {
                    root.dialog.cwd.pop();
                }
            }

            Glyph {
                id: upIcon

                anchors.centerIn: parent
                name: "folder-up"
                color: root.dialog.cwd.length === 1 ? Signal.palette.ruleStrong : Signal.palette.ink
            }
        }

        StyledRect {
            Layout.fillWidth: true

            radius: Appearance.rounding.small
            color: Signal.tPalette.raised

            implicitHeight: pathComponents.implicitHeight + pathComponents.anchors.margins * 2

            RowLayout {
                id: pathComponents

                anchors.fill: parent
                anchors.margins: Appearance.padding.small / 2
                anchors.leftMargin: 0

                spacing: Appearance.spacing.small

                Repeater {
                    model: root.dialog.cwd

                    RowLayout {
                        id: folder

                        required property string modelData
                        required property int index

                        spacing: 0

                        Loader {
                            Layout.rightMargin: Appearance.spacing.small
                            active: folder.index > 0
                            sourceComponent: StyledText {
                                text: "/"
                                color: Signal.palette.inkMuted
                                font.bold: true
                            }
                        }

                        Item {
                            implicitWidth: homeIcon.implicitWidth + (homeIcon.active ? Appearance.padding.small : 0) + folderName.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: folderName.implicitHeight + Appearance.padding.small * 2

                            Loader {
                                anchors.fill: parent
                                active: folder.index < root.dialog.cwd.length - 1
                                sourceComponent: StateLayer {
                                    radius: Appearance.rounding.small

                                    function onClicked(): void {
                                        root.dialog.cwd = root.dialog.cwd.slice(0, folder.index + 1);
                                    }
                                }
                            }

                            Loader {
                                id: homeIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Appearance.padding.normal

                                active: folder.index === 0 && folder.modelData === "Home"
                                sourceComponent: Glyph {
                                    name: "home"
                                    color: root.dialog.cwd.length === 1 ? Signal.palette.ink : Signal.palette.inkMuted
                                }
                            }

                            StyledText {
                                id: folderName

                                anchors.left: homeIcon.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: homeIcon.active ? Appearance.padding.small : 0

                                text: folder.modelData
                                color: folder.index < root.dialog.cwd.length - 1 ? Signal.palette.inkMuted : Signal.palette.ink
                                font.bold: true
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}

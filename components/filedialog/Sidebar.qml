pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var dialog

    implicitWidth: Sizes.sidebarWidth
    implicitHeight: inner.implicitHeight + Appearance.padding.normal * 2

    color: Signal.tPalette.panel

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small / 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.padding.small / 2
            Layout.bottomMargin: Appearance.spacing.normal
            text: qsTr("Files")
            color: Signal.palette.ink
            font.pointSize: Appearance.font.size.larger
            font.bold: true
        }

        Repeater {
            model: ["Home", "Downloads", "Desktop", "Documents", "Music", "Pictures", "Videos"]

            StyledRect {
                id: place

                required property string modelData
                readonly property bool selected: modelData === root.dialog.cwd[root.dialog.cwd.length - 1]

                Layout.fillWidth: true
                implicitHeight: placeInner.implicitHeight + Appearance.padding.normal * 2

                radius: Appearance.rounding.full
                color: Qt.alpha(Signal.palette.cueWell, selected ? 1 : 0)

                StateLayer {
                    color: place.selected ? Signal.palette.onCueWell : Signal.palette.ink

                    function onClicked(): void {
                        if (place.modelData === "Home")
                            root.dialog.cwd = ["Home"];
                        else
                            root.dialog.cwd = ["Home", place.modelData];
                    }
                }

                RowLayout {
                    id: placeInner

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.large

                    spacing: Appearance.spacing.normal

                    Glyph {
                        name: {
                            const p = place.modelData;
                            if (p === "Home")
                                return "home";
                            if (p === "Downloads")
                                return "file-download";
                            if (p === "Desktop")
                                return "device-desktop";
                            if (p === "Documents")
                                return "file-text";
                            if (p === "Music")
                                return "music";
                            if (p === "Pictures")
                                return "photo";
                            if (p === "Videos")
                                return "movie";
                            return "folder";
                        }
                        color: place.selected ? Signal.palette.onCueWell : Signal.palette.ink
                        font.pointSize: Appearance.font.size.large
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: place.modelData
                        color: place.selected ? Signal.palette.onCueWell : Signal.palette.ink
                        font.pointSize: Appearance.font.size.normal
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

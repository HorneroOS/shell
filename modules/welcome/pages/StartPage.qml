import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.welcome
import QtQuick
import QtQuick.Layouts

// Start stub page: proves the nav -> content pipeline. Real copy, actions
// and feature status arrive in part 2 (content catalog + VM scenarios).
ColumnLayout {
    id: root

    spacing: Appearance.spacing.large

    Item {
        Layout.fillHeight: true
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: "waving_hand"
        color: Colours.palette.m3primary
        font.pointSize: Appearance.font.size.large * 3
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        text: qsTr("Welcome to Hornero")
        font.pointSize: Appearance.font.size.large * 2
        font.weight: 600
        horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: 520
        text: qsTr("Your desktop is ready. Take a short tour, or explore on your own — this window stops opening automatically as soon as you switch that off below.")
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    TextButton {
        Layout.alignment: Qt.AlignHCenter
        text: qsTr("Take the tour")
        onClicked: Welcome.open("navigate")
    }

    Item {
        Layout.fillHeight: true
    }
}

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Generic placeholder for sections whose real content lands in part 2.
// Callers pass an already-translated title (qsTr at the call site).
ColumnLayout {
    id: root

    required property string icon
    required property string title

    spacing: Appearance.spacing.normal

    Item {
        Layout.fillHeight: true
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: root.icon
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.large * 2
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        text: root.title
        font.pointSize: Appearance.font.size.large
        font.weight: 600
        horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: 480
        text: qsTr("Real content for this section arrives in part 2.")
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        Layout.fillHeight: true
    }
}

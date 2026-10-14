pragma ComponentBehavior: Bound

import qs.components.controls
import qs.config
import QtQuick
import QtQuick.Layouts

// Keeps trailing actions centered on one stable rail even when their labels
// have different widths (for example Selected, Install first, and Use this).
Item {
    id: root

    property alias text: button.text
    property alias type: button.type
    property bool controlEnabled: true
    property bool disabled: false
    property int accessibilityRole: Accessible.Button
    property string accessibilityName: text

    signal clicked

    Layout.minimumWidth: Config.controlCenter.actionColumnWidth
    Layout.preferredWidth: Config.controlCenter.actionColumnWidth
    Layout.maximumWidth: Config.controlCenter.actionColumnWidth
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: Config.controlCenter.actionColumnWidth
    implicitHeight: button.implicitHeight

    TextButton {
        id: button

        anchors.centerIn: parent
        enabled: root.controlEnabled
        disabled: root.disabled
        Accessible.role: root.accessibilityRole
        Accessible.name: root.accessibilityName

        onClicked: root.clicked()
    }
}

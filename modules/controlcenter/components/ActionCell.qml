pragma ComponentBehavior: Bound

import qs.components.controls
import qs.config
import QtQuick
import QtQuick.Layouts

// Keeps trailing actions on one stable right edge even when their labels
// have different widths (for example Selected, Install first, and Use this).
Item {
    id: root

    property alias text: button.text
    property alias type: button.type
    property bool controlEnabled: true
    property bool disabled: false
    property int accessibilityRole: Accessible.Button
    property string accessibilityName: text

    // Keep the shared action rail wide enough as the user increases the
    // interface type scale. A fixed 136 px slot can make longer action
    // labels overlap the setting text at larger sizes.
    readonly property real actionColumnWidth: Math.max(
        Config.controlCenter.actionColumnWidth,
        Config.controlCenter.actionColumnWidth * Appearance.font.size.scale
    )

    signal clicked

    Layout.minimumWidth: actionColumnWidth
    Layout.preferredWidth: actionColumnWidth
    Layout.maximumWidth: actionColumnWidth
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: actionColumnWidth
    implicitHeight: button.implicitHeight

    TextButton {
        id: button

        // TextButton is a project Item-based control rather than Qt Quick
        // Controls' Button. Give it a concrete size so the visual action
        // stays on the same trailing edge across labels of different
        // lengths.
        width: implicitWidth
        height: implicitHeight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.controlEnabled
        // Keep visual and interaction state aligned even when a caller only
        // marks the action unavailable through controlEnabled.
        disabled: root.disabled || !root.controlEnabled
        Accessible.role: root.accessibilityRole
        Accessible.name: root.accessibilityName

        onClicked: root.clicked()
    }
}

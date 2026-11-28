pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Filterable keybinding cheatsheet view wrapping ShortcutList.qml.
Item {
    id: root

    property bool windowActive: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Shortcuts reference")

    onVisibleChanged: {
        if (visible)
            list.focusSearch();
    }

    StyledFlickable {
        id: shortcutsFlick

        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: list.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: shortcutsFlick
        }

        ShortcutList {
            id: list

            width: parent.width - Appearance.padding.small
        }
    }
}

import qs.components
import qs.services
import qs.config
import QtQuick.Layouts

ColumnLayout {
    // Rack rhythm: rows inside one popout module sit 8 apart.
    spacing: Appearance.spacing.smaller

    StyledText {
        text: qsTr("Capslock: %1").arg(Compositor.capsLock ? qsTr("Enabled") : qsTr("Disabled"))
    }

    StyledText {
        text: qsTr("Numlock: %1").arg(Compositor.numLock ? qsTr("Enabled") : qsTr("Disabled"))
    }
}

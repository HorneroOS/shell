import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Typed shell actions (legacy tools drawer). options.actions lists ids from
// ShellActions.known; unknown ids are skipped with a warning.
Item {
    id: root

    property bool vertical
    property var options: ({})
    readonly property var actions: {
        const ids = Array.isArray(options.actions) ? options.actions : ["screenshot", "layoutPicker", "settings"];
        return ids.filter(id => {
            if (ShellActions.isKnown(id))
                return true;
            console.warn(`[bar] quickActions: unknown action "${id}"`);
            return false;
        });
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: root.actions

            BarButton {
                required property string modelData

                icon: ShellActions.known[modelData].icon
                label: ShellActions.known[modelData].label
                colour: Colours.palette.m3onSurfaceVariant
                iconSize: Appearance.font.size.normal
                onActivated: ShellActions.run(modelData)
            }
        }
    }
}

pragma ComponentBehavior: Bound

import ".."
import qs.components.controls
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property string pluginId
    required property string screenName

    readonly property var verticalItems: [verticalTop, verticalMiddle, verticalBottom]
    readonly property var horizontalItems: [horizontalLeft, horizontalCenter, horizontalRight]

    function currentParts(): var {
        const parts = Config.plugins.desktopWidgetSlot(pluginId, screenName).split("-");
        return {vertical: parts[0] || "bottom", horizontal: parts[1] || "right"};
    }

    function setPart(vertical: string, horizontal: string): void {
        Config.plugins.setDesktopWidgetSlot(pluginId, screenName, `${vertical}-${horizontal}`);
    }

    SplitButtonRow {
        label: qsTr("%1 · vertical slot").arg(root.screenName)
        accessibleName: qsTr("%1 display, vertical widget position").arg(root.screenName)
        menuItems: root.verticalItems

        Component.onCompleted: {
            const part = root.currentParts().vertical;
            for (const option of menuItems) {
                if (option.value === part)
                    active = option;
            }
        }

        onSelected: item => root.setPart(item.value, root.currentParts().horizontal)
    }

    SplitButtonRow {
        label: qsTr("%1 · horizontal slot").arg(root.screenName)
        accessibleName: qsTr("%1 display, horizontal widget position").arg(root.screenName)
        menuItems: root.horizontalItems

        Component.onCompleted: {
            const part = root.currentParts().horizontal;
            for (const option of menuItems) {
                if (option.value === part)
                    active = option;
            }
        }

        onSelected: item => root.setPart(root.currentParts().vertical, item.value)
    }

    MenuItem {
        id: verticalTop
        text: qsTr("Top")
        icon: "vertical_align_top"
        property string value: "top"
    }
    MenuItem {
        id: verticalMiddle
        text: qsTr("Middle")
        icon: "vertical_align_center"
        property string value: "middle"
    }
    MenuItem {
        id: verticalBottom
        text: qsTr("Bottom")
        icon: "vertical_align_bottom"
        property string value: "bottom"
    }
    MenuItem {
        id: horizontalLeft
        text: qsTr("Left")
        icon: "align_horizontal_left"
        property string value: "left"
    }
    MenuItem {
        id: horizontalCenter
        text: qsTr("Center")
        icon: "align_horizontal_center"
        property string value: "center"
    }
    MenuItem {
        id: horizontalRight
        text: qsTr("Right")
        icon: "align_horizontal_right"
        property string value: "right"
    }
}

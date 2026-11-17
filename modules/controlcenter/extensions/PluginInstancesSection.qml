pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Instances of one extension's desktop widget (RFC 0003 section 6). The
// primary instance always exists; extra instances are offered only when the
// extension declares `surfaces.desktop.instances` (it reads its settings
// per instance), so a second copy can never silently share the first one's
// state. Selecting an instance retargets the generated settings and the
// live preview below to that instance; Add duplicates the selected
// instance's stored settings; Remove deletes the instance with its
// settings, position and size. Everything persists through
// Config.plugins (plugins.instances in shell.json).
ColumnLayout {
    id: root

    required property string pluginId
    // "" = the primary instance, else an extra instance id.
    property string selected: ""

    readonly property bool supported: (Plugins.surfaceFor(Plugins.entryFor(root.pluginId), "desktop")?.instances ?? false) === true
    readonly property var extras: Config.plugins.instancesOf(root.pluginId)
    readonly property bool atLimit: root.extras.length >= Config.plugins.maxInstances

    // A removed instance falls back to the primary.
    onExtrasChanged: {
        if (root.selected !== "" && !root.extras.some(item => item.id === root.selected))
            root.selected = "";
    }

    visible: root.supported
    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Instances")
        font.weight: Appearance.font.weight.medium
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Place the same widget more than once. Each instance has its own settings, position and size.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.Wrap
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        ToggleButton {
            toggled: root.selected === ""
            label: qsTr("Main")
            Accessible.name: qsTr("Edit the main instance")
            onClicked: root.selected = ""
        }

        Repeater {
            model: root.extras

            delegate: ToggleButton {
                required property var modelData
                required property int index

                toggled: root.selected === modelData.id
                label: modelData.label !== "" ? modelData.label : qsTr("Instance %1").arg(index + 2)
                Accessible.name: qsTr("Edit %1").arg(label)
                onClicked: root.selected = modelData.id
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledTextField {
            id: labelField

            Layout.preferredWidth: 180
            visible: root.selected !== ""
            maximumLength: 32
            Accessible.name: qsTr("Instance name")
            placeholderText: qsTr("Instance name")
            padding: Appearance.padding.small
            leftPadding: Appearance.padding.normal
            rightPadding: Appearance.padding.normal
            background: StyledRect {
                radius: Appearance.rounding.small
                color: Signal.tPalette.raised
            }
            onVisibleChanged: if (visible)
                text = root.extras.find(item => item.id === root.selected)?.label ?? ""
            onEditingFinished: Config.plugins.renameInstance(root.pluginId, root.selected, text)

            Connections {
                target: root

                function onSelectedChanged(): void {
                    labelField.text = root.extras.find(item => item.id === root.selected)?.label ?? "";
                }
            }
        }

        TextButton {
            enabled: !root.atLimit
            text: root.selected === "" ? qsTr("Add instance") : qsTr("Duplicate")
            type: TextButton.Tonal
            onClicked: {
                const id = Config.plugins.addInstance(root.pluginId, "", Config.plugins.instanceKey(root.pluginId, root.selected));
                if (id !== "")
                    root.selected = id;
            }
        }

        TextButton {
            visible: root.selected !== ""
            text: qsTr("Remove instance")
            type: TextButton.Text
            onClicked: Config.plugins.removeInstance(root.pluginId, root.selected)
        }

        StyledText {
            visible: root.atLimit
            text: qsTr("Up to %1 extra instances.").arg(Config.plugins.maxInstances)
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
        }
    }
}

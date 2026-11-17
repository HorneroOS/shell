pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    height: implicitHeight

    required property Session session

    spacing: Appearance.spacing.normal

    SettingsHeader {
        icon: "bluetooth"
        title: qsTr("Bluetooth Settings")
    }

    StyledText {
        Layout.fillWidth: true
        visible: !root.session.bt.hasAdapter
        wrapMode: Text.WordWrap
        text: qsTr("No Bluetooth adapter found. The Bluetooth service may be stopped, or this machine has no Bluetooth hardware.")
        color: Signal.palette.inkMuted
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.session.bt.lastError !== ""
        wrapMode: Text.WordWrap
        text: root.session.bt.lastError
        color: Signal.palette.alert
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.large
        text: qsTr("Adapter status")
        font.pointSize: Appearance.font.size.larger
        font.weight: 500
    }

    StyledText {
        text: qsTr("General adapter settings")
        color: Signal.palette.inkMuted
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: adapterStatus.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.small
        color: Signal.tPalette.panel

        ColumnLayout {
            id: adapterStatus

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.larger

            Toggle {
                label: qsTr("Powered")
                checked: root.session.bt.currentAdapter?.enabled ?? false
                toggle.onToggled: root.session.bt.setPowered(checked)
            }

            Toggle {
                label: qsTr("Discoverable")
                checked: root.session.bt.currentAdapter?.discoverable ?? false
                toggle.onToggled: {
                    const adapter = root.session.bt.currentAdapter;
                    if (adapter) {
                        adapter.discoverableTimeout = checked ? 120 : 0;
                        adapter.discoverable = checked;
                    }
                }
            }

            Toggle {
                label: qsTr("Pairable")
                checked: root.session.bt.currentAdapter?.pairable ?? false
                toggle.onToggled: {
                    const adapter = root.session.bt.currentAdapter;
                    if (adapter) {
                        adapter.pairableTimeout = checked ? 120 : 0;
                        adapter.pairable = checked;
                    }
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.large
        text: qsTr("Adapter properties")
        font.pointSize: Appearance.font.size.larger
        font.weight: 500
    }

    StyledText {
        text: qsTr("Per-adapter settings")
        color: Signal.palette.inkMuted
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: adapterSettings.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.small
        color: Signal.tPalette.panel

        ColumnLayout {
            id: adapterSettings

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.larger

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Current adapter")
                }

                Item {
                    id: adapterPickerButton

                    property bool expanded

                    implicitWidth: adapterPicker.implicitWidth + Appearance.padding.normal * 2
                    implicitHeight: adapterPicker.implicitHeight + Appearance.padding.smaller * 2

                    Interactive {
                        radius: Appearance.rounding.small

                        function onClicked(): void {
                            adapterPickerButton.expanded = !adapterPickerButton.expanded;
                        }
                    }

                    RowLayout {
                        id: adapterPicker

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        anchors.topMargin: Appearance.padding.smaller
                        anchors.bottomMargin: Appearance.padding.smaller
                        spacing: Appearance.spacing.normal

                        StyledText {
                            Layout.leftMargin: Appearance.padding.small
                            text: root.session.bt.currentAdapter?.name ?? qsTr("None")
                        }

                        Glyph {
                            name: "chevron-down"
                        }
                    }

                    Elevation {
                        anchors.fill: adapterListBg
                        radius: adapterListBg.radius
                        opacity: adapterPickerButton.expanded ? 1 : 0
                        scale: adapterPickerButton.expanded ? 1 : 0.7
                        level: 2

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {
                                duration: Appearance.anim.durations.settleFast
                                easing.bezierCurve: Appearance.anim.curves.settleFast
                            }
                        }
                    }

                    StyledClippingRect {
                        id: adapterListBg

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: adapterPickerButton.expanded ? adapterList.implicitHeight : adapterPickerButton.implicitHeight

                        color: Signal.palette.signalWell
                        radius: Appearance.rounding.small
                        opacity: adapterPickerButton.expanded ? 1 : 0
                        scale: adapterPickerButton.expanded ? 1 : 0.7

                        ColumnLayout {
                            id: adapterList

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 0

                            Repeater {
                                model: Bluetooth.adapters

                                Item {
                                    id: adapter

                                    required property BluetoothAdapter modelData

                                    Layout.fillWidth: true
                                    implicitHeight: adapterInner.implicitHeight + Appearance.padding.normal * 2

                                    Interactive {
                                        disabled: !adapterPickerButton.expanded

                                        function onClicked(): void {
                                            adapterPickerButton.expanded = false;
                                            root.session.bt.currentAdapter = adapter.modelData;
                                        }
                                    }

                                    RowLayout {
                                        id: adapterInner

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: Appearance.padding.normal
                                        spacing: Appearance.spacing.normal

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: Appearance.padding.small
                                            text: adapter.modelData.name
                                            color: Signal.palette.onSignalWell
                                        }

                                        Glyph {
                                            name: "check"
                                            color: Signal.palette.onSignalWell
                                            visible: adapter.modelData === root.session.bt.currentAdapter
                                        }
                                    }
                                }
                            }
                        }

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {
                                duration: Appearance.anim.durations.settleFast
                                easing.bezierCurve: Appearance.anim.curves.settleFast
                            }
                        }

                        Behavior on implicitHeight {
                            Anim {
                                duration: Appearance.anim.durations.settle
                                easing.bezierCurve: Appearance.anim.curves.settle
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Discoverable timeout")
                }

                CustomSpinBox {
                    min: 0
                    value: root.session.bt.currentAdapter?.discoverableTimeout ?? 0
                    onValueModified: value => {
                        if (root.session.bt.currentAdapter) {
                            root.session.bt.currentAdapter.discoverableTimeout = value;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Item {
                    id: renameAdapter

                    Layout.fillWidth: true
                    Layout.rightMargin: Appearance.spacing.small

                    implicitHeight: renameLabel.implicitHeight + adapterNameEdit.implicitHeight

                    states: State {
                        name: "editingAdapterName"
                        when: root.session.bt.editingAdapterName

                        AnchorChanges {
                            target: adapterNameEdit
                            anchors.top: renameAdapter.top
                        }
                        PropertyChanges {
                            renameAdapter.implicitHeight: adapterNameEdit.implicitHeight
                            renameLabel.opacity: 0
                            adapterNameEdit.padding: Appearance.padding.normal
                        }
                    }

                    transitions: Transition {
                        AnchorAnimation {
                            duration: Appearance.anim.durations.medium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                        Anim {
                            properties: "implicitHeight,opacity,padding"
                        }
                    }

                    StyledText {
                        id: renameLabel

                        anchors.left: parent.left

                        text: qsTr("Rename adapter")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.small
                    }

                    StyledTextField {
                        id: adapterNameEdit

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: renameLabel.bottom
                        anchors.leftMargin: root.session.bt.editingAdapterName ? 0 : -Appearance.padding.normal

                        text: root.session.bt.currentAdapter?.name ?? ""
                        readOnly: !root.session.bt.editingAdapterName
                        onAccepted: {
                            const adapter = root.session.bt.currentAdapter;
                            if (!adapter) { root.session.bt.editingAdapterName = false; return; }
                            const newName = adapterNameEdit.text.trim();
                            if (newName && newName !== adapter.name)
                                Quickshell.execDetached(["busctl", "set-property", "org.bluez", adapter.dbusPath, "org.bluez.Adapter1", "Alias", "s", newName]);
                            root.session.bt.editingAdapterName = false;
                        }

                        leftPadding: Appearance.padding.normal
                        rightPadding: Appearance.padding.normal

                        background: StyledRect {
                            radius: Appearance.rounding.small
                            border.width: 2
                            border.color: Signal.palette.signal
                            opacity: root.session.bt.editingAdapterName ? 1 : 0

                            Behavior on border.color {
                                CAnim {}
                            }

                            Behavior on opacity {
                                Anim {}
                            }
                        }

                        Behavior on anchors.leftMargin {
                            Anim {}
                        }
                    }
                }

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: cancelEditIcon.implicitHeight + Appearance.padding.smaller * 2

                    radius: Appearance.rounding.small
                    color: Signal.palette.signalWell
                    opacity: root.session.bt.editingAdapterName ? 1 : 0
                    scale: root.session.bt.editingAdapterName ? 1 : 0.5

                    Interactive {
                        color: Signal.palette.onSignalWell
                        disabled: !root.session.bt.editingAdapterName

                        function onClicked(): void {
                            root.session.bt.editingAdapterName = false;
                            adapterNameEdit.text = Qt.binding(() => root.session.bt.currentAdapter?.name ?? "");
                        }
                    }

                    Glyph {
                        id: cancelEditIcon

                        anchors.centerIn: parent
                        animate: true
                        name: "cancel"
                        color: Signal.palette.onSignalWell
                    }

                    Behavior on opacity {
                        Anim {}
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.settleFast
                            easing.bezierCurve: Appearance.anim.curves.settleFast
                        }
                    }
                }

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: editIcon.implicitHeight + Appearance.padding.smaller * 2

                    radius: root.session.bt.editingAdapterName ? Appearance.rounding.small : implicitHeight / 2 * Math.min(1, Appearance.rounding.scale)
                    color: Qt.alpha(Signal.palette.signal, root.session.bt.editingAdapterName ? 1 : 0)

                    Interactive {
                        color: root.session.bt.editingAdapterName ? Signal.palette.onSignal : Signal.palette.ink

                        function onClicked(): void {
                            root.session.bt.editingAdapterName = !root.session.bt.editingAdapterName;
                            if (root.session.bt.editingAdapterName)
                                adapterNameEdit.forceActiveFocus();
                            else
                                adapterNameEdit.accepted();
                        }
                    }

                    Glyph {
                        id: editIcon

                        anchors.centerIn: parent
                        animate: true
                        name: root.session.bt.editingAdapterName ? "circle-check" : "edit"
                        color: root.session.bt.editingAdapterName ? Signal.palette.onSignal : Signal.palette.ink
                    }

                    Behavior on radius {
                        Anim {}
                    }
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.large
        text: qsTr("Adapter information")
        font.pointSize: Appearance.font.size.larger
        font.weight: 500
    }

    StyledText {
        text: qsTr("Information about the current adapter")
        color: Signal.palette.inkMuted
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: adapterInfo.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.small
        color: Signal.tPalette.panel

        ColumnLayout {
            id: adapterInfo

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.small / 2

            StyledText {
                text: qsTr("Adapter state")
            }

            StyledText {
                text: root.session.bt.currentAdapter ? BluetoothAdapterState.toString(root.session.bt.currentAdapter.state) : qsTr("Unknown")
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                text: qsTr("Dbus path")
            }

            StyledText {
                text: root.session.bt.currentAdapter?.dbusPath ?? ""
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                text: qsTr("Adapter id")
            }

            StyledText {
                text: root.session.bt.currentAdapter?.adapterId ?? ""
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle

            cLayer: 2
        }
    }
}

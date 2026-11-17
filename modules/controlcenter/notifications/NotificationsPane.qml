pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.large

                RowLayout {
                    spacing: Appearance.spacing.normal

                    PaneHeader {
                        paneId: "notifications"
                    }

                    StyledRect {
                        visible: Notifs.notClosed.length > 0
                        radius: Appearance.rounding.small
                        color: Signal.palette.signal
                        implicitWidth: Math.max(implicitHeight, badgeText.implicitWidth + Appearance.padding.smaller * 2)
                        implicitHeight: badgeText.implicitHeight + Appearance.padding.smaller

                        StyledText {
                            id: badgeText

                            anchors.centerIn: parent
                            text: Notifs.notClosed.length
                            color: Signal.palette.onSignal
                            font.pointSize: Appearance.font.size.smaller
                            font.weight: 600
                        }
                    }
                }

                // ── Do Not Disturb ───────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Do Not Disturb")

                    ColumnLayout {
                        id: dndCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Do not disturb")
                            checked: Notifs.dnd
                            onToggled: checked => {
                                Notifs.dnd = checked;
                            }
                        }
                    }
                }

                // ── Behavior ─────────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Behavior")

                    ColumnLayout {
                        id: behaviorCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Auto-expire notifications")
                            checked: Config.notifs.expire
                            onToggled: checked => {
                                Config.notifs.expire = checked;
                                Config.save();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Expire after")
                            value: Config.notifs.defaultExpireTimeout
                            from: 1000
                            to: 30000
                            stepSize: 500
                            suffix: "ms"
                            validator: IntValidator {
                                bottom: 1000
                                top: 30000
                            }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)
                            onValueModified: val => {
                                Config.notifs.defaultExpireTimeout = Math.round(val);
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Open on click")
                            checked: Config.notifs.actionOnClick
                            onToggled: checked => {
                                Config.notifs.actionOnClick = checked;
                                Config.save();
                            }
                        }
                    }
                }

                // ── Lock screen ────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Lock screen")

                    ColumnLayout {
                        id: lockCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Hide notifications on lock screen")
                            checked: Config.lock.hideNotifs
                            onToggled: checked => {
                                Config.lock.hideNotifs = checked;
                                Config.save();
                            }
                        }
                    }
                }

                // ── Toast events ─────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Toast events")

                    ColumnLayout {
                        id: toastsCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Charging changed")
                            checked: Config.utilities.toasts.chargingChanged
                            onToggled: checked => {
                                Config.utilities.toasts.chargingChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Audio output changed")
                            checked: Config.utilities.toasts.audioOutputChanged
                            onToggled: checked => {
                                Config.utilities.toasts.audioOutputChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Audio input changed")
                            checked: Config.utilities.toasts.audioInputChanged
                            onToggled: checked => {
                                Config.utilities.toasts.audioInputChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Keyboard layout changed")
                            checked: Config.utilities.toasts.kbLayoutChanged
                            onToggled: checked => {
                                Config.utilities.toasts.kbLayoutChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Caps Lock changed")
                            checked: Config.utilities.toasts.capsLockChanged
                            onToggled: checked => {
                                Config.utilities.toasts.capsLockChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Num Lock changed")
                            checked: Config.utilities.toasts.numLockChanged
                            onToggled: checked => {
                                Config.utilities.toasts.numLockChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("VPN changed")
                            checked: Config.utilities.toasts.vpnChanged
                            onToggled: checked => {
                                Config.utilities.toasts.vpnChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Experience mode changed")
                            checked: Config.experience.toasts
                            onToggled: checked => {
                                Config.experience.toasts = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Do not disturb changed")
                            checked: Config.utilities.toasts.dndChanged
                            onToggled: checked => {
                                Config.utilities.toasts.dndChanged = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Now playing")
                            checked: Config.utilities.toasts.nowPlaying
                            onToggled: checked => {
                                Config.utilities.toasts.nowPlaying = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Config loaded")
                            checked: Config.utilities.toasts.configLoaded
                            onToggled: checked => {
                                Config.utilities.toasts.configLoaded = checked;
                                Config.save();
                            }
                        }
                    }
                }

                // ── Recent notifications ──────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Recent notifications")

                    ColumnLayout {
                        id: historyCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Recent")
                                font.pointSize: Appearance.font.size.normal
                                font.weight: 500
                            }

                            TextButton {
                                visible: Notifs.notClosed.length > 0
                                text: qsTr("Clear all")
                                type: TextButton.Tonal
                                onClicked: {
                                    for (const n of Notifs.notClosed)
                                        n.closed = true;
                                }
                            }
                        }

                        StyledText {
                            visible: Notifs.notClosed.length === 0
                            text: qsTr("No pending notifications")
                            color: Signal.palette.inkMuted
                            font.pointSize: Appearance.font.size.small
                        }

                        Repeater {
                            model: Notifs.notClosed.slice(0, 5)

                            StyledRect {
                                id: notifCard

                                required property var modelData

                                Layout.fillWidth: true
                                radius: Appearance.rounding.small
                                color: Signal.layer(Signal.palette.raised, 1)
                                implicitHeight: notifRow.implicitHeight + Appearance.padding.normal * 2

                                RowLayout {
                                    id: notifRow

                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.normal
                                    spacing: Appearance.spacing.normal

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: notifCard.modelData.summary || notifCard.modelData.appName || ""
                                            font.pointSize: Appearance.font.size.small
                                            font.weight: 600
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            visible: text !== ""
                                            Layout.fillWidth: true
                                            text: notifCard.modelData.body || ""
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    TextButton {
                                        text: qsTr("Dismiss")
                                        onClicked: notifCard.modelData.closed = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}

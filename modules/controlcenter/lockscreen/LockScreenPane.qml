pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Lock screen: every Config.lock knob in one place
// (logo recolour, notification privacy, fingerprint unlock), bound
// directly to the shell config the lock surface actually reads.
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
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Lock screen")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("How HorneroOS looks and behaves while locked. Changes apply to the next lock.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: lockCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: lockCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Privacy & unlock")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SwitchRow {
                            label: qsTr("Hide notifications while locked")
                            checked: Config.lock.hideNotifs
                            onToggled: checked => {
                                Config.lock.hideNotifs = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Recolour the logo to the theme")
                            checked: Config.lock.recolourLogo
                            onToggled: checked => {
                                Config.lock.recolourLogo = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Fingerprint unlock")
                            checked: Config.lock.enableFprint
                            onToggled: checked => {
                                Config.lock.enableFprint = checked;
                                Config.save();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Fingerprint attempts")
                            value: Config.lock.maxFprintTries
                            from: 1
                            to: 10
                            stepSize: 1
                            validator: IntValidator {
                                bottom: 1
                                top: 10
                            }
                            formatValueFunction: val => `${Math.round(val)}`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => {
                                Config.lock.maxFprintTries = Math.round(newValue);
                                Config.save();
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: idleCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: idleCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Idle & locking")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SwitchRow {
                            label: qsTr("Lock before sleep")
                            checked: Config.general.idle.lockBeforeSleep
                            onToggled: checked => {
                                Config.general.idle.lockBeforeSleep = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Stay awake while audio plays")
                            checked: Config.general.idle.inhibitWhenAudio
                            onToggled: checked => {
                                Config.general.idle.inhibitWhenAudio = checked;
                                Config.save();
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Idle timeouts and battery warnings live in Control Center › Power.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
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

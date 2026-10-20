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

// Control Center › Session: the session menu behavior the shell
// actually honors (Config.session), in one place.
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
                    text: qsTr("Session")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("The power/session menu and how it responds to keyboard and drag.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: sessionCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: sessionCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Session menu")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SwitchRow {
                            label: qsTr("Session menu enabled")
                            checked: Config.session.enabled
                            onToggled: checked => {
                                Config.session.enabled = checked;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Vim keybinds in menus")
                            checked: Config.session.vimKeybinds
                            onToggled: checked => {
                                Config.session.vimKeybinds = checked;
                                Config.save();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Drag threshold")
                            value: Config.session.dragThreshold
                            from: 5
                            to: 100
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 5
                                top: 100
                            }
                            formatValueFunction: val => `${Math.round(val)} px`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => {
                                Config.session.dragThreshold = Math.round(newValue);
                                Config.save();
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

pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Windows (shell#235, first slice): window geometry
// — gaps, border size, corner rounding — through
// `horneroctl hypr windows` (its own bounded, confirmed writer;
// subset sets keep the untouched values). Focus behaviour and
// float/pin rules stay tracked in #235 — this pane never hand-edits
// compositor config, and Niri geometry is not faked here.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property int gapsIn: 5
    property int gapsOut: 20
    property int borderSize: 2
    property int rounding: 10
    property string statusText: qsTr("Reading window geometry…")
    property string actionText: ""

    function refresh(): void {
        statusProc.out = "";
        statusProc.command = ["horneroctl", "hypr", "windows", "status", "--json"];
        statusProc.running = true;
    }

    function apply(flag: string, value: int): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "hypr", "windows", "set", flag, value.toString(), "--yes", "--json"];
        setProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: statusProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                statusProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(statusProc.out.trim());
                const d = payload.data ?? {};
                root.gapsIn = parseInt(d.gaps_in ?? "5");
                root.gapsOut = parseInt(d.gaps_out ?? "20");
                root.borderSize = parseInt(d.border_size ?? "2");
                root.rounding = parseInt(d.rounding ?? "10");
                root.statusText = payload.ok ? qsTr("Live from Hyprland via horneroctl") : payload.message.toString();
            } catch (e) {
                root.statusText = qsTr("horneroctl windows unavailable on this system.");
            }
        }
    }

    Process {
        id: setProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                setProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(setProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.actionText = qsTr("The windows command did not answer. Check: horneroctl hypr windows status");
            }
            root.refresh();
        }
    }

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
                    text: qsTr("Windows")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: geoCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: geoCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.normal

                        StyledText {
                            text: qsTr("Geometry (Hyprland)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Inner gaps")
                            value: root.gapsIn
                            from: 0
                            to: 100
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }
                            onValueModified: newValue => root.apply("--gaps-in", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Outer gaps")
                            value: root.gapsOut
                            from: 0
                            to: 200
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 200
                            }
                            onValueModified: newValue => root.apply("--gaps-out", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Border size")
                            value: root.borderSize
                            from: 0
                            to: 20
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 20
                            }
                            onValueModified: newValue => root.apply("--border-size", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Corner rounding")
                            value: root.rounding
                            from: 0
                            to: 60
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 60
                            }
                            onValueModified: newValue => root.apply("--rounding", Math.round(newValue))
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Restore saved")
                                type: TextButton.Tonal
                                onClicked: {
                                    root.actionText = qsTr("Restoring…");
                                    setProc.out = "";
                                    setProc.command = ["horneroctl", "hypr", "windows", "restore", "--yes", "--json"];
                                    setProc.running = true;
                                }
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionText !== ""
                            text: root.actionText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Focus behaviour and floating/pin rules arrive in later slices of #235. Changes persist via horneroctl and are re-applied with Restore after a restart until session restore lands.")
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

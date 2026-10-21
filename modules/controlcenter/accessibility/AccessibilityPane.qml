pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.modules.companion
import qs.config
import qs.services
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Accessibility (shell#221): the shell-wide knobs
// that already exist — text size, motion, transparency — plus the
// cursor size through `horneroctl hypr cursor`, grouped where
// people look for them. Every control binds a real mechanism;
// nothing here is decorative.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property int cursorSize: 24
    property string cursorText: qsTr("Reading cursor…")
    property string cursorAction: ""

    function refreshCursor(): void {
        cursorProc.out = "";
        cursorProc.command = ["horneroctl", "hypr", "cursor", "status", "--json"];
        cursorProc.running = true;
    }

    Component.onCompleted: root.refreshCursor()

    Process {
        id: cursorProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                cursorProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(cursorProc.out.trim());
                const d = payload.data ?? {};
                root.cursorSize = parseInt(d.size ?? "24") || 24;
                root.cursorText = qsTr("Cursor theme %1 · size %2 (from %3)").arg(d.theme ?? "default").arg(d.size ?? "24").arg(d.size_source ?? "default");
            } catch (e) {
                root.cursorText = qsTr("horneroctl cursor unavailable on this system.");
            }
        }
    }

    Process {
        id: cursorSetProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                cursorSetProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(cursorSetProc.out.trim());
                root.cursorAction = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.cursorAction = "";
            }
            root.refreshCursor();
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
                    text: qsTr("Accessibility")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Make HorneroOS easier to see and calmer to use. Changes apply instantly.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: visionCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: visionCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Vision")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Text size")
                            value: Config.appearance.font.size.scale
                            from: 0.8
                            to: 1.5
                            stepSize: 0.05
                            suffix: "×"
                            decimals: 2
                            onValueModified: newValue => {
                                Config.appearance.font.size.scale = newValue;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Transparency effects")
                            checked: Config.appearance.transparency.enabled
                            onToggled: checked => {
                                Config.appearance.transparency.enabled = checked;
                                Config.save();
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: motionCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: motionCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Motion")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Animation speed")
                            value: Config.appearance.anim.durations.scale
                            from: 0
                            to: 2
                            stepSize: 0.1
                            suffix: "×"
                            decimals: 1
                            formatValueFunction: val => val === 0 ? qsTr("off") : `${val.toFixed(1)}×`
                            parseValueFunction: text => parseFloat(text)
                            onValueModified: newValue => {
                                Config.appearance.anim.durations.scale = newValue;
                                Config.save();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Calm Javi (reduced motion)")
                            checked: CompanionStore.reducedMotion
                            onToggled: checked => CompanionStore.reducedMotion = checked
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Javi's chat also honors reduced motion: no pulse or scanline shimmer while it is on.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: cursorCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: cursorCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Cursor")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.cursorText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Cursor size")
                            value: root.cursorSize
                            from: 16
                            to: 64
                            stepSize: 2
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 16
                                top: 64
                            }
                            onValueModified: newValue => {
                                root.cursorAction = qsTr("Applying…");
                                cursorSetProc.out = "";
                                cursorSetProc.command = ["horneroctl", "hypr", "cursor", "set", "--size", Math.round(newValue).toString(), "--yes", "--json"];
                                cursorSetProc.running = true;
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.cursorAction !== ""
                            text: root.cursorAction
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Applies to the Hyprland cursor immediately and is restored at login; other apps pick up the size when they start.")
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

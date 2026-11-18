pragma ComponentBehavior: Bound

import qs.config
import QtQuick
import QtQuick.Layouts

// A mini desktop rendered live from a CANDIDATE palette (RFC 0002 §13.3):
// bar, popout with a card and buttons, launcher row, notification,
// terminal ANSI strip and a telemetry trace. It reads only `palette`
// (role -> #RRGGBB, with term0..term15) and never touches Signal, so what
// it shows is exactly what the candidate would look like, not the current
// theme.
Item {
    id: root

    // Flat role map: {ground: "#..", ..., term0: "#.."}.
    property var palette: ({})
    property bool light: false
    // Wallpaper behind the desktop; empty draws the ground colour.
    property string wallpaper: ""
    property var minSurfaceAlpha: ({})

    implicitWidth: 560
    implicitHeight: 330

    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Preview of the candidate palette on a sample desktop: bar, popout, launcher, notification, terminal colours and a telemetry trace")

    function c(role: string): color {
        const v = root.palette[role];
        return v ? v : "#808080";
    }

    function surface(role: string): color {
        const a = root.minSurfaceAlpha[role];
        return Qt.alpha(root.c(role), typeof a === "number" ? Math.max(0.88, a) : 1);
    }

    readonly property string monoFamily: Appearance.font.family.mono
    readonly property string sansFamily: Appearance.font.family.sans

    Rectangle {
        id: desk

        anchors.fill: parent
        color: root.c("ground")
        border.width: 1
        border.color: root.c("rule")
        radius: Appearance.rounding.small
        clip: true

        Image {
            anchors.fill: parent
            source: root.wallpaper ? ("file://" + root.wallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 640
            visible: status === Image.Ready
        }

        // Bar
        Rectangle {
            id: bar

            x: 8
            y: 8
            width: parent.width - 16
            height: 26
            color: root.surface("base")
            border.width: 1
            border.color: root.c("rule")
            radius: Appearance.rounding.small

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        width: index === 1 ? 22 : 14
                        height: 14
                        radius: 2
                        color: index === 1 ? root.c("signalWell") : "transparent"
                        border.width: 1
                        border.color: index === 1 ? root.c("signal") : root.c("rule")

                        Text {
                            anchors.centerIn: parent
                            text: parent.index + 1
                            font.family: root.monoFamily
                            font.pixelSize: 9
                            color: parent.index === 1 ? root.c("onSignalWell") : root.c("inkMuted")
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "14:32"
                font.family: root.monoFamily
                font.pixelSize: 12
                color: root.c("ink")
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [{"r": "phosphor", "t": "NET"}, {"r": "cue", "t": "CPU 23"}, {"r": "alert", "t": "BAT 9%"}]

                    Text {
                        required property var modelData

                        text: modelData.t
                        font.family: root.monoFamily
                        font.pixelSize: 9
                        color: root.c(modelData.r)
                    }
                }
            }
        }

        // Popout with a card
        Rectangle {
            id: popout

            x: parent.width - width - 12
            y: bar.y + bar.height + 8
            width: 210
            height: 150
            color: root.surface("panel")
            border.width: 1
            border.color: root.c("ruleStrong")
            radius: Appearance.rounding.small

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    text: "AUDIO OUTPUT"
                    font.family: root.monoFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.c("inkMuted")
                }

                Rectangle {
                    width: parent.width
                    height: 54
                    color: root.c("raised")
                    border.width: 1
                    border.color: root.c("rule")
                    radius: 2

                    Text {
                        x: 8
                        y: 6
                        text: qsTr("Studio speakers")
                        font.family: root.sansFamily
                        font.pixelSize: 12
                        color: root.c("ink")
                    }

                    Text {
                        x: 8
                        y: 22
                        text: qsTr("Connected · 48 kHz")
                        font.family: root.sansFamily
                        font.pixelSize: 10
                        color: root.c("inkMuted")
                    }

                    Rectangle {
                        x: 8
                        y: 40
                        width: parent.width - 16
                        height: 5
                        color: root.c("sunken")
                        border.width: 1
                        border.color: root.c("rule")

                        Rectangle {
                            width: parent.width * 0.62
                            height: parent.height
                            color: root.c("signal")
                        }
                    }
                }

                Row {
                    spacing: 6

                    Rectangle {
                        width: 74
                        height: 24
                        radius: 2
                        color: root.c("signal")

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Play")
                            font.family: root.sansFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.c("onSignal")
                        }
                    }

                    Rectangle {
                        width: 66
                        height: 24
                        radius: 2
                        color: root.c("cueWell")

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Mixer")
                            font.family: root.sansFamily
                            font.pixelSize: 11
                            color: root.c("onCueWell")
                        }
                    }

                    Rectangle {
                        width: 38
                        height: 24
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.c("focus")

                        Text {
                            anchors.centerIn: parent
                            text: "⌘"
                            font.pixelSize: 11
                            color: root.c("focus")
                        }
                    }
                }

                Row {
                    spacing: 6

                    Repeater {
                        model: [{"w": "phosphorWell", "o": "onPhosphorWell", "t": "OK"}, {"w": "signalWell", "o": "onSignalWell", "t": "BUSY"}, {"w": "alertWell", "o": "onAlertWell", "t": "FAIL"}]

                        Rectangle {
                            required property var modelData

                            width: 44
                            height: 16
                            radius: 2
                            color: root.c(modelData.w)

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.t
                                font.family: root.monoFamily
                                font.pixelSize: 9
                                color: root.c(parent.modelData.o)
                            }
                        }
                    }
                }
            }
        }

        // Launcher
        Rectangle {
            id: launcher

            x: 12
            y: bar.y + bar.height + 8
            width: 230
            height: 108
            color: root.surface("panel")
            border.width: 1
            border.color: root.c("ruleStrong")
            radius: Appearance.rounding.small

            Rectangle {
                x: 8
                y: 8
                width: parent.width - 16
                height: 22
                color: root.c("sunken")
                border.width: 1
                border.color: root.c("focus")

                Text {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "fire|"
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    color: root.c("ink")
                }
            }

            Column {
                x: 8
                y: 36
                width: parent.width - 16
                spacing: 2

                Repeater {
                    model: [{"t": "Firefox", "s": "Web browser", "sel": true}, {"t": "Files", "s": "File manager", "sel": false}, {"t": "Fish shell", "s": "Terminal", "sel": false}]

                    Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 20
                        color: modelData.sel ? root.c("signalWell") : "transparent"
                        radius: 2

                        Text {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.t
                            font.family: root.sansFamily
                            font.pixelSize: 11
                            color: parent.modelData.sel ? root.c("onSignalWell") : root.c("ink")
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.s
                            font.family: root.sansFamily
                            font.pixelSize: 9
                            color: parent.modelData.sel ? root.c("onSignalWell") : root.c("inkMuted")
                        }
                    }
                }
            }
        }

        // Notification
        Rectangle {
            x: 12
            y: launcher.y + launcher.height + 8
            width: 230
            height: 44
            color: root.surface("panel")
            border.width: 1
            border.color: root.c("ruleStrong")
            radius: Appearance.rounding.small

            Rectangle {
                x: 8
                y: 10
                width: 24
                height: 24
                radius: 2
                color: root.c("alertWell")

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    font.family: root.monoFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: root.c("onAlertWell")
                }
            }

            Text {
                x: 40
                y: 8
                text: qsTr("Sign-in failed")
                font.family: root.sansFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.c("ink")
            }

            Text {
                x: 40
                y: 24
                width: parent.width - 48
                text: qsTr("The server rejected the saved password.")
                elide: Text.ElideRight
                font.family: root.sansFamily
                font.pixelSize: 10
                color: root.c("inkMuted")
            }
        }

        // Terminal + telemetry
        Rectangle {
            id: term

            x: popout.x
            y: popout.y + popout.height + 8
            width: popout.width
            height: parent.height - y - 8
            color: root.c("base")
            border.width: 1
            border.color: root.c("rule")
            radius: 2

            Text {
                x: 6
                y: 4
                textFormat: Text.RichText
                text: "<font color='" + root.c("term2") + "'>user</font><font color='" + root.c("ink") + "'>@hornero </font><font color='" + root.c("term4") + "'>~ </font><font color='" + root.c("term3") + "'>$</font><font color='" + root.c("ink") + "'> ls</font>"
                font.family: root.monoFamily
                font.pixelSize: 10
            }

            Row {
                x: 6
                y: 20
                spacing: 1

                Repeater {
                    model: 16

                    Rectangle {
                        required property int index

                        width: 11
                        height: 10
                        color: root.c("term" + index)
                    }
                }
            }

            // Telemetry trace in a sunken well
            Rectangle {
                x: 6
                y: 36
                width: parent.width - 12
                height: parent.height - 40
                color: root.c("sunken")
                border.width: 1
                border.color: root.c("rule")

                Canvas {
                    anchors.fill: parent
                    anchors.margins: 2
                    property color trace: root.c("phosphor")
                    onTraceChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = String(trace);
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        for (let i = 0; i <= 40; i++) {
                            const x = width * i / 40;
                            const y = height * (0.5 - 0.32 * Math.sin(i / 3.1) * Math.cos(i / 7.3));
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }
            }
        }
    }
}

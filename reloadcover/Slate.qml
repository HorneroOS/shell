pragma ComponentBehavior: Bound

import QtQuick
import "cover.js" as Cover

// One screen of the reload cover: a broadcast stand-by slate in Hornero
// Signal (signal-visual-language §2.3 Transmisión, §6, §7.1). Pure QtQuick
// so it loads even when the main shell config is broken, and so the
// offscreen harness can render it without a compositor.
//
// The primary screen carries the full card; other screens get a quiet
// plate. Motion budget: one sweep animation on the primary screen (none
// when motion is reduced) plus the parent's 1 s clock.
Item {
    id: root

    // Resolved by Cover.resolve(): {palette, light, highContrast, mascot, fonts}.
    property var cover: Cover.resolve("", "")
    property string lang: "en"
    property bool primary: true
    property bool motion: true
    property int elapsed: 0
    property string screenName: ""
    // Javi frames live inside this directory (CMake installs them to
    // reloadcover/assets/): Quickshell blackholes files outside the config
    // root, and the cover's root is this directory, so ../assets is unreachable.
    property url spriteBase: Qt.resolvedUrl("assets/companion/frames/default-sleep-0")

    readonly property var p: cover.palette
    readonly property real u: Math.max(0.75, Math.min(1.6, Math.min(width / 1920, height / 1080)))
    readonly property bool slow: elapsed >= 15
    // Introspection for the offscreen harness.
    readonly property bool javiShown: javi.visible
    readonly property bool sweeping: sweep.running

    function t(key: string): string {
        return Cover.text(root.lang, key);
    }

    Rectangle {
        anchors.fill: parent
        color: root.p.ground
    }

    // Title-safe corner marks, like a broadcast monitor's safe-area guide.
    Repeater {
        model: 4

        Item {
            id: corner

            required property int index
            readonly property real inset: Math.round(Math.min(root.width, root.height) * 0.05)
            readonly property real len: Math.round(28 * root.u)

            x: (index % 2 === 0) ? inset : root.width - inset - len
            y: (index < 2) ? inset : root.height - inset - len
            width: len
            height: len

            Rectangle {
                y: corner.index < 2 ? 0 : parent.height - 1
                width: parent.width
                height: 1
                color: root.p.ruleStrong
            }
            Rectangle {
                x: corner.index % 2 === 0 ? 0 : parent.width - 1
                width: 1
                height: parent.height
                color: root.p.ruleStrong
            }
        }
    }

    // Output label, bottom-left inside the safe area.
    Text {
        x: Math.round(Math.min(root.width, root.height) * 0.05)
        y: root.height - Math.round(Math.min(root.width, root.height) * 0.05) - height - Math.round(36 * root.u)
        visible: root.screenName.length > 0
        text: "OUT · " + root.screenName.toUpperCase()
        color: root.p.inkMuted
        font.family: root.cover.mono
        font.pixelSize: Math.round(11 * root.u)
        font.letterSpacing: 1.5
    }

    // ---- quiet plate (secondary screens) ----
    Column {
        anchors.centerIn: parent
        visible: !root.primary
        spacing: Math.round(14 * root.u)

        HorneroMark {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.round(36 * root.u)
            color: root.p.signal
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(160 * root.u)
            height: 1
            color: root.p.rule
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.t("quiet")
            color: root.p.inkMuted
            font.family: root.cover.mono
            font.pixelSize: Math.round(12 * root.u)
            font.letterSpacing: 3
        }
    }

    // ---- stand-by slate (primary screen) ----
    Rectangle {
        id: card

        visible: root.primary
        anchors.centerIn: parent
        width: Math.round(640 * root.u)
        height: body.implicitHeight + 2 * pad
        radius: 8
        color: root.p.panel
        border.width: 1
        border.color: root.p.rule
        clip: false

        readonly property real pad: Math.round(28 * root.u)

        // Registration tick on the leading top corner (§7.1).
        Rectangle {
            x: card.pad
            y: -1
            width: 2
            height: Math.round(10 * root.u)
            color: root.p.signal
        }

        Column {
            id: body

            x: card.pad
            y: card.pad
            width: card.width - 2 * card.pad
            spacing: Math.round(18 * root.u)

            // Header: channel eyebrow and the tally chip.
            Item {
                width: parent.width
                height: chip.height

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.t("channel")
                    color: root.p.inkMuted
                    font.family: root.cover.mono
                    font.pixelSize: Math.round(11 * root.u)
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    id: chip

                    anchors.right: parent.right
                    width: chipRow.implicitWidth + Math.round(16 * root.u)
                    height: Math.round(22 * root.u)
                    radius: 3
                    color: root.p.signalWell

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Math.round(7 * root.u)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(7 * root.u)
                            height: width
                            radius: width / 2
                            color: root.p.signal
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.t("tally")
                            color: root.p.onSignalWell
                            font.family: root.cover.mono
                            font.pixelSize: Math.round(11 * root.u)
                            font.weight: Font.Medium
                            font.letterSpacing: 1.5
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.p.rule
            }

            // Mark + title block.
            Row {
                spacing: Math.round(22 * root.u)

                HorneroMark {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Math.round(76 * root.u)
                    color: root.p.signal
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * root.u)

                    Text {
                        text: root.t("title")
                        color: root.p.ink
                        font.family: root.cover.display
                        font.pixelSize: Math.round(68 * root.u)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 4
                    }
                    Text {
                        text: root.t("aside") + "  ·  HORNERO SIGNAL"
                        color: root.p.inkMuted
                        font.family: root.cover.mono
                        font.pixelSize: Math.round(12 * root.u)
                        font.letterSpacing: 3
                    }
                }
            }

            // Scanning well: a tuning dial with a slow sweeping needle.
            Rectangle {
                id: well

                width: parent.width
                height: Math.round(30 * root.u)
                radius: 3
                color: root.p.sunken
                border.width: 1
                border.color: root.p.rule
                clip: true

                readonly property real step: Math.round(12 * root.u)

                Repeater {
                    model: Math.max(0, Math.floor((well.width - 2) / well.step))

                    Rectangle {
                        required property int index

                        x: 1 + Math.round(well.step / 2) + index * well.step
                        y: well.height - 1 - height
                        width: 1
                        height: index % 5 === 0 ? Math.round(10 * root.u) : Math.round(5 * root.u)
                        color: index % 5 === 0 ? root.p.ruleStrong : root.p.inkFaint
                        opacity: index % 5 === 0 ? 1 : 0.6
                    }
                }

                Item {
                    id: needle

                    readonly property real travel: well.width - width - 2
                    property real pos: 0.62

                    x: 1 + pos * travel
                    width: Math.round(9 * root.u)
                    height: well.height

                    // Index triangle and hairline needle.
                    Canvas {
                        id: tri

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 1
                        width: parent.width
                        height: Math.round(6 * root.u)

                        property color fill: root.p.signal

                        onFillChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = fill;
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.lineTo(width, 0);
                            ctx.lineTo(width / 2, height);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tri.height
                        width: 2
                        height: parent.height - tri.height - 1
                        color: root.p.signal
                    }

                    SequentialAnimation on pos {
                        id: sweep

                        running: root.primary && root.motion && root.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0
                            to: 1
                            duration: 2800
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 1
                            to: 0
                            duration: 2800
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // Honest status line; turns into a hint after 15 s.
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.slow ? root.t("slow") : root.t("status")
                color: root.slow ? root.p.alert : root.p.inkMuted
                font.family: root.cover.sans
                font.pixelSize: Math.round(16 * root.u)
            }

            // Footer readouts.
            Item {
                width: parent.width
                height: cmd.height

                Text {
                    id: cmd

                    text: "horneroctl shell restart"
                    color: root.p.inkMuted
                    font.family: root.cover.mono
                    font.pixelSize: Math.round(11 * root.u)
                }
                Text {
                    anchors.right: parent.right
                    text: Cover.timecode(root.elapsed)
                    color: root.p.ink
                    font.family: root.cover.mono
                    font.pixelSize: Math.round(11 * root.u)
                    font.letterSpacing: 1
                    font.features: {
                        "tnum": 1
                    }
                }
            }

            // Test-card bars, drawn from the palette roles so the strip
            // follows every theme.
            Row {
                id: bars

                width: parent.width
                height: Math.round(5 * root.u)

                readonly property var roles: ["ink", "signal", "cue", "phosphor", "alert", "inkMuted", "ruleStrong"]
                readonly property real cell: Math.floor(width / roles.length)

                Repeater {
                    model: bars.roles

                    Rectangle {
                        required property string modelData
                        required property int index

                        width: index === bars.roles.length - 1 ? bars.width - index * bars.cell : bars.cell
                        height: bars.height
                        color: root.p[modelData]
                    }
                }
            }
        }

        // Javi, dozing on the slate. Optional: hidden when the mascot is
        // off or the art is not installed next to the cover.
        Image {
            id: javi

            readonly property int frame: root.motion ? (root.elapsed % 4) + 1 : 1

            visible: root.cover.mascot && status === Image.Ready
            source: root.cover.mascot ? root.spriteBase + frame + ".png" : ""
            width: Math.round(124 * root.u)
            height: width
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: false
            cache: true
            // Feet on the card's top edge (the art has ~10 % bottom margin).
            x: card.width - width - Math.round(20 * root.u)
            y: -height + Math.round(height * 0.1) + 1
            Accessible.ignored: true
        }

        // Two drowsy letters drifting up from Javi.
        Text {
            visible: javi.visible
            x: javi.x - Math.round(2 * root.u)
            y: javi.y + Math.round(18 * root.u)
            text: "z"
            color: root.p.inkFaint
            font.family: root.cover.sans
            font.pixelSize: Math.round(13 * root.u)
            font.weight: Font.DemiBold
            Accessible.ignored: true
        }
        Text {
            visible: javi.visible
            x: javi.x - Math.round(16 * root.u)
            y: javi.y - Math.round(2 * root.u)
            text: "Z"
            color: root.p.inkMuted
            font.family: root.cover.sans
            font.pixelSize: Math.round(19 * root.u)
            font.weight: Font.DemiBold
            Accessible.ignored: true
        }
    }
}

pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.images
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import Quickshell
import QtQuick
import QtQuick.Layouts

// Lock centre column: the clock, then the sign-in module. Calm by design:
// one clip-reveal of the clock on show (`sweep`, `scan`), then nothing
// moves. Plex Sans Condensed numerals, date in Plex Mono, a single
// `signal` hairline as the only accent. Glow (amendment 2) is limited to
// that hairline in the Signal experience.
ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    // The sign-in module is the interactive centre of the screen: at least
    // 520 px of column (a 468 px module) even on a 1080p display.
    readonly property int centerWidth: Math.max(520, Config.lock.sizes.centerWidth * centerScale)
    readonly property real clockSize: Appearance.font.size.display * 2.4 * centerScale
    readonly property string userName: Quickshell.env("USER") ?? ""

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Appearance.spacing.large

    Item {
        Layout.fillHeight: true
    }

    // Clock, revealed once by a clip wipe from the left. The outer item
    // keeps the final size so the numerals never move; only the clip opens.
    Item {
        id: clockBox

        property real reveal: 0

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: clockRow.implicitWidth
        implicitHeight: clockRow.implicitHeight

        Component.onCompleted: revealAnim.start()

        Anim {
            id: revealAnim

            target: clockBox
            property: "reveal"
            from: 0
            to: 1
            duration: Appearance.anim.durations.scan
            easing.bezierCurve: Appearance.anim.curves.sweep
        }

        Item {
            width: clockBox.width * clockBox.reveal
            height: clockBox.height
            clip: true

            Row {
                id: clockRow

                spacing: 4

                StyledText {
                    text: Time.hourStr
                    font.family: Appearance.font.family.display
                    font.weight: Font.Medium
                    font.pointSize: root.clockSize
                    font.letterSpacing: -root.clockSize * 0.015
                    font.features: {
                        "tnum": 1
                    }
                }

                StyledText {
                    text: ":"
                    color: Signal.palette.inkMuted
                    font.family: Appearance.font.family.display
                    font.weight: Font.Medium
                    font.pointSize: root.clockSize
                    font.letterSpacing: -root.clockSize * 0.015
                }

                StyledText {
                    text: Time.minuteStr
                    font.family: Appearance.font.family.display
                    font.weight: Font.Medium
                    font.pointSize: root.clockSize
                    font.letterSpacing: -root.clockSize * 0.015
                    font.features: {
                        "tnum": 1
                    }
                }

                StyledText {
                    anchors.baseline: parent.children[0].baseline
                    visible: Config.services.useTwelveHourClock
                    leftPadding: Appearance.spacing.small
                    mono: true
                    text: Time.amPmStr
                    color: Signal.palette.inkMuted
                    font.pointSize: Math.floor(root.clockSize / 4)
                }
            }
        }
    }

    // The one accent: a short `signal` hairline between clock and date.
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 48
        implicitHeight: 2

        OnAirBar {
            glow: true
            edge: "bottom"
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        mono: true
        text: Time.format("dddd d MMMM yyyy")
        color: Signal.palette.inkMuted
        font.pointSize: Math.max(Appearance.font.size.normal, Math.floor(Appearance.font.size.larger * root.centerScale))
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Appearance.font.size.larger * 0.08
    }

    // Welcome line in the active microcopy voice, hornero beside it.
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.spacing.small
        spacing: Appearance.spacing.smaller

        HorneroSprite {
            pixel: 2
        }

        StyledText {
            text: Microcopy.line("lock.welcome")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
        }
    }

    // Sign-in module.
    Instruments.Frame {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.spacing.large * 2
        Layout.preferredWidth: root.centerWidth * 0.9
        implicitHeight: headerHeight + signIn.implicitHeight + 16
        channel: "01"
        title: qsTr("Locked")
        context: root.userName
        active: true

        ColumnLayout {
            id: signIn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: Appearance.rounding.small
                    color: Signal.palette.sunken
                    border.width: 1
                    border.color: Signal.palette.rule
                    clip: true

                    Glyph {
                        anchors.centerIn: parent

                        name: "user"
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.large
                    }

                    CachingImage {
                        anchors.fill: parent
                        anchors.margins: 1

                        path: `${Paths.home}/.face`
                    }
                }

                // Entry well. Focus stays here: key presses go to PAM.
                Instruments.Well {
                    id: entry

                    Layout.fillWidth: true
                    implicitHeight: 52

                    focus: true
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            forceActiveFocus();
                    }

                    border.color: activeFocus ? Signal.palette.focus : Signal.palette.rule
                    border.width: activeFocus ? 2 : 1

                    Keys.onPressed: event => {
                        if (root.lock.unlocking)
                            return;

                        root.lock.pam.handleKey(event);
                    }

                    StateLayer {
                        hoverEnabled: false
                        cursorShape: Qt.IBeamCursor

                        function onClicked(): void {
                            entry.forceActiveFocus();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: Appearance.spacing.small

                        Item {
                            implicitWidth: 32
                            implicitHeight: 32

                            Glyph {
                                anchors.centerIn: parent

                                name: {
                                    if (root.lock.pam.fprint.tries >= Config.lock.maxFprintTries)
                                        return "fingerprint-off";
                                    if (root.lock.pam.fprint.active)
                                        return "fingerprint";
                                    return "lock";
                                }
                                color: root.lock.pam.fprint.tries >= Config.lock.maxFprintTries ? Signal.palette.alert : Signal.palette.inkMuted
                            }
                        }

                        InputField {
                            id: inputField

                            pam: root.lock.pam
                        }

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32

                            radius: Appearance.rounding.small
                            color: root.lock.pam.buffer ? Signal.palette.signal : Signal.palette.lifted
                            border.width: 1
                            border.color: root.lock.pam.buffer ? Signal.palette.signal : Signal.palette.rule

                            StateLayer {
                                color: root.lock.pam.buffer ? Signal.palette.onSignal : Signal.palette.ink

                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Unlock")

                                function onClicked(): void {
                                    root.lock.pam.passwd.start();
                                }
                            }

                            Glyph {
                                anchors.centerIn: parent

                                name: "arrow-forward"
                                color: root.lock.pam.buffer ? Signal.palette.onSignal : Signal.palette.ink
                            }
                        }
                    }
                }
            }

            // Status lines. Errors are named in words; nothing flashes.
            RowLayout {
                id: messageRow

                Layout.fillWidth: true
                visible: message.msg !== ""
                spacing: Appearance.spacing.small

                Accessible.role: Accessible.AlertMessage
                Accessible.name: message.msg

                Glyph {
                    Layout.alignment: Qt.AlignTop
                    name: "alert-triangle"
                    color: Signal.palette.alert
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    id: message

                    readonly property Pam pam: root.lock.pam
                    readonly property string msg: {
                        if (pam.fprintState === "error")
                            return qsTr("FP ERROR: %1").arg(pam.fprint.message);
                        if (pam.state === "error")
                            return qsTr("PW ERROR: %1").arg(pam.passwd.message);

                        if (pam.lockMessage)
                            return pam.lockMessage;

                        if (pam.state === "max" && pam.fprintState === "max")
                            return qsTr("Maximum password and fingerprint attempts reached.");
                        if (pam.state === "max") {
                            if (pam.fprint.available)
                                return qsTr("Maximum password attempts reached. Please use fingerprint.");
                            return qsTr("Maximum password attempts reached.");
                        }
                        if (pam.fprintState === "max")
                            return qsTr("Maximum fingerprint attempts reached. Please use password.");

                        if (pam.state === "fail") {
                            if (pam.fprint.available)
                                return qsTr("Incorrect password. Please try again or use fingerprint.");
                            return qsTr("Incorrect password. Please try again.");
                        }
                        if (pam.fprintState === "fail")
                            return qsTr("Fingerprint not recognized (%1/%2). Please try again or use password.").arg(pam.fprint.tries).arg(Config.lock.maxFprintTries);

                        return "";
                    }

                    Layout.fillWidth: true
                    text: msg
                    color: Signal.palette.alert
                    mono: true
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }

            StyledText {
                id: stateMessage

                // Only unexpected states are worth a line: Caps lock ON and a
                // non-default keyboard layout. Num lock is never announced.
                readonly property string msg: {
                    const layoutChanged = Compositor.supports("keyboardLayoutState") && !Compositor.keyboardLayoutIsDefault;
                    const caps = Compositor.supports("lockStatus") && Compositor.capsLock;
                    if (layoutChanged && caps)
                        return qsTr("Caps lock is ON. Keyboard layout: %1").arg(Compositor.keyboardLayoutName);
                    if (layoutChanged)
                        return qsTr("Keyboard layout: %1").arg(Compositor.keyboardLayoutName);
                    if (caps)
                        return qsTr("Caps lock is ON.");
                    return "";
                }

                Layout.fillWidth: true
                visible: msg !== "" && !messageRow.visible
                text: msg
                color: Signal.palette.inkMuted
                mono: true
                font.pointSize: Appearance.font.size.smaller
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }

    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 2
    }
}

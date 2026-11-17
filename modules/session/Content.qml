pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import Quickshell
import QtQuick

// Session menu: one armed action per button — first press arms (with a
// confirm label), second press runs. Mirrors the control-center
// PowerTile pattern so destructive actions never fire on a stray key.
Column {
    id: root

    required property PersistentProperties visibilities

    padding: 12
    spacing: 2
    width: 280

    // Header: channel eyebrow + the honest context (uptime).
    Item {
        width: root.width - root.padding * 2
        height: 28

        Instruments.Eyebrow {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            label: root.title
            color: Signal.palette.ink
        }

        Instruments.Eyebrow {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: SysInfo.uptime !== ""
            label: root.uptimeLabel
        }
    }

    Rectangle {
        width: root.width - root.padding * 2
        height: 1
        color: Signal.palette.rule
    }

    Item {
        width: 1
        height: 6
    }

    // Two-step confirm for every action: first press arms, second press
    // runs. Focus loss or Escape resets.
    property string armedAction: ""
    readonly property string title: qsTr("Session")
    // "2 hours, 17 minutes" -> "2h 17m": the header stays one short line.
    readonly property string uptimeLabel: qsTr("up %1").arg(SysInfo.uptime.replace(/ days?/, "d").replace(/ hours?/, "h").replace(/ minutes?/, "m").replace(/,/g, ""))

    function runOrArm(action: string, command: var): void {
        if (root.armedAction !== action) {
            root.armedAction = action; // first press arms
            return;
        }
        root.armedAction = "";
        Quickshell.execDetached(command);
    }

    SessionButton {
        id: logout

        action: "logout"
        label: qsTr("Log out")
        icon: Config.session.icons.logout
        command: Config.session.commands.logout

        KeyNavigation.down: shutdown

        Component.onCompleted: forceActiveFocus()

        Connections {
            target: root.visibilities

            function onLauncherChanged(): void {
                if (!root.visibilities.launcher)
                    logout.forceActiveFocus();
            }
        }
    }

    SessionButton {
        id: shutdown

        action: "shutdown"
        label: qsTr("Shut down")
        icon: Config.session.icons.shutdown
        command: Config.session.commands.shutdown

        KeyNavigation.up: logout
        KeyNavigation.down: hibernate
    }

    SessionButton {
        id: hibernate

        action: "hibernate"
        label: qsTr("Hibernate")
        icon: Config.session.icons.hibernate
        command: Config.session.commands.hibernate

        KeyNavigation.up: shutdown
        KeyNavigation.down: reboot
    }

    SessionButton {
        id: reboot

        action: "reboot"
        label: qsTr("Restart")
        icon: Config.session.icons.reboot
        command: Config.session.commands.reboot

        KeyNavigation.up: hibernate
    }

    // Footer: the hornero dozing beside a quiet hint, in the active voice.
    Row {
        topPadding: 8
        leftPadding: 4
        spacing: Appearance.spacing.smaller

        HorneroSprite {
            anchors.verticalCenter: parent.verticalCenter
            pixel: 2
            pose: "sleep"
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Microcopy.line("session.hint")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }
    }

    component SessionButton: Column {
        id: entry

        required property string action
        required property string label
        required property string icon
        required property list<string> command

        readonly property bool armed: root.armedAction === entry.action

        spacing: 0
        focus: true

        Keys.onEnterPressed: root.runOrArm(entry.action, entry.command)
        Keys.onReturnPressed: root.runOrArm(entry.action, entry.command)
        Keys.onEscapePressed: event => {
            if (root.armedAction.length > 0) {
                root.armedAction = ""; // first Escape disarms
                event.accepted = true;
            } else {
                root.visibilities.session = false;
            }
        }
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_K && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }

        onActiveFocusChanged: {
            if (!activeFocus && root.armedAction === entry.action)
                root.armedAction = "";
        }

        // Instrument row: glyph cell, label, mono key cue. Focus shows the
        // on-air bar + `raised` fill; armed turns the row `alertWell` and
        // asks for the second press in words, not only colour.
        StyledRect {
            id: button

            width: root.width - root.padding * 2
            implicitHeight: 44

            radius: Appearance.rounding.small
            color: entry.armed ? Signal.palette.alertWell : entry.activeFocus ? Signal.palette.raised : "transparent"

            Accessible.role: Accessible.Button
            Accessible.name: entry.armed ? qsTr("Confirm %1").arg(entry.label) : entry.label
            Accessible.onPressAction: root.runOrArm(entry.action, entry.command)

            StateLayer {
                radius: parent.radius
                color: entry.armed ? Signal.palette.onAlertWell : Signal.palette.ink

                function onClicked(): void {
                    entry.forceActiveFocus();
                    root.runOrArm(entry.action, entry.command);
                }
            }

            Rectangle {
                visible: entry.activeFocus || entry.armed
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                width: 2
                color: entry.armed ? Signal.palette.alert : Signal.palette.signal
            }

            Glyph {
                id: glyph

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                name: entry.icon
                color: entry.armed ? Signal.palette.onAlertWell : entry.activeFocus ? Signal.palette.ink : Signal.palette.inkMuted
                size: Appearance.font.size.large
            }

            StyledText {
                anchors.left: glyph.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: entry.armed ? qsTr("Confirm %1").arg(entry.label.toLowerCase()) : entry.label
                color: entry.armed ? Signal.palette.onAlertWell : Signal.palette.ink
                font.pointSize: Appearance.font.size.normal
                font.weight: entry.activeFocus || entry.armed ? Font.Medium : Font.Normal
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.activeFocus || entry.armed
                mono: true
                text: entry.armed ? qsTr("⏎ again") : "⏎"
                color: entry.armed ? Signal.palette.onAlertWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                font.capitalization: Font.AllUppercase
                Accessible.ignored: true
            }
        }
    }
}

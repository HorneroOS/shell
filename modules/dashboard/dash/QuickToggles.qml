import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Three channel cells (night mode, gaming mode, screen recording). Cells
// are fixed rectangles in a shared well: a selected cell takes the
// `signalWell` fill plus an on-air bar, so state is never colour alone.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 32

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 4

        ToggleChip {
            Layout.fillWidth: true
            icon: "moon"
            label: qsTr("Night")
            description: qsTr("Toggle night mode")
            // No persistent service: the action only fires the script.
            active: false
            onToggled: Quickshell.execDetached(["horneroctl", "appearance", "night-mode", "toggle", "--yes"])
        }

        ToggleChip {
            Layout.fillWidth: true
            icon: "device-gamepad-2"
            label: qsTr("Game")
            description: Experience.gaming ? qsTr("Leave gaming mode") : qsTr("Switch to gaming mode")
            active: Experience.gaming
            onToggled: Experience.toggle("gaming")
        }

        ToggleChip {
            Layout.fillWidth: true
            icon: Recorder.running ? "player-stop" : "point"
            label: Recorder.running ? (Recorder.elapsed > 0 ? "%1:%2".arg(Math.floor(Recorder.elapsed / 60)).arg(String(Math.floor(Recorder.elapsed % 60)).padStart(2, "0")) : qsTr("Rec")) : qsTr("Record")
            description: Recorder.running ? qsTr("Stop screen recording") : qsTr("Start screen recording")
            active: Recorder.running
            onToggled: {
                if (Recorder.running)
                    Recorder.stop();
                else
                    Recorder.start();
            }
        }
    }

    component ToggleChip: Rectangle {
        id: chip

        required property string icon
        required property string label
        required property bool active
        property string description: chip.label
        signal toggled

        implicitHeight: 32
        implicitWidth: chipRow.implicitWidth + 20
        radius: Appearance.rounding.small
        border.width: 1
        border.color: chip.active ? Signal.palette.signal : Signal.palette.rule
        // Inactive cells keep a visible container (shell#462).
        color: chip.active ? Signal.palette.signalWell : Signal.palette.lifted

        Accessible.role: Accessible.Button
        Accessible.name: chip.description

        StateLayer {
            radius: parent.radius
            color: chip.active ? Signal.palette.onSignalWell : Signal.palette.ink

            function onClicked(): void {
                chip.toggled();
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            Glyph {
                anchors.verticalCenter: parent.verticalCenter

                name: chip.icon
                color: chip.active ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                mono: true
                text: chip.label
                color: chip.active ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                font.weight: chip.active ? Font.DemiBold : Font.Normal
            }
        }

        OnAirBar {
            edge: "bottom"
            active: chip.active
        }
    }
}

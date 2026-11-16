import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: row.implicitWidth + Appearance.padding.large * 2
    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        // Night mode toggle
        ToggleChip {
            icon: "dark_mode"
            label: qsTr("Night")
            description: qsTr("Toggle night mode")
            active: false  // No persistent service — just fire the script
            onToggled: Quickshell.execDetached(["horneroctl", "appearance", "night-mode", "toggle", "--yes"])
        }

        // Game mode toggle
        ToggleChip {
            icon: "sports_esports"
            label: qsTr("Game")
            description: GameMode.enabled ? qsTr("Turn off game mode") : qsTr("Turn on game mode")
            active: GameMode.enabled
            visible: Compositor.supports("hyprlandTuning")
            onToggled: GameMode.toggle()
        }

        // Screen recorder toggle
        ToggleChip {
            icon: Recorder.running ? "stop_circle" : "fiber_manual_record"
            label: Recorder.running
                ? (Recorder.elapsed > 0
                    ? "%1:%2".arg(Math.floor(Recorder.elapsed / 60)).arg(String(Math.floor(Recorder.elapsed % 60)).padStart(2, "0"))
                    : qsTr("Rec"))
                : qsTr("Record")
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

    // ── Reusable pill toggle ──────────────────────────────────────────────────
    component ToggleChip: StyledRect {
        id: chip

        required property string icon
        required property string label
        required property bool active
        property string description: chip.label
        signal toggled

        radius: Appearance.rounding.full
        Accessible.role: Accessible.Button
        Accessible.name: chip.description
        // Inactive chips used the card's own layer and read as plain text
        // (shell#462); a visible container keeps them recognisable as buttons.
        color: chip.active
            ? Colours.palette.m3primaryContainer
            : Colours.palette.m3surfaceContainerHighest
        implicitHeight: chipRow.implicitHeight + Appearance.padding.smaller * 2
        implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2

        StateLayer {
            radius: parent.radius
            color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            function onClicked() { chip.toggled(); }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: chip.icon
                color: chip.active
                    ? Colours.palette.m3onPrimaryContainer
                    : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.normal
                animate: true
            }

            StyledText {
                text: chip.label
                color: chip.active
                    ? Colours.palette.m3onPrimaryContainer
                    : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.smaller
                font.weight: chip.active ? 600 : 400
            }
        }
    }
}

pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// What this system can do, stated plainly (Desktop, Studio, Gaming).
// Everything here is read from the live services: the current experience
// mode, the factory layout and the capabilities Experience actually
// reports. A capability the system cannot confirm says so ("Not
// available", "Checked on first use"); nothing offers to switch modes —
// that lives in Settings.
GridLayout {
    id: root

    function studioStatus(): string {
        if (!Experience.studioAudioProbed)
            return qsTr("Checked on first use");
        return Experience.studioAudioAvailable ? qsTr("Ready") : qsTr("Not available");
    }

    function tuningStatus(): string {
        return Experience.hyprlandTuningAvailable ? qsTr("Ready") : qsTr("Not available");
    }

    Layout.fillWidth: true
    columns: 3
    columnSpacing: Appearance.spacing.small
    rowSpacing: Appearance.spacing.small

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("What this system can do")

    Instruments.Frame {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: headerHeight + desktopBody.implicitHeight + 16
        channel: "01"
        title: qsTr("Desktop")
        context: qsTr("always")

        ColumnLayout {
            id: desktopBody

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            Capability {
                label: qsTr("Cockpit layout")
                status: qsTr("Default")
                ok: true
            }

            Capability {
                label: qsTr("Launcher, dashboard, Control Center")
                status: qsTr("Ready")
                ok: true
            }

            Capability {
                label: qsTr("Mode now")
                status: Experience.label
                ok: true
            }
        }
    }

    Instruments.Frame {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: headerHeight + studioBody.implicitHeight + 16
        channel: "02"
        title: qsTr("Studio")

        ColumnLayout {
            id: studioBody

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            Capability {
                label: qsTr("Low-latency audio profile")
                status: root.studioStatus()
                ok: Experience.studioAudioAvailable
            }

            StyledText {
                Layout.fillWidth: true

                visible: Experience.studioAudioProbed && !Experience.studioAudioAvailable && Experience.studioAudioMessage !== ""
                text: Experience.studioAudioMessage
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }
        }
    }

    Instruments.Frame {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: headerHeight + gamingBody.implicitHeight + 16
        channel: "03"
        title: qsTr("Gaming")

        ColumnLayout {
            id: gamingBody

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            Capability {
                label: qsTr("Quiet mode: no animation, no glow")
                status: qsTr("Ready")
                ok: true
            }

            Capability {
                label: qsTr("Compositor tuning")
                status: root.tuningStatus()
                ok: Experience.hyprlandTuningAvailable
            }
        }
    }

    // One capability line: the label and a status named in words, with a
    // check or dash glyph so state never relies on colour.
    component Capability: RowLayout {
        id: cap

        required property string label
        required property string status
        required property bool ok

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("%1: %2").arg(cap.label).arg(cap.status)

        Glyph {
            Layout.alignment: Qt.AlignTop

            name: cap.ok ? "check" : "minus"
            color: cap.ok ? Signal.palette.phosphor : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true

                text: cap.label
                wrapMode: Text.WordWrap
            }

            StyledText {
                text: cap.status
                mono: true
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }
    }
}

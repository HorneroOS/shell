pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center › Gaming: read-only readiness from
// `horneroctl gaming doctor --json` (fixed argv, no shell). Gaming is
// Planned (HorneroOS/hornero#328): this pane installs nothing, writes no
// selection state, and never claims hardware qualification, game
// compatibility, performance, or latency.
//
// Three separate things live here and must not be conflated:
// - Hornero Gaming Focus (services/GameMode.qml): Hyprland visual
//   effects only, restored on disable/reload, unavailable on Niri.
// - Feral GameMode: process-scoped performance daemon, reported by
//   horneroctl as the `gamemode` doctor check. Not toggled here.
// - Power profiles: owned by the Power pane, untouched here.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    // Stable catalogue IDs (HorneroOS/hornero editions/catalogue.yaml).
    // IDs and titles only — package lists stay in the catalogue.
    readonly property var specializationModel: [
        { "id": "desktop-gaming", "title": qsTr("Desktop Gaming"), "note": qsTr("Default profile") },
        { "id": "handheld", "title": qsTr("Handheld"), "note": qsTr("Qualified hardware only") },
        { "id": "streaming", "title": qsTr("Streaming"), "note": "" },
        { "id": "multi-launcher", "title": qsTr("Multi-Launcher"), "note": "" },
        { "id": "vr", "title": qsTr("VR"), "note": qsTr("Experimental") },
        { "id": "advanced-compat", "title": qsTr("Advanced Compatibility"), "note": qsTr("User-managed opt-ins") }
    ]

    property var doctorChecks: []
    property string doctorError: ""

    function refresh(): void {
        if (doctorProc.running)
            return;
        root.doctorError = "";
        doctorProc.command = ["horneroctl", "--json", "gaming", "doctor"];
        doctorProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: doctorProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                doctorProc.out += data;
            }
        }
        onStarted: doctorProc.out = ""
        onExited: {
            try {
                const env = JSON.parse(doctorProc.out.trim());
                const data = env.data || {};
                root.doctorChecks = Object.keys(data).sort().map(name => ({
                            "name": name,
                            "ok": data[name] === "ok"
                        }));
                if (root.doctorChecks.length === 0)
                    root.doctorError = qsTr("Gaming diagnostics returned no checks.");
            } catch (e) {
                root.doctorChecks = [];
                root.doctorError = qsTr("Gaming is unavailable (is a horneroctl with gaming support installed?).");
            }
        }
    }

    SplitPaneLayout {
        anchors.fill: parent
        session: root.session

        leftContent: Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SettingsHeader {
                    icon: "sports_esports"
                    title: qsTr("Gaming")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Gaming is Planned: this pane only reports readiness from horneroctl. Nothing is installed or changed here, and detection is not hardware qualification.")
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                }
            }
        }

        rightContent: Component {
            StyledFlickable {
                flickableDirection: Flickable.VerticalFlick
                contentHeight: content.implicitHeight

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: parent
                }

                ColumnLayout {
                    id: content

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Appearance.spacing.normal

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Readiness")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.doctorError.length > 0
                            text: root.doctorError
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3error
                            font.pointSize: Appearance.font.size.small
                        }

                        Repeater {
                            model: root.doctorChecks

                            StyledText {
                                required property var modelData

                                Layout.fillWidth: true
                                text: (modelData.ok ? "✓ " : "✗ ") + modelData.name
                                color: modelData.ok ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                                font.pointSize: Appearance.font.size.small
                            }
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            Accessible.name: qsTr("Refresh Gaming readiness")
                            onClicked: root.refresh()
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Gaming Focus")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Hornero Gaming Focus only trims Hyprland visual effects while you play and restores them afterwards. It is separate from Feral GameMode (per-process performance) and from power profiles. Unavailable on compositors without Hyprland tuning.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        SwitchRow {
                            label: qsTr("Gaming Focus (Hyprland effects)")
                            checked: GameMode.enabled
                            onToggled: checked => GameMode.enabled = checked
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Profiles")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Profiles are selected in the installer or recorded by horneroctl; this pane does not change them. Steam is proprietary and always an explicit opt-in. Kernel-level anti-cheat is unsupported; EAC/BattlEye depend on publisher Proton enablement.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        Repeater {
                            model: root.specializationModel

                            StyledText {
                                required property var modelData

                                Layout.fillWidth: true
                                text: modelData.note.length > 0 ? `${modelData.title} — ${modelData.note}` : modelData.title
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.small
                            }
                        }
                    }
                }
            }
        }
    }
}

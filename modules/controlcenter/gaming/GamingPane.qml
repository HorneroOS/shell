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

// Control Center › Gaming: profiles, power, session and diagnostics.
// horneroctl is the single writer: `gaming selection show|set`,
// `gaming doctor` and `apps performance mode [set]` run with fixed
// argv (no shell, no package manager) and state is re-read after
// every run. Recording a selection installs nothing and Steam stays
// an explicit application opt-in. Power changes go through the ctl
// (via power-profiles-daemon, logind-mediated, not root) behind a two-step confirm. Gaming is Preview: detection is
// not hardware qualification and no performance is promised.
//
// Kept separate, never conflated:
// - Hornero Gaming Focus (services/GameMode.qml): Hyprland visual
//   effects only, restored on disable/reload, unavailable on Niri.
// - Feral GameMode: per-process daemon, reported as the `gamemode`
//   doctor check. Not toggled here.
// - The experimental Gamescope session (greeter-selectable) is
//   reported read-only here; it is never launched from this pane.
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
    readonly property var applicationModel: [
        { "id": "steam", "title": "Steam", "note": qsTr("Proprietary — explicit opt-in") },
        { "id": "lutris", "title": "Lutris", "note": "" },
        { "id": "bottles", "title": "Bottles", "note": "" },
        { "id": "wine", "title": "Wine", "note": "" },
        { "id": "vkbasalt", "title": "vkBasalt", "note": "" },
        { "id": "obs-studio", "title": "OBS Studio", "note": "" },
        { "id": "heroic-games-launcher", "title": "Heroic Games Launcher", "note": qsTr("Reference-only — not installed") },
        { "id": "steamvr", "title": "SteamVR", "note": qsTr("Experimental — reference-only") }
    ]
    readonly property var performanceModel: ["power-saver", "balanced", "performance"]

    property var doctorChecks: []
    property string doctorError: ""
    property bool doctorLoading: false
    property var selectedSpecializations: []
    property var selectedApplications: []
    property string selectionState: "unknown"
    property string actionError: ""
    property bool busy: false
    property string performanceCurrent: ""
    property var performanceAvailable: []
    property string performanceError: ""
    property string armedProfile: ""

    function refresh(): void {
        if (doctorProc.running || selectionProc.running || perfProc.running)
            return;
        root.doctorError = "";
        root.doctorLoading = true;
        doctorProc.running = true;
        selectionProc.running = true;
        perfProc.running = true;
    }

    function applyEnvelope(proc: Process, onOk: var): void {
        try {
            const env = JSON.parse(proc.out.trim());
            if (env.ok === true)
                onOk(env);
            else
                root.actionError = (env.message || qsTr("Gaming command failed")).toString();
        } catch (e) {
            root.actionError = qsTr("Gaming is unavailable (horneroctl did not answer).");
        }
    }

    function toggleId(kind: string, id: string, checked: bool): void {
        if (root.busy)
            return;
        let specs = root.selectedSpecializations.slice();
        let apps = root.selectedApplications.slice();
        const list = kind === "specialization" ? specs : apps;
        const at = list.indexOf(id);
        if (checked && at < 0)
            list.push(id);
        if (!checked && at >= 0)
            list.splice(at, 1);
        if (specs.length === 0 && apps.length === 0) {
            root.actionError = qsTr("Keep at least one specialization or application selected.");
            root.refresh();
            return;
        }
        root.busy = true;
        root.actionError = "";
        const argv = ["horneroctl", "--json", "gaming", "selection", "set"];
        for (const spec of specs)
            argv.push("--specialization", spec);
        for (const app of apps)
            argv.push("--application", app);
        setProc.command = argv;
        setProc.running = true;
    }

    // Two-step confirm: first click arms, second runs the ctl --yes
    // gate. Switching profile is reversible by picking another one.
    function setPerformance(profile: string): void {
        if (root.busy || profile === root.performanceCurrent)
            return;
        if (root.armedProfile !== profile) {
            root.armedProfile = profile;
            return;
        }
        root.armedProfile = "";
        root.busy = true;
        root.actionError = "";
        setProc.command = ["horneroctl", "--json", "apps", "performance", "mode", "set", profile, "--yes"];
        setProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: doctorProc

        command: ["horneroctl", "--json", "gaming", "doctor"]
        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                doctorProc.out += data;
            }
        }
        onStarted: doctorProc.out = ""
        onExited: {
            root.doctorLoading = false;
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

    Process {
        id: selectionProc

        command: ["horneroctl", "--json", "gaming", "selection", "show"]
        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                selectionProc.out += data;
            }
        }
        onStarted: selectionProc.out = ""
        onExited: root.applyEnvelope(selectionProc, env => {
            const data = env.data || {};
            root.selectionState = (data.state || "unknown").toString();
            root.selectedSpecializations = (data.specializations || "").toString().split(",").filter(s => s.length > 0);
            root.selectedApplications = (data.applications || "").toString().split(",").filter(s => s.length > 0);
        })
    }

    Process {
        id: perfProc

        command: ["horneroctl", "--json", "apps", "performance", "mode"]
        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                perfProc.out += data;
            }
        }
        onStarted: perfProc.out = ""
        onExited: {
            try {
                const env = JSON.parse(perfProc.out.trim());
                const data = env.data || {};
                root.performanceCurrent = (data.current || "").toString();
                root.performanceAvailable = (data.available || "").toString().split(",").filter(s => s.length > 0);
                root.performanceError = env.ok === true ? "" : qsTr("Power profile unavailable.");
            } catch (e) {
                root.performanceCurrent = "";
                root.performanceAvailable = [];
                root.performanceError = qsTr("Power profile unavailable (is horneroctl installed?).");
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
        onStarted: setProc.out = ""
        onExited: {
            root.busy = false;
            root.applyEnvelope(setProc, () => {});
            root.refresh();
        }
    }

    SplitPaneLayout {
        anchors.fill: parent

        leftContent: Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SettingsHeader {
                    icon: "sports_esports"
                    title: qsTr("Gaming")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Gaming is Preview: profiles record what you want and nothing is installed by recording them. Detection is not hardware qualification, and no game compatibility or performance is promised.")
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
                            text: qsTr("Profiles")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectionState === "recorded" ? qsTr("Selection recorded. No packages were installed or removed by recording it.") : root.selectionState === "not-selected" ? qsTr("No selection recorded yet. Choose a profile or individual applications below.") : qsTr("Reading selection…")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionError.length > 0
                            text: root.actionError
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3error
                            font.pointSize: Appearance.font.size.small
                        }

                        Repeater {
                            model: root.specializationModel

                            SwitchRow {
                                required property var modelData

                                label: modelData.note.length > 0 ? `${modelData.title} — ${modelData.note}` : modelData.title
                                checked: root.selectedSpecializations.includes(modelData.id)
                                enabled: !root.busy
                                onToggled: checked => root.toggleId("specialization", modelData.id, checked)
                            }
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            Accessible.name: qsTr("Refresh Gaming profiles, power and diagnostics")
                            enabled: !root.busy
                            onClicked: root.refresh()
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Applications")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        Repeater {
                            model: root.applicationModel

                            SwitchRow {
                                required property var modelData

                                label: modelData.note.length > 0 ? `${modelData.title} — ${modelData.note}` : modelData.title
                                checked: root.selectedApplications.includes(modelData.id)
                                enabled: !root.busy && modelData.id !== "heroic-games-launcher" && modelData.id !== "steamvr"
                                onToggled: checked => root.toggleId("application", modelData.id, checked)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Steam is proprietary and always an explicit opt-in. Removing an application from the selection never deletes your files, settings, or games.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Performance mode")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.performanceError.length > 0 ? root.performanceError : root.performanceCurrent.length > 0 ? qsTr("Current profile: %1. Switching is reversible — pick another profile to change back. Performance can raise heat, fan noise, and battery use; no improvement is guaranteed.").arg(root.performanceCurrent) : qsTr("Reading power profile…")
                            wrapMode: Text.WordWrap
                            color: root.performanceError.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        Repeater {
                            model: root.performanceModel

                            TextButton {
                                required property var modelData

                                text: root.armedProfile === modelData ? qsTr("Confirm %1").arg(modelData) : modelData
                                Accessible.name: qsTr("Set power profile to %1 (two-step confirm)").arg(modelData)
                                enabled: !root.busy && root.performanceAvailable.includes(modelData) && root.performanceCurrent !== modelData
                                onClicked: root.setPerformance(modelData)
                            }
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
                            text: qsTr("Gaming session")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("The experimental Gamescope session is chosen at the greeter (login screen), not launched from here. It fails closed when gamescope or Steam is missing; check Diagnostics below for both. Kernel-level anti-cheat is unsupported; EAC/BattlEye depend on publisher Proton enablement.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Diagnostics")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.doctorLoading || root.doctorError.length > 0 || root.doctorChecks.length === 0
                            text: root.doctorLoading ? qsTr("Running diagnostics…") : root.doctorError.length > 0 ? root.doctorError : qsTr("No diagnostics yet.")
                            wrapMode: Text.WordWrap
                            color: root.doctorError.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
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
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center › Studio: workload and application selection manager.
// horneroctl is the single writer of Studio selection state: this pane
// only invokes `horneroctl studio selection show|set` and
// `horneroctl studio doctor` with fixed argv (no shell, no package
// manager) and re-reads state after every run. Recording a selection is
// user intent only — no package is installed or removed here, and
// removing a workload never touches user data, settings, or projects.
// Studio remains Planned; nothing here claims QA-validated support.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    // Stable catalogue IDs (HorneroOS/hornero editions/catalogue.yaml).
    // IDs and display titles only — package lists stay in the catalogue.
    readonly property var specializationModel: [
        { "id": "audio-music-production", "title": qsTr("Audio & Music Production") },
        { "id": "video-editing-post-production", "title": qsTr("Video Editing & Post-Production") },
        { "id": "streaming-content-creation", "title": qsTr("Streaming & Content Creation") },
        { "id": "graphic-design-illustration", "title": qsTr("Graphic Design & Illustration") },
        { "id": "photography-raw-processing", "title": qsTr("Photography & RAW Processing") },
        { "id": "3d-animation-vfx", "title": qsTr("3D, Animation & VFX") },
        { "id": "game-development", "title": qsTr("Game Development") },
        { "id": "maker-cad", "title": qsTr("Maker & CAD") },
        { "id": "complete-creative-workstation", "title": qsTr("Complete Creative Workstation") },
        { "id": "custom-selection", "title": qsTr("Custom Selection") }
    ]
    readonly property var applicationModel: [
        { "id": "ardour", "title": "Ardour", "note": "" },
        { "id": "guitarix", "title": "Guitarix", "note": "" },
        { "id": "carla", "title": "Carla", "note": "" },
        { "id": "audacity", "title": "Audacity", "note": "" },
        { "id": "reaper", "title": "REAPER", "note": qsTr("Proprietary — vendor EULA, explicit opt-in") },
        { "id": "yabridge", "title": "yabridge", "note": qsTr("Windows VST bridge — needs Wine and your own plugins") },
        { "id": "obs-studio", "title": "OBS Studio", "note": "" },
        { "id": "kdenlive", "title": "Kdenlive", "note": "" },
        { "id": "blender", "title": "Blender", "note": "" },
        { "id": "krita", "title": "Krita", "note": "" },
        { "id": "gimp", "title": "GIMP", "note": "" },
        { "id": "inkscape", "title": "Inkscape", "note": "" },
        { "id": "darktable", "title": "darktable", "note": "" },
        { "id": "rawtherapee", "title": "RawTherapee", "note": "" },
        { "id": "graphite", "title": "Graphite", "note": qsTr("Experimental") },
        { "id": "penpot", "title": "Penpot", "note": qsTr("Reference-only — browser tool, not installed") },
        { "id": "scribus", "title": "Scribus", "note": "" },
        { "id": "freecad", "title": "FreeCAD", "note": "" },
        { "id": "godot", "title": "Godot", "note": "" }
    ]

    property var selectedSpecializations: []
    property var selectedApplications: []
    property string selectionState: "unknown"
    property string selectionError: ""
    property string actionError: ""
    property var doctorChecks: []
    property bool busy: false

    function refresh(): void {
        if (selectionProc.running || doctorProc.running)
            return;
        root.selectionError = "";
        selectionProc.command = ["horneroctl", "--json", "studio", "selection", "show"];
        selectionProc.running = true;
        doctorProc.command = ["horneroctl", "--json", "studio", "doctor"];
        doctorProc.running = true;
    }

    function applyEnvelope(proc: Process, onOk: var): void {
        try {
            const env = JSON.parse(proc.out.trim());
            if (env.ok === true) {
                onOk(env);
            } else {
                root.actionError = (env.message || qsTr("Studio command failed")).toString();
            }
        } catch (e) {
            root.actionError = qsTr("Studio is unavailable (horneroctl did not answer).");
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
        const argv = ["horneroctl", "--json", "studio", "selection", "set"];
        for (const spec of specs)
            argv.push("--specialization", spec);
        for (const app of apps)
            argv.push("--application", app);
        setProc.command = argv;
        setProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: selectionProc

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
            } catch (e) {
                root.doctorChecks = [];
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
        session: root.session

        leftContent: Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SettingsHeader {
                    icon: "movie_creation"
                    title: qsTr("Studio")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Creative workloads for this machine. Studio is Planned: selections record what you want, and package installation stays a separate reviewed step.")
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

                        // First-run checklist derived only from recorded
                        // selection state and read-only doctor data.
                        // Anything owned by the installer or QA is shown
                        // as pending evidence, never as passed.
                        StyledText {
                            Layout.fillWidth: true
                            text: (root.selectionState === "recorded" ? qsTr("✓ Selection recorded") : qsTr("○ Record a selection below")) + "\n" + (root.doctorChecks.length > 0 ? qsTr("✓ Audio stack health reported by horneroctl") : qsTr("○ Audio stack health unavailable (is horneroctl installed?)")) + "\n" + qsTr("○ Installer onboarding and QA acceptance: pending evidence, not passed")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Selection")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectionState === "recorded" ? qsTr("Selection recorded. No packages were installed or removed by recording it.") : root.selectionState === "not-selected" ? qsTr("No selection recorded yet. Choose a specialization or individual applications below.") : qsTr("Reading selection…")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionError.length > 0 || root.selectionError.length > 0
                            text: root.actionError.length > 0 ? root.actionError : root.selectionError
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3error
                            font.pointSize: Appearance.font.size.small
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            Accessible.name: qsTr("Refresh Studio selection and health")
                            enabled: !root.busy
                            onClicked: root.refresh()
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Specializations")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        Repeater {
                            model: root.specializationModel

                            SwitchRow {
                                required property var modelData

                                label: modelData.title
                                checked: root.selectedSpecializations.includes(modelData.id)
                                enabled: !root.busy
                                onToggled: checked => root.toggleId("specialization", modelData.id, checked)
                            }
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
                                enabled: !root.busy && modelData.id !== "penpot"
                                onToggled: checked => root.toggleId("application", modelData.id, checked)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Removing a workload or application from the selection never deletes your files, settings, or projects.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Audio routing & health")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        // Read-only view over the existing Audio service
                        // (Quickshell Pipewire). Shell owns no second
                        // audio graph: devices and streams come from the
                        // shared backend, and anything the backend does
                        // not expose reliably is labelled unsupported
                        // instead of being estimated.
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Output: %1").arg(Audio.sink ? (Audio.sink.description || Audio.sink.name) : qsTr("No output device detected"))
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Input: %1").arg(Audio.source ? (Audio.source.description || Audio.source.name) : qsTr("No input device detected"))
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Audio.streams.length > 0 ? qsTr("Active streams: %1").arg(Audio.streams.map(stream => Audio.getStreamName(stream)).join(", ")) : qsTr("No active application streams.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Effective rate/quantum and XRUN counts are not exposed by this backend, so they are not estimated here. Use Balanced unless you measured otherwise; no audio is recorded by this view.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Health")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        Repeater {
                            model: root.doctorChecks

                            StyledText {
                                required property var modelData

                                Layout.fillWidth: true
                                text: `${modelData.ok ? "✓" : "✗"} ${modelData.name}`
                                color: modelData.ok ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                                font.pointSize: Appearance.font.size.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.doctorChecks.length === 0
                            text: qsTr("Health checks unavailable (is horneroctl installed?).")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }
                }
            }
        }
    }
}

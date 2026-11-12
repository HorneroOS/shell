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

// Control Center › Agent Center: read-only view over the coding/agent
// CLIs HorneroOS discovers on this machine, plus Javi (Hermes) state.
// horneroctl is the single source of truth: this pane only invokes
// fixed argv — `horneroctl --json agent list`,
// `horneroctl --json agent status <id>`,
// `horneroctl --json agent default show`,
// `horneroctl --json agent config status` and
// `horneroctl --json assistant status` — and re-reads state after
// every run. The only action is recording a default agent from an
// explicit per-agent click (`agent default set <id> --yes`); recording
// a default installs and launches nothing. `agent launch` is a
// dry-run proposal only (executed=false), shown as proposal text and
// never presented as a real launch. horneroctl reports no agent
// version or usage data, so none is shown here. Auth state is
// file-presence only as reported by the CLI; credential contents and
// secrets never enter this pane.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property var agentsModel: []
    property string defaultAgent: ""
    property string defaultState: "unknown"
    property bool assistantKnown: false
    property bool assistantEnabled: false
    property string assistantGateway: ""
    property string assistantHermes: ""
    property string assistantMessage: ""
    property string configSummary: ""
    property string listError: ""
    property string actionError: ""
    property string actionMessage: ""
    property string proposalText: ""
    property bool loading: false
    property bool busy: false
    property var pendingStatusIds: []
    property string currentStatusId: ""

    function refresh(): void {
        if (root.loading || root.busy || statusProc.running)
            return;
        root.loading = true;
        root.listError = "";
        root.actionError = "";
        listProc.command = ["horneroctl", "--json", "agent", "list"];
        listProc.running = true;
        defaultProc.command = ["horneroctl", "--json", "agent", "default", "show"];
        defaultProc.running = true;
        assistantProc.command = ["horneroctl", "--json", "assistant", "status"];
        assistantProc.running = true;
        configProc.command = ["horneroctl", "--json", "agent", "config", "status"];
        configProc.running = true;
    }

    function parseEnvelope(raw: string): var {
        try {
            return JSON.parse(raw.trim());
        } catch (e) {
            return null;
        }
    }

    // Per-agent detail (auth/config presence) only exists in
    // `agent status <id>`, so queued ids are probed one at a time
    // through the same fixed-argv template.
    function probeNextStatus(): void {
        if (root.pendingStatusIds.length === 0) {
            root.currentStatusId = "";
            root.loading = false;
            return;
        }
        const next = root.pendingStatusIds.slice();
        root.currentStatusId = next.shift().toString();
        root.pendingStatusIds = next;
        statusProc.command = ["horneroctl", "--json", "agent", "status", root.currentStatusId];
        statusProc.running = true;
    }

    function updateAgent(id: string, fields: var): void {
        const rows = root.agentsModel.slice();
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].id === id) {
                const merged = {};
                for (const key in rows[i])
                    merged[key] = rows[i][key];
                for (const key in fields)
                    merged[key] = fields[key];
                rows[i] = merged;
            }
        }
        root.agentsModel = rows;
    }

    // Explicit per-agent user click only. horneroctl records the
    // choice under XDG config; it installs and launches nothing.
    function setDefault(id: string): void {
        if (root.busy || id.length === 0 || id === root.defaultAgent)
            return;
        root.busy = true;
        root.actionError = "";
        root.actionMessage = "";
        setDefaultProc.command = ["horneroctl", "--json", "agent", "default", "set", id, "--yes"];
        setDefaultProc.running = true;
    }

    // Dry-run proposal only: the CLI returns executed=false and never
    // runs the agent, so the result is shown as proposal copy text.
    function showLaunchProposal(id: string): void {
        if (root.busy || id.length === 0)
            return;
        root.busy = true;
        root.actionError = "";
        root.proposalText = "";
        launchProc.command = ["horneroctl", "--json", "agent", "launch", id];
        launchProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                listProc.out += data;
            }
        }
        onStarted: listProc.out = ""
        onExited: {
            const env = root.parseEnvelope(listProc.out);
            if (!env || env.ok !== true) {
                root.agentsModel = [];
                root.listError = env && env.message ? env.message.toString() : qsTr("Agent list unavailable (is horneroctl installed?).");
                root.loading = false;
                return;
            }
            const data = env.data || {};
            const ids = (data.agents || "").toString().split(",").filter(s => s.length > 0);
            root.defaultAgent = (data.default || "").toString();
            const rows = [];
            for (const id of ids) {
                rows.push({
                    "id": id,
                    "name": id,
                    "exec": (data["agent." + id + ".exec"] || "").toString(),
                    "installed": data["agent." + id + ".installed"] === "true",
                    "auth": "unknown",
                    "configPresent": "unknown",
                    "resolvedPath": ""
                });
            }
            root.agentsModel = rows;
            root.pendingStatusIds = ids.slice();
            root.probeNextStatus();
        }
    }

    Process {
        id: statusProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                statusProc.out += data;
            }
        }
        onStarted: statusProc.out = ""
        onExited: {
            const env = root.parseEnvelope(statusProc.out);
            if (env && env.ok === true) {
                const data = env.data || {};
                root.updateAgent(root.currentStatusId, {
                    "name": (data.name || root.currentStatusId).toString(),
                    "exec": (data.exec || "").toString(),
                    "installed": data.installed === "true",
                    "auth": (data.auth || "unknown").toString(),
                    "configPresent": (data.config_present || "unknown").toString(),
                    "resolvedPath": (data.resolved_path || "").toString()
                });
                if (data.is_default === "true")
                    root.defaultAgent = root.currentStatusId;
            }
            root.probeNextStatus();
        }
    }

    Process {
        id: defaultProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                defaultProc.out += data;
            }
        }
        onStarted: defaultProc.out = ""
        onExited: {
            const env = root.parseEnvelope(defaultProc.out);
            if (env && env.ok === true) {
                const data = env.data || {};
                root.defaultState = (data.state || "unknown").toString();
                root.defaultAgent = (data.default || "").toString();
            } else {
                root.defaultState = "unknown";
            }
        }
    }

    Process {
        id: assistantProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantProc.out += data;
            }
        }
        onStarted: assistantProc.out = ""
        onExited: {
            const env = root.parseEnvelope(assistantProc.out);
            if (!env) {
                root.assistantKnown = false;
                root.assistantMessage = qsTr("Assistant status unavailable (is horneroctl installed?).");
                return;
            }
            const data = env.data || {};
            root.assistantKnown = true;
            root.assistantEnabled = data.enabled === "true";
            root.assistantGateway = (data.gateway || "").toString();
            root.assistantHermes = (data.hermes || "").toString();
            root.assistantMessage = (env.message || "").toString();
        }
    }

    Process {
        id: configProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                configProc.out += data;
            }
        }
        onStarted: configProc.out = ""
        onExited: {
            const env = root.parseEnvelope(configProc.out);
            if (env && env.ok === true) {
                const data = env.data || {};
                root.configSummary = qsTr("Entries: %1 · Targets: %2 · Issues: %3").arg((data.entries || "0").toString()).arg((data.targets || "0").toString()).arg((data.issues || "0").toString());
            } else {
                root.configSummary = qsTr("Agent config status unavailable (is horneroctl installed?).");
            }
        }
    }

    Process {
        id: setDefaultProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                setDefaultProc.out += data;
            }
        }
        onStarted: setDefaultProc.out = ""
        onExited: {
            root.busy = false;
            const env = root.parseEnvelope(setDefaultProc.out);
            if (env && env.ok === true) {
                root.actionMessage = (env.message || "").toString();
                root.refresh();
            } else {
                root.actionError = env && env.message ? env.message.toString() : qsTr("Could not record the default agent.");
            }
        }
    }

    Process {
        id: launchProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                launchProc.out += data;
            }
        }
        onStarted: launchProc.out = ""
        onExited: {
            root.busy = false;
            const env = root.parseEnvelope(launchProc.out);
            if (env && env.ok === true) {
                const data = env.data || {};
                // executed=false: this is proposal copy text only,
                // nothing was launched by showing it.
                root.proposalText = qsTr("Proposal only (executed=false): %1").arg((data.proposal || env.message || "").toString());
            } else {
                root.actionError = env && env.message ? env.message.toString() : qsTr("Launch proposal unavailable.");
            }
        }
    }

    SplitPaneLayout {
        anchors.fill: parent

        leftContent: Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SettingsHeader {
                    icon: "smart_toy"
                    title: qsTr("Agent Center")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Coding agents discovered on this machine, and Javi, the Hornero assistant. State comes only from horneroctl; nothing is fetched or launched here.")
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
                            text: qsTr("Agents")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.loading
                            text: qsTr("Reading agents…")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.loading && root.listError.length > 0
                            text: root.listError
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3error
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.loading && root.listError.length === 0 && root.agentsModel.length === 0
                            text: qsTr("No agents reported by horneroctl.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionError.length > 0
                            text: root.actionError
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3error
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionMessage.length > 0
                            text: root.actionMessage
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            Accessible.name: qsTr("Refresh agent, default, config and assistant state")
                            enabled: !root.loading && !root.busy
                            onClicked: root.refresh()
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Default agent")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.defaultAgent.length > 0 ? qsTr("Default: %1").arg(root.defaultAgent) : root.defaultState === "not-selected" ? qsTr("No default agent recorded. Choose one from the list below.") : qsTr("Default agent state unavailable.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Recording a default only saves your choice; it does not start the agent.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Discovered agents")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        Repeater {
                            model: root.agentsModel

                            ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.id === root.defaultAgent ? qsTr("%1 — default").arg(modelData.name) : modelData.name
                                    wrapMode: Text.WordWrap
                                    font.weight: 600
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Installed: %1 · Auth: %2 · Config present: %3").arg(modelData.installed ? qsTr("yes (%1)").arg(modelData.resolvedPath.length > 0 ? modelData.resolvedPath : modelData.exec) : qsTr("not found on PATH")).arg(modelData.auth).arg(modelData.configPresent)
                                    wrapMode: Text.WordWrap
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.small
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Version: not reported by horneroctl")
                                    wrapMode: Text.WordWrap
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.small
                                }

                                RowLayout {
                                    TextButton {
                                        text: qsTr("Set default")
                                        Accessible.name: qsTr("Record %1 as the default agent").arg(modelData.id)
                                        enabled: !root.busy && !root.loading && modelData.id !== root.defaultAgent
                                        visible: modelData.id !== root.defaultAgent
                                        onClicked: root.setDefault(modelData.id)
                                    }

                                    TextButton {
                                        text: qsTr("Launch proposal")
                                        Accessible.name: qsTr("Show the dry-run launch proposal for %1 (nothing is executed)").arg(modelData.id)
                                        enabled: !root.busy && !root.loading
                                        onClicked: root.showLaunchProposal(modelData.id)
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.proposalText.length > 0
                            text: root.proposalText
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Javi assistant")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: !root.assistantKnown ? qsTr("Assistant status unavailable (is horneroctl installed?).") : root.assistantEnabled ? qsTr("Enabled · Gateway: %1 · Hermes: %2").arg(root.assistantGateway.length > 0 ? root.assistantGateway : qsTr("unknown")).arg(root.assistantHermes) : qsTr("Disabled")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.assistantMessage.length > 0
                            text: root.assistantMessage
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Manage Javi in the Javi pane; this pane only reports assistant state.")
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SectionContainer {
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Agent config")
                            font.pointSize: Appearance.font.size.large
                            font.weight: 600
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.configSummary.length > 0 ? root.configSummary : qsTr("Reading agent config…")
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

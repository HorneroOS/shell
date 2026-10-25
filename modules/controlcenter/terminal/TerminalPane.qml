pragma ComponentBehavior: Bound

import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import qs.modules.controlcenter
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    // Keep the supported choices visible even when only one is installed.
    // Availability is runtime data; the chooser itself is a stable product
    // contract and must not disappear when that query returns an empty list.
    property var installedTerminals: []
    property string selectedTerminal: "kitty"
    property string statusMessage: ""
    property bool loading: true
    property bool busy: false
    property bool listAnswered: false
    property bool listTimedOut: false
    property bool actionAnswered: false
    property bool actionSucceeded: false

    function envelope(raw: string): var {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    function availableTerminalIds(value: var): var {
        const supported = ["kitty", "alacritty", "ghostty"];
        const candidates = Array.isArray(value) ? value : String(value || "").split(",");
        const ids = [];
        for (const candidate of candidates) {
            const id = String(candidate).trim().toLowerCase();
            if (supported.indexOf(id) >= 0 && ids.indexOf(id) < 0)
                ids.push(id);
        }
        return ids;
    }

    function refresh(): void {
        if (listProc.running || actionProc.running)
            return;
        root.loading = true;
        root.listAnswered = false;
        root.listTimedOut = false;
        listProc.running = true;
    }

    function logLayout(): void {
        const headerLayout = header.children.length > 0 ? header.children[0] : null;
        const sectionLayout = terminalSection.children.length > 0 ? terminalSection.children[0] : null;
        const firstSectionChild = sectionLayout && sectionLayout.children.length > 0 ? sectionLayout.children[0] : null;
        function describe(item: var): string {
            if (!item)
                return "none";
            const label = item.text !== undefined ? String(item.text) : item.terminalId !== undefined ? String(item.terminalId) : item.toString();
            const color = item.color !== undefined ? String(item.color) : "n/a";
            return `${label}@${item.x},${item.y} ${item.width}x${item.height} visible=${item.visible} opacity=${item.opacity} color=${color}`;
        }
        const headerDescriptions = [];
        if (headerLayout) {
            for (let index = 0; index < headerLayout.children.length; index++)
                headerDescriptions.push(describe(headerLayout.children[index]));
        }
        const sectionDescriptions = [];
        if (sectionLayout) {
            for (let index = 0; index < sectionLayout.children.length; index++)
                sectionDescriptions.push(describe(sectionLayout.children[index]));
        }
        const headerChildren = headerDescriptions.length > 0 ? headerDescriptions.join(" | ") : "none";
        const sectionChildren = sectionDescriptions.length > 0 ? sectionDescriptions.join(" | ") : "none";
        console.log(`[TerminalPane] root=${root.x},${root.y} ${root.width}x${root.height} visible=${root.visible}/${root.opacity} surface=${surface.x},${surface.y} ${surface.width}x${surface.height} visible=${surface.visible}/${surface.opacity} flick=${flick.x},${flick.y} ${flick.width}x${flick.height} visible=${flick.visible}/${flick.opacity} contentY=${flick.contentY} content=${content.x},${content.y} ${content.width}x${content.height} implicit=${content.implicitHeight} visible=${content.visible} opacity=${content.opacity} header=${header.x},${header.y} ${header.width}x${header.height} layout=${headerLayout ? `${headerLayout.x},${headerLayout.y} ${headerLayout.width}x${headerLayout.height} implicit=${headerLayout.implicitHeight} visible=${headerLayout.visible}/${headerLayout.opacity}` : "none"} headerChildren=${headerChildren} section=${terminalSection.x},${terminalSection.y} ${terminalSection.width}x${terminalSection.height} visible=${terminalSection.visible}/${terminalSection.opacity} layout=${sectionLayout ? `${sectionLayout.x},${sectionLayout.y} ${sectionLayout.width}x${sectionLayout.height} implicit=${sectionLayout.implicitHeight} visible=${sectionLayout.visible}/${sectionLayout.opacity} children=${sectionLayout.children.length}` : "none"} first=${describe(firstSectionChild)} sectionChildren=${sectionChildren} loading=${root.loading} status=${root.statusMessage}`);
    }

    function applyTerminal(id: string): void {
        if (root.busy || id === root.selectedTerminal)
            return;
        root.statusMessage = "";
        root.actionAnswered = false;
        root.actionSucceeded = false;
        root.busy = true;
        actionProc.command = ["horneroctl", "--json", "config", "default-apps", "set", "terminal", id, "--yes"];
        actionProc.running = true;
    }

    component TerminalCard: StyledRect {
        id: terminalCard

        required property string terminalId
        readonly property bool installed: root.installedTerminals.indexOf(terminalId) >= 0

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        Item {
            id: row

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            implicitHeight: Math.max(icon.implicitHeight, details.implicitHeight, action.implicitHeight)

            MaterialIcon {
                id: icon

                anchors.left: parent.left
                anchors.leftMargin: Appearance.spacing.normal
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.font.size.extraLarge * 1.5
                text: "terminal"
                color: terminalCard.installed && terminalCard.terminalId === root.selectedTerminal ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.large
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                id: details

                anchors.left: icon.right
                anchors.leftMargin: Appearance.spacing.normal
                anchors.right: action.left
                anchors.rightMargin: Appearance.spacing.normal
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: terminalCard.terminalId === "kitty" ? "Kitty" : terminalCard.terminalId === "alacritty" ? "Alacritty" : "Ghostty"
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 600
                }

                StyledText {
                    text: !terminalCard.installed ? qsTr("Not installed") : terminalCard.terminalId === root.selectedTerminal ? qsTr("Selected default") : qsTr("Installed and ready to use")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            ActionCell {
                id: action

                width: action.actionColumnWidth
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: !terminalCard.installed ? qsTr("Install first") : terminalCard.terminalId === root.selectedTerminal ? qsTr("Selected") : qsTr("Use this")
                type: terminalCard.terminalId === root.selectedTerminal ? TextButton.Tonal : TextButton.Text
                controlEnabled: terminalCard.installed && terminalCard.terminalId !== root.selectedTerminal && !root.busy
                disabled: !terminalCard.installed || terminalCard.terminalId === root.selectedTerminal || root.busy
                accessibilityRole: terminalCard.terminalId === root.selectedTerminal || !terminalCard.installed ? Accessible.StaticText : Accessible.Button
                accessibilityName: terminalCard.terminalId === root.selectedTerminal ? qsTr("%1 is the default terminal").arg(terminalCard.terminalId) : !terminalCard.installed ? qsTr("%1 is not installed").arg(terminalCard.terminalId) : qsTr("Use %1 as the default terminal").arg(terminalCard.terminalId)
                onClicked: root.applyTerminal(terminalCard.terminalId)
            }
        }
    }

    Component.onCompleted: {
        root.refresh();
        Qt.callLater(root.logLayout);
    }

    onLoadingChanged: Qt.callLater(root.logLayout)

    Timer {
        id: listTimeout

        // Start with the initial request and keep running until both the UI
        // has a response and the process has exited.
        running: root.loading || listProc.running
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.loading && !root.listAnswered) {
                root.listTimedOut = true;
                root.installedTerminals = [];
                root.loading = false;
                root.statusMessage = qsTr("Terminal settings request timed out.");
            }
            if (listProc.running) {
                listProc.running = false;
                listKillTimeout.start();
            }
        }
    }

    Timer {
        id: listKillTimeout

        interval: 2000
        repeat: false
        onTriggered: {
            if (listProc.running)
                listProc.signal(9); // POSIX SIGKILL after the SIGTERM grace period.
        }
    }

    Process {
        id: listProc

        command: ["horneroctl", "--json", "config", "default-apps", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.listTimedOut)
                    return;
                const response = root.envelope(text);
                root.listAnswered = response !== null;
                root.loading = false;
                if (!response || response.ok !== true) {
                    root.installedTerminals = [];
                    root.statusMessage = response && response.message ? response.message : qsTr("Could not read terminal settings.");
                    return;
                }
                const data = response.data || {};
                root.selectedTerminal = String(data.terminal_shell_id || "kitty");
                root.installedTerminals = root.availableTerminalIds(data.terminals_available);
                root.statusMessage = root.installedTerminals.length === 0 ? qsTr("Install Kitty, Alacritty, or Ghostty to choose a terminal.") : "";
            }
        }
        onExited: (exitCode, exitStatus) => {
            listKillTimeout.stop();
            root.loading = false;
            if (!root.listAnswered) {
                if (root.listTimedOut) {
                    return;
                }
                root.installedTerminals = [];
                root.statusMessage = (exitCode !== 0 || exitStatus !== 0)
                    ? qsTr("Terminal settings could not be loaded (exit %1).").arg(exitCode)
                    : qsTr("Terminal settings returned no data.");
            }
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = root.envelope(text);
                root.actionAnswered = response !== null;
                root.actionSucceeded = response !== null && response.ok === true;
                root.statusMessage = response && response.message ? response.message : "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.statusMessage.length === 0)
                    root.statusMessage = text.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if ((exitCode !== 0 || exitStatus !== 0) && !root.actionAnswered) {
                root.actionSucceeded = false;
                root.statusMessage = qsTr("The terminal setting could not be changed (exit %1).").arg(exitCode);
            }
            if (root.actionSucceeded)
                Qt.callLater(() => root.refresh());
        }
    }

    StyledClippingRect {
        id: surface

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: Appearance.rounding.normal
        color: "transparent"

            StyledFlickable {
                id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                SettingsHeader {
                    id: header

                    icon: "terminal"
                    title: qsTr("Terminal")
                }

                SectionContainer {
                    id: terminalSection

                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Choose the terminal Hornero opens for shortcuts and integrated actions. The selection is shared with Exo, XDG terminal preferences, and Hornero Shell.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        visible: !root.loading && root.installedTerminals.indexOf(root.selectedTerminal) < 0
                        Layout.fillWidth: true
                        text: qsTr("The saved default (%1) is not currently installed. Install it or choose an available terminal below.").arg(root.selectedTerminal)
                        color: Colours.palette.m3tertiary
                        wrapMode: Text.Wrap
                    }

                    // Keep the sizing contract on the instances consumed by
                    // this ColumnLayout so each row uses the full section width.
                    TerminalCard {
                        Layout.fillWidth: true
                        terminalId: "kitty"
                    }

                    TerminalCard {
                        Layout.fillWidth: true
                        terminalId: "alacritty"
                    }

                    TerminalCard {
                        Layout.fillWidth: true
                        terminalId: "ghostty"
                    }

                    StyledText {
                        visible: root.loading
                        Layout.fillWidth: true
                        text: qsTr("Checking installed terminals…")
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        visible: root.statusMessage.length > 0
                        Layout.fillWidth: true
                        text: root.statusMessage
                        color: root.actionSucceeded ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        Accessible.role: Accessible.StaticText
                        Accessible.name: root.statusMessage
                    }

                    TextButton {
                        visible: root.installedTerminals.length === 0 && !root.loading
                        text: qsTr("Refresh")
                        type: TextButton.Tonal
                        enabled: !root.loading
                        onClicked: root.refresh()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Hornero keeps the terminal shortcut, XDG preference, Exo handler, and Shell app launches aligned. Install an alternative first, then return here to select it.")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}

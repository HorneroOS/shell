pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets

// Control Center › Extensions: community plugin lifecycle.
// horneroctl stays the single writer of plugin lifecycle state: this
// pane never writes receipts or payloads itself, it only invokes
// `horneroctl plugin enable|disable|trust <id> --yes` — the exact CLI
// commands — and re-reads state through the Plugins service. Enable
// (the direction that runs third-party QML as your user) requires an
// explicit inline confirmation, mirroring the CLI --yes gate.
// Install and remove stay CLI-only.
Item {
    id: root

    required property Session session

    property string pendingEnable: ""
    property string pendingTrust: ""
    property string pendingInstall: ""
    property string pendingCatalogAction: ""
    property string actionError: ""
    property var actionEnvelope: null
    property var catalogEntries: []
    property string catalogError: ""
    property string catalogRevision: ""
    property string catalogSearch: ""
    property string actionMessage: ""

    function filteredCatalogEntries(): var {
        const query = root.catalogSearch.trim().toLowerCase();
        if (!query)
            return root.catalogEntries;
        return root.catalogEntries.filter(entry => [entry.name, entry.description, entry.author, entry.category, entry.placement]
            .some(value => String(value || "").toLowerCase().includes(query)));
    }

    function declaredCapabilities(capabilities, verified): string {
        const declared = capabilities || {};
        const commands = Array.isArray(declared.processCommands) ? declared.processCommands : [];
        const hosts = Array.isArray(declared.networkHosts) ? declared.networkHosts : [];
        const settings = declared.settings && typeof declared.settings === "object" ? declared.settings : {};
        const settingsSummary = Object.keys(settings).sort().map(key => `${key}: ${JSON.stringify(settings[key])}`).join(", ");
        const provenance = verified === false
            ? qsTr("Unverified plugin-manifest declarations")
            : qsTr("Plugin-declared capabilities");
        return qsTr("%1\nProcess commands: %2\nNetwork hosts: %3\nSettings: %4")
            .arg(provenance)
            .arg(commands.length ? commands.join(", ") : qsTr("None declared"))
            .arg(hosts.length ? hosts.join(", ") : qsTr("None declared"))
            .arg(settingsSummary || qsTr("None declared"));
    }

    function refreshCatalog() {
        root.catalogError = "";
        root.catalogRevision = "";
        catalogProc.command = ["horneroctl", "--json", "plugin", "catalog"];
        catalogProc.running = true;
    }

    function runCatalogAction(action, pluginId) {
        root.actionError = "";
        root.actionMessage = "";
        catalogInstallProc.command = ["horneroctl", "--json", "plugin", "catalog", action, pluginId];
        if (action === "install" || action === "update")
            catalogInstallProc.command.push("--revision", root.catalogRevision);
        catalogInstallProc.command.push("--yes");
        catalogInstallProc.running = true;
    }

    function runLifecycle(action, pluginId) {
        root.actionError = "";
        root.actionEnvelope = null;
        lifecycleProc.command = ["horneroctl", "--json", "plugin", action, pluginId, "--yes"];
        lifecycleProc.running = true;
    }

    Process {
        id: lifecycleProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.actionEnvelope = JSON.parse(text);
                } catch (e) {
                    root.actionEnvelope = null;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const env = root.actionEnvelope;
            if (env && env.ok === true) {
                root.pendingEnable = "";
                root.pendingTrust = "";
                root.actionError = "";
                Plugins.reload();
            } else {
                root.actionError = (env && env.message) ? String(env.message) : qsTr("Plugin action failed (exit %1).").arg(exitCode);
            }
        }
    }

    Process {
        id: catalogProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                catalogProc.out += data;
            }
        }
        onStarted: catalogProc.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const env = JSON.parse(catalogProc.out.trim());
                if (env.ok === true) {
                    root.catalogEntries = JSON.parse((env.data && env.data.plugins) || "[]");
                    root.catalogRevision = (env.data && env.data.revision) ? String(env.data.revision) : "";
                } else {
                    root.catalogError = (env.message || "Catalogue unavailable").toString();
                }
            } catch (e) {
                root.catalogError = qsTr("Catalogue unavailable (network or horneroctl).");
            }
        }
    }

    Process {
        id: catalogInstallProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                catalogInstallProc.out += data;
            }
        }
        onStarted: catalogInstallProc.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const env = JSON.parse(catalogInstallProc.out.trim());
                if (env.ok === true) {
                    root.pendingInstall = "";
                    root.pendingCatalogAction = "";
                    const data = env.data || {};
                    root.actionMessage = [env.message || qsTr("Catalogue action completed."),
                        data.revision ? qsTr("Catalogue revision: %1").arg(data.revision) : "",
                        data.sha256 ? qsTr("Payload SHA-256: %1").arg(data.sha256) : ""]
                        .filter(Boolean).join("\n");
                    Plugins.reload();
                    root.refreshCatalog();
                } else {
                    root.actionError = (env.message || "Install failed").toString();
                }
            } catch (e) {
                root.actionError = qsTr("Install failed.");
            }
        }
    }

    Component.onCompleted: root.refreshCatalog()

    anchors.fill: parent

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
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

                StyledText {
                    text: qsTr("Extensions")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Every enabled QML plugin runs as your user without a sandbox. Command and network declarations come from each plugin's manifest and are not enforced permissions. Review a plugin's source before enabling it.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                TextButton {
                    text: qsTr("Reload plugin list")
                    type: TextButton.Tonal
                    onClicked: Plugins.reload()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.actionError.length > 0
                    text: root.actionError
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3error
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.actionMessage.length > 0
                    text: root.actionMessage
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3primary
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.discovered && Plugins.entries.length === 0
                    text: qsTr("No plugins installed. Add one with: horneroctl plugin install <path>")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: Plugins.entries

                    delegate: StyledRect {
                        id: row

                        required property var modelData

                        Layout.fillWidth: true
                        radius: Appearance.rounding.normal
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                        implicitHeight: rowCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: rowCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        text: `${row.modelData.name} ${row.modelData.version}`
                                        font.weight: 500
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData.placement ? qsTr("Placement: %1").arg(row.modelData.placement) : qsTr("No placement")
                                        font.pointSize: Appearance.font.size.small
                                        color: Colours.palette.m3onSurfaceVariant
                                        wrapMode: Text.Wrap
                                    }
                                }

                                StyledRect {
                                    Layout.preferredHeight: rowStateLabel.implicitHeight + 6
                                    Layout.preferredWidth: rowStateLabel.implicitWidth + 14
                                    radius: Appearance.rounding.full
                                    color: !row.modelData.enabled && !row.modelData.requestedEnabled ? Colours.palette.m3surfaceContainerHigh : row.modelData.state === "loaded" ? Colours.palette.m3primaryContainer : row.modelData.state === "failed" || row.modelData.state === "blocked" ? Colours.palette.m3errorContainer : Colours.palette.m3surfaceContainerHigh

                                    StyledText {
                                        id: rowStateLabel

                                        anchors.centerIn: parent
                                        text: !row.modelData.enabled && !row.modelData.requestedEnabled ? qsTr("Disabled") : row.modelData.state === "loaded" ? qsTr("Loaded") : row.modelData.state === "failed" ? qsTr("Failed") : row.modelData.state === "blocked" ? qsTr("Blocked") : qsTr("Pending")
                                        font.pointSize: Appearance.font.size.smaller
                                        font.weight: 600
                                        color: !row.modelData.enabled && !row.modelData.requestedEnabled ? Colours.palette.m3onSurfaceVariant : row.modelData.state === "loaded" ? Colours.palette.m3onPrimaryContainer : row.modelData.state === "failed" || row.modelData.state === "blocked" ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Trust: %1").arg(row.modelData.trust ?? qsTr("unknown"))
                                font.pointSize: Appearance.font.size.small
                                color: (["untrusted", "stale-trust", "modified", "unverified"].includes(row.modelData.trust)) ? Colours.palette.m3error : Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: row.modelData.source === "https://github.com/HorneroOS/plugins.git"
                                text: qsTr("Catalogue revision: %1\nExpected payload SHA-256: %2")
                                    .arg(row.modelData.revision || qsTr("Not recorded"))
                                    .arg(row.modelData.catalog_sha256 || qsTr("Not recorded"))
                                font.pointSize: Appearance.font.size.smaller
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingTrust === row.modelData.id
                                text: qsTr("You are trusting the exact code currently installed for this plugin. If its files change, you will be asked again. Trusting does not enable it.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!row.modelData.detail
                                text: row.modelData.detail ?? ""
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingEnable === row.modelData.id
                                text: qsTr("This plugin's QML will run as your user, without a sandbox. Enable only if you reviewed its source.\n%1")
                                    .arg(root.declaredCapabilities(row.modelData.capabilities, row.modelData.capabilities_verified))
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: row.modelData.placement === "desktop" ? Quickshell.screens : []

                                delegate: DesktopWidgetPosition {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    pluginId: row.modelData.id
                                    screenName: modelData.name
                                }
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: !row.modelData.enabled && (["untrusted", "stale-trust", "modified", "unverified"].includes(row.modelData.trust)) && root.pendingTrust !== row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Trust…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingTrust = row.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Confirm trust")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("trust", row.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingTrust = ""
                                }

                                TextButton {
                                    visible: !row.modelData.enabled && !row.modelData.requestedEnabled && root.pendingEnable !== row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Enable…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingEnable = row.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Confirm enable")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("enable", row.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingEnable = ""
                                }

                                TextButton {
                                    visible: row.modelData.enabled || row.modelData.requestedEnabled
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Disable")
                                    type: TextButton.Tonal
                                    onClicked: root.runLifecycle("disable", row.modelData.id)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: qsTr("Official catalogue — HorneroOS/plugins")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Official extensions from HorneroOS/plugins. Installing copies hash-verified, pinned data but does not run it. Enabling is a separate confirmed step. Capability lists describe plugin declarations; they do not restrict what QML can do.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogRevision.length > 0
                    text: qsTr("Catalogue revision: %1").arg(root.catalogRevision)
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                SearchBar {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search official extensions")
                    Accessible.name: qsTr("Search official extensions")
                    text: root.catalogSearch
                    onTextChanged: root.catalogSearch = text
                }

                TextButton {
                    text: qsTr("Refresh catalogue")
                    type: TextButton.Tonal
                    enabled: !catalogProc.running
                    onClicked: root.refreshCatalog()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogError.length > 0
                    text: root.catalogError
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3error
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogEntries.length > 0 && root.filteredCatalogEntries().length === 0
                    text: qsTr("No official extensions match this search.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.filteredCatalogEntries()

                    delegate: StyledRect {
                        id: catRow

                        required property var modelData

                        Layout.fillWidth: true
                        radius: Appearance.rounding.normal
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                        implicitHeight: catCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: catCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: `${catRow.modelData.name} ${catRow.modelData.version} · ${catRow.modelData.trust}`
                                font.weight: 500
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: catRow.modelData.description || qsTr("No description provided.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("By %1 · %2 · %3 · %4")
                                    .arg(catRow.modelData.author || qsTr("Unknown author"))
                                    .arg(catRow.modelData.license || qsTr("License not listed"))
                                    .arg(catRow.modelData.category || qsTr("Uncategorized"))
                                    .arg(catRow.modelData.placement || qsTr("Placement not listed"))
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.declaredCapabilities(catRow.modelData.capabilities)
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Source: %1\nPayload SHA-256: %2\nPlugin snapshot: %3")
                                    .arg(catRow.modelData.homepage || qsTr("Not listed"))
                                    .arg(catRow.modelData.sha256 || qsTr("Not listed"))
                                    .arg(catRow.modelData.generatedFrom || qsTr("Not listed"))
                                font.pointSize: Appearance.font.size.smaller
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("%1 · %2 · %3").arg(catRow.modelData.category || "").arg(catRow.modelData.placement || "").arg(catRow.modelData.state || "")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: catRow.modelData.state !== "installed" && root.pendingInstall !== catRow.modelData.id
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Install…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingInstall = catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Confirm install")
                                    type: TextButton.Filled
                                    onClicked: {
                                        root.runCatalogAction("install", catRow.modelData.id);
                                    }
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingInstall = ""
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && root.pendingCatalogAction !== "update:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Update…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "update:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Confirm update")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("update", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && catRow.modelData.rollback_available && root.pendingCatalogAction !== "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Roll back…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "rollback:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: catRow.modelData.rollback_available && root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Confirm rollback")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("rollback", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id || root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = ""
                                }

                                StyledText {
                                    visible: catRow.modelData.state === "installed"
                                    text: qsTr("Installed — enable it in the list above")
                                    font.pointSize: Appearance.font.size.small
                                    color: Colours.palette.m3outline
                                }
                            }
                        }
                    }
                }

                CommunityRegistrySection {
                    Layout.fillWidth: true
                }
            }
        }
    }
}

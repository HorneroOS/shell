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

    function refreshCatalog() {
        root.catalogError = "";
        catalogProc.command = ["horneroctl", "--json", "plugin", "catalog"];
        catalogProc.running = true;
    }

    function runCatalogAction(action, pluginId) {
        root.actionError = "";
        catalogInstallProc.command = ["horneroctl", "--json", "plugin", "catalog", action, pluginId, "--yes"];
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
                    text: qsTr("Community plugins run with your user's permissions — they are not sandboxed. Only enable plugins whose source you have reviewed. Enabling asks for confirmation here; install and remove stay in the CLI: horneroctl plugin install / remove")
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
                    visible: Plugins.discovered && Plugins.entries.length === 0
                    text: qsTr("No community plugins installed. Install one with: horneroctl plugin install <path>")
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

                            StyledText {
                                text: `${row.modelData.name} ${row.modelData.version}`
                                font.weight: 500
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.enabled ? qsTr("Enabled — state: %1").arg(row.modelData.state) : qsTr("Disabled")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Trust: %1").arg(row.modelData.trust ?? qsTr("unknown"))
                                font.pointSize: Appearance.font.size.small
                                color: (row.modelData.trust === "untrusted" || row.modelData.trust === "stale-trust") ? Colours.palette.m3error : Colours.palette.m3outline
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
                                text: qsTr("This plugin's QML will run as your user, without a sandbox. Enable only if you reviewed its source.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: !row.modelData.enabled && (row.modelData.trust === "untrusted" || row.modelData.trust === "stale-trust") && root.pendingTrust !== row.modelData.id
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
                                    visible: !row.modelData.enabled && root.pendingEnable !== row.modelData.id
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
                                    visible: row.modelData.enabled
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
                    text: qsTr("First-party extensions, hash-verified and pinned by the catalogue. Installing copies inert data; enabling stays a separate confirmed step above. Community plugins are not listed yet.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
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

                Repeater {
                    model: root.catalogEntries

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
                                text: qsTr("%1 · %2 · %3").arg(catRow.modelData.category || "").arg(catRow.modelData.placement || "").arg(catRow.modelData.state || "")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: catRow.modelData.state !== "installed" && root.pendingInstall !== catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Install…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingInstall = catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Confirm install")
                                    type: TextButton.Filled
                                    onClicked: {
                                        catalogInstallProc.command = ["horneroctl", "--json", "plugin", "catalog", "install", catRow.modelData.id, "--yes"];
                                        catalogInstallProc.running = true;
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
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Confirm update")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("update", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && root.pendingCatalogAction !== "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Roll back…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "rollback:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "rollback:" + catRow.modelData.id
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
            }
        }
    }
}

import "../components"
import qs.components
import qs.components.controls
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Community discovery uses only the verified, read-only horneroctl contract.
Item {
    id: root

    property var entries: []
    property string error: ""
    property string indexVersion: ""
    property string generatedFrom: ""
    property string search: ""

    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth

    function filteredEntries(): var {
        const query = root.search.trim().toLowerCase();
        if (!query)
            return root.entries;
        return root.entries.filter(entry => [entry.id, entry.repository, entry.revision, entry.sha256, entry.authorKeyFingerprint]
            .some(value => String(value || "").toLowerCase().includes(query)));
    }

    function refresh() {
        root.error = "";
        root.entries = [];
        root.indexVersion = "";
        root.generatedFrom = "";
        registryProc.command = ["horneroctl", "--json", "plugin", "community", "list"];
        registryProc.running = true;
    }

    Process {
        id: registryProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                registryProc.out += data;
            }
        }
        onStarted: registryProc.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const env = JSON.parse(registryProc.out.trim());
                const data = env && env.data && typeof env.data === "object" ? env.data : null;
                if (exitCode !== 0 || !env || env.ok !== true) {
                    root.error = (env && env.message) ? String(env.message) : qsTr("Community registry command failed (exit %1).").arg(exitCode);
                    return;
                }
                if (!data || typeof data.plugins !== "string" || typeof data.indexVersion !== "string"
                        || typeof data.generatedFrom !== "string") {
                    root.error = qsTr("Community registry returned an invalid response from horneroctl.");
                    return;
                }
                const entries = JSON.parse(data.plugins);
                if (Array.isArray(entries) && !entries.some(entry => !entry || typeof entry.id !== "string"
                        || typeof entry.repository !== "string" || typeof entry.revision !== "string"
                        || typeof entry.sha256 !== "string" || typeof entry.authorKeyFingerprint !== "string")) {
                    root.entries = entries;
                    root.indexVersion = data.indexVersion;
                    root.generatedFrom = data.generatedFrom;
                } else {
                    root.error = qsTr("Community registry returned entries with invalid provenance fields.");
                }
            } catch (e) {
                root.error = qsTr("Community registry unavailable. Check the network, signature, registry key, and horneroctl.");
            }
        }
    }

    Component.onCompleted: root.refresh()

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Community registry")
            font.pointSize: Appearance.font.size.large
            font.weight: 500
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("An index signature identifies who published the list. It does not mean HorneroOS reviewed the code or that the code is safe. Community QML runs with your user privileges and has no sandbox.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Read-only for now. Community install, update, and rollback are unavailable until horneroctl preserves the verified revision and payload hash through those actions.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.indexVersion.length > 0
            text: qsTr("Verified index v%1 · source snapshot %2").arg(root.indexVersion).arg(root.generatedFrom || qsTr("not recorded"))
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }

        SearchBar {
            Layout.fillWidth: true
            placeholderText: qsTr("Search verified community entries")
            Accessible.name: qsTr("Search verified community entries")
            text: root.search
            onTextChanged: root.search = text
        }

        TextButton {
            text: qsTr("Refresh community index")
            type: TextButton.Tonal
            enabled: !registryProc.running
            onClicked: root.refresh()
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.error.length > 0
            text: root.error
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3error
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.indexVersion.length > 0 && root.entries.length === 0
            text: qsTr("The verified community index has no entries.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.entries.length > 0 && root.filteredEntries().length === 0
            text: qsTr("No verified community entries match this search.")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.filteredEntries()

            delegate: StyledRect {
                id: communityRow

                required property var modelData

                Layout.fillWidth: true
                radius: Appearance.rounding.normal
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                implicitHeight: communityCol.implicitHeight + Appearance.padding.large * 2

                ColumnLayout {
                    id: communityCol

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: communityRow.modelData.id
                        font.weight: 500
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Source: %1").arg(communityRow.modelData.repository)
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3outline
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Pinned revision: %1\nPayload SHA-256: %2\nAuthor key fingerprint: %3")
                            .arg(communityRow.modelData.revision)
                            .arg(communityRow.modelData.sha256)
                            .arg(communityRow.modelData.authorKeyFingerprint)
                        font.pointSize: Appearance.font.size.smaller
                        color: Colours.palette.m3outline
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}

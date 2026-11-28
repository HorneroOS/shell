import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Optional workstation profiles picker for Welcome's "Set up your apps" step.
// Backed by `horneroctl --json store profiles` and `queue add` through Actions.
ColumnLayout {
    id: root

    property string selectedProfileId: ""
    property var selectedApps: ({})

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    function activeProfile(): var {
        const list = Actions.appProfiles || [];
        if (list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === root.selectedProfileId)
                return list[i];
        }
        return list[0];
    }

    function syncSelectedApps(profile: var): void {
        if (!profile || !Array.isArray(profile.apps)) {
            root.selectedApps = {};
            return;
        }
        const next = {};
        for (let i = 0; i < profile.apps.length; i++) {
            const a = profile.apps[i];
            next[a.id] = !a.optional;
        }
        root.selectedApps = next;
    }

    function toggleAppSelection(appId: string): void {
        const next = Object.assign({}, root.selectedApps);
        next[appId] = !(next[appId] === true);
        root.selectedApps = next;
    }

    function selectedAppIds(): var {
        const prof = root.activeProfile();
        if (!prof || !Array.isArray(prof.apps))
            return [];
        const out = [];
        for (let i = 0; i < prof.apps.length; i++) {
            const id = prof.apps[i].id;
            if (root.selectedApps[id] === true)
                out.push(id);
        }
        return out;
    }

    Component.onCompleted: {
        Actions.ensureAppProfiles();
        const prof = root.activeProfile();
        if (prof) {
            root.selectedProfileId = prof.id;
            root.syncSelectedApps(prof);
        }
    }

    Connections {
        target: Actions

        function onAppProfilesChanged(): void {
            const prof = root.activeProfile();
            if (prof && root.selectedProfileId === "") {
                root.selectedProfileId = prof.id;
                root.syncSelectedApps(prof);
            }
        }
    }

    StyledRect {
        visible: Actions.appProfilesLoading || Actions.appProfilesError !== "" || Actions.appsLastError !== "" || Actions.appsLastSuccess !== ""
        Layout.fillWidth: true
        implicitHeight: statusRow.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.small
        color: (Actions.appProfilesError !== "" || Actions.appsLastError !== "") ? Signal.palette.alertWell : (Actions.appsLastSuccess !== "" ? Signal.palette.phosphorWell : Signal.palette.panel)
        border.width: 1
        border.color: (Actions.appProfilesError !== "" || Actions.appsLastError !== "") ? Signal.palette.alert : (Actions.appsLastSuccess !== "" ? Signal.palette.phosphor : Signal.palette.rule)

        RowLayout {
            id: statusRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            Glyph {
                name: (Actions.appProfilesError !== "" || Actions.appsLastError !== "") ? "alert-circle" : (Actions.appsLastSuccess !== "" ? "circle-check" : "hourglass")
                color: (Actions.appProfilesError !== "" || Actions.appsLastError !== "") ? Signal.palette.onAlertWell : (Actions.appsLastSuccess !== "" ? Signal.palette.onPhosphorWell : Signal.palette.signal)
            }

            StyledText {
                Layout.fillWidth: true
                text: Actions.appsLastError !== "" ? Actions.appsLastError : (Actions.appsLastSuccess !== "" ? Actions.appsLastSuccess : (Actions.appProfilesError !== "" ? Actions.appProfilesError : qsTr("Loading workstation profiles…")))
                color: (Actions.appProfilesError !== "" || Actions.appsLastError !== "") ? Signal.palette.onAlertWell : (Actions.appsLastSuccess !== "" ? Signal.palette.onPhosphorWell : Signal.palette.ink)
                wrapMode: Text.WordWrap
            }

            TextButton {
                visible: Actions.appProfilesError !== "" && !Actions.appProfilesLoading
                text: qsTr("Retry")
                type: TextButton.Tonal
                onClicked: Actions.refreshAppProfiles()
            }
        }
    }

    Flow {
        visible: (Actions.appProfiles || []).length > 0
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: Actions.appProfiles || []

            delegate: ToggleButton {
                required property var modelData

                readonly property bool isCurrent: root.activeProfile() && root.activeProfile().id === modelData.id

                toggled: isCurrent
                icon: modelData.icon || "apps"
                label: modelData.name
                onClicked: {
                    root.selectedProfileId = modelData.id;
                    root.syncSelectedApps(modelData);
                }
            }
        }
    }

    StyledRect {
        visible: root.activeProfile() !== null
        Layout.fillWidth: true
        implicitHeight: profCol.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.small
        color: Signal.palette.panel
        border.width: 1
        border.color: Signal.palette.rule

        ColumnLayout {
            id: profCol

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: root.activeProfile() ? root.activeProfile().name : ""
                font.weight: Appearance.font.weight.strong
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.activeProfile() && root.activeProfile().description !== ""
                text: root.activeProfile() ? root.activeProfile().description : ""
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.smaller
                wrapMode: Text.WordWrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.activeProfile() ? root.activeProfile().apps : []

                    delegate: ToggleButton {
                        required property var modelData

                        readonly property bool checkedApp: root.selectedApps[modelData.id] === true

                        toggled: checkedApp
                        icon: checkedApp ? "square-check" : "square"
                        label: modelData.installed ? qsTr("%1 (Installed)").arg(modelData.name) : modelData.name
                        disabled: Actions.appsBusy
                        onClicked: root.toggleAppSelection(modelData.id)
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                TextButton {
                    text: Actions.appsBusy ? qsTr("Queueing…") : qsTr("Queue selected (%1)").arg(root.selectedAppIds().length)
                    disabled: Actions.appsBusy || root.selectedAppIds().length === 0
                    onClicked: Actions.queueAppIds(root.selectedAppIds())
                }

                TextButton {
                    text: qsTr("Open Queue in Hornero Apps")
                    type: TextButton.Tonal
                    onClicked: Actions.openApps("queue")
                }
            }
        }
    }
}

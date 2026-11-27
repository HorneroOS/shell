pragma ComponentBehavior: Bound

import ".."
import "../components"
import "../../../services/profiles.js" as Profiles
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center › Profiles: universal workspace profiles, snapshots,
// companion app launcher, and post-apply safety rollback.
// horneroctl is the single writer of profile state: every read and mutation
// invokes `horneroctl --json profile ...` with fixed argv arrays (no shell).
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property bool loading: true
    property bool busy: false
    property bool available: true
    property string statusError: ""
    property string actionError: ""
    property string actionSuccess: ""

    property string activeProfileId: ""
    property bool hasBaseline: false
    property bool hasPrevious: false
    property var profilesModel: []
    property var activeDetail: null
    property var diffData: null

    property bool postApplyBannerVisible: false
    property int postApplySeconds: 15
    property string postApplyProfileId: ""
    property bool postApplyPipewireRestarted: false
    property var postApplyMissingApps: []
    property var postApplyWarnings: []

    property string armedDeleteId: ""

    property string captureName: ""
    readonly property string captureSlug: Profiles.slugifyProfileId(root.captureName)
    property string captureDescription: ""
    property var captureDomains: ({
            "experience": true,
            "audio": true,
            "power": true,
            "extensions": true,
            "apps": true
        })

    function activeProfileObj(): var {
        for (let i = 0; i < root.profilesModel.length; i++) {
            if (root.profilesModel[i].id === root.activeProfileId)
                return root.profilesModel[i];
        }
        return null;
    }

    function activeMissingApps(): var {
        if (root.postApplyMissingApps.length > 0 && (root.postApplyProfileId === root.activeProfileId || root.activeProfileId === ""))
            return root.postApplyMissingApps;
        if (root.activeDetail && root.activeDetail.id === root.activeProfileId && root.activeDetail.missingApps.length > 0)
            return root.activeDetail.missingApps;
        const activeObj = root.activeProfileObj();
        if (activeObj && activeObj.missingApps && activeObj.missingApps.length > 0)
            return activeObj.missingApps;
        return [];
    }

    function activeMissingAppsTargetId(): string {
        if (root.postApplyMissingApps.length > 0 && root.postApplyProfileId.length > 0)
            return root.postApplyProfileId;
        return root.activeProfileId;
    }

    function domainLabel(domainId: string): string {
        if (domainId === "experience")
            return qsTr("Experience");
        if (domainId === "audio")
            return qsTr("Audio & Routing");
        if (domainId === "power")
            return qsTr("Power");
        if (domainId === "extensions")
            return qsTr("Extensions");
        if (domainId === "apps")
            return qsTr("Companion Apps");
        return domainId;
    }

    function selectedDomainsList(): var {
        const out = [];
        for (let i = 0; i < Profiles.PROFILE_DOMAINS.length; i++) {
            const id = Profiles.PROFILE_DOMAINS[i].id;
            if (root.captureDomains[id] === true)
                out.push(id);
        }
        return out;
    }

    function toggleCaptureDomain(domainId: string): void {
        const next = {};
        for (const k in root.captureDomains)
            next[k] = root.captureDomains[k];
        next[domainId] = !next[domainId];
        root.captureDomains = next;
    }

    function refresh(): void {
        if (listProc.running)
            return;
        root.loading = true;
        root.statusError = "";
        listProc.command = ["horneroctl", "--json", "profile", "list"];
        listProc.running = true;
    }

    function requestDiff(id: string, activateIfSafe: bool): void {
        if (root.busy || diffProc.running)
            return;
        root.actionError = "";
        root.actionSuccess = "";
        diffProc.activateIfSafe = activateIfSafe;
        diffProc.targetId = id;
        diffProc.command = ["horneroctl", "--json", "profile", "diff", id];
        diffProc.running = true;
    }

    function executeActivate(id: string): void {
        if (root.busy || id.length === 0)
            return;
        root.armedDeleteId = "";
        root.runMutation("apply", id, ["horneroctl", "--json", "profile", "apply", id, "--yes"]);
    }

    function revertProfile(): void {
        if (root.busy)
            return;
        postApplyTimer.stop();
        root.postApplyBannerVisible = false;
        root.armedDeleteId = "";
        root.runMutation("revert", "", ["horneroctl", "--json", "profile", "revert", "--yes"]);
    }

    function restoreBaseline(): void {
        if (root.busy)
            return;
        postApplyTimer.stop();
        root.postApplyBannerVisible = false;
        root.armedDeleteId = "";
        root.runMutation("restore-baseline", "baseline", ["horneroctl", "--json", "profile", "restore-baseline", "--yes"]);
    }

    function keepAppliedProfile(): void {
        postApplyTimer.stop();
        root.postApplyBannerVisible = false;
    }

    function launchMissingApps(profileId: string, appId: string): void {
        if (root.busy || profileId.length === 0)
            return;
        const argv = ["horneroctl", "--json", "profile", "launch-apps", profileId];
        if (appId.length > 0)
            argv.push("--app", appId);
        argv.push("--yes");
        root.runMutation("launch-apps", profileId, argv);
    }

    function captureSnapshot(): void {
        if (root.busy)
            return;
        const slug = root.captureSlug;
        const name = root.captureName.trim();
        const domains = root.selectedDomainsList();
        if (slug.length === 0 || name.length === 0 || domains.length === 0)
            return;
        const argv = ["horneroctl", "--json", "profile", "capture", slug, "--name", name];
        const desc = root.captureDescription.trim();
        if (desc.length > 0)
            argv.push("--description", desc);
        argv.push("--domains", domains.join(","), "--yes");
        root.runMutation("capture", slug, argv);
    }

    function deleteProfile(id: string): void {
        if (root.busy || id.length === 0 || id === "baseline")
            return;
        if (root.armedDeleteId !== id) {
            root.armedDeleteId = id;
            return;
        }
        root.armedDeleteId = "";
        root.runMutation("delete", id, ["horneroctl", "--json", "profile", "delete", id, "--yes"]);
    }

    function runMutation(kind: string, targetId: string, argv: var): void {
        if (root.busy || mutProc.running)
            return;
        root.busy = true;
        root.actionError = "";
        root.actionSuccess = "";
        mutProc.mutKind = kind;
        mutProc.targetId = targetId;
        mutProc.command = argv;
        mutProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Timer {
        id: postApplyTimer

        interval: 1000
        repeat: true
        running: root.postApplyBannerVisible && root.postApplySeconds > 0
        onTriggered: {
            if (root.postApplySeconds > 1) {
                root.postApplySeconds--;
            } else {
                root.postApplySeconds = 0;
                postApplyTimer.stop();
                root.postApplyBannerVisible = false;
            }
        }
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Profiles.parseProfileList(text);
                root.loading = false;
                root.available = res.available;
                root.activeProfileId = res.active;
                root.hasBaseline = res.hasBaseline;
                root.hasPrevious = res.hasPrevious;
                root.profilesModel = res.profiles;
                root.statusError = res.available ? "" : res.error;
                if (res.available && res.active.length > 0 && !showProc.running) {
                    showProc.command = ["horneroctl", "--json", "profile", "show", res.active];
                    showProc.running = true;
                } else if (res.active.length === 0) {
                    root.activeDetail = null;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.profilesModel.length === 0 && root.statusError.length === 0) {
                root.available = false;
                root.statusError = qsTr("Profile service unavailable (is horneroctl updated?).");
            }
        }
    }

    Process {
        id: showProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Profiles.parseProfileShow(text);
                root.activeDetail = res.available ? res : null;
            }
        }
    }

    Process {
        id: diffProc

        property bool activateIfSafe: false
        property string targetId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Profiles.parseProfileDiff(text);
                if (!res.available) {
                    root.actionError = res.error || qsTr("Could not preview profile changes.");
                    return;
                }
                if (diffProc.activateIfSafe && !res.willRestartPipewire && res.hardwareMissing.length === 0) {
                    root.executeActivate(res.id || diffProc.targetId);
                    return;
                }
                root.diffData = res;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && root.diffData === null && root.actionError.length === 0)
                root.actionError = qsTr("Could not preview profile diff (exit %1).").arg(exitCode);
        }
    }

    Process {
        id: mutProc

        property string mutKind: ""
        property string targetId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (mutProc.mutKind === "apply") {
                    const res = Profiles.parseProfileApply(text);
                    if (!res.ok) {
                        root.actionError = res.error || qsTr("Could not activate profile.");
                        return;
                    }
                    root.diffData = null;
                    root.postApplyProfileId = res.id || mutProc.targetId;
                    root.postApplyPipewireRestarted = res.pipewireRestarted;
                    root.postApplyMissingApps = res.missingApps;
                    root.postApplyWarnings = res.warnings;
                    root.postApplySeconds = 15;
                    root.postApplyBannerVisible = true;
                    postApplyTimer.restart();
                    root.actionSuccess = res.message || qsTr("Profile activated.");
                    return;
                }

                const applyLike = Profiles.parseProfileApply(text);
                if (!applyLike.ok) {
                    root.actionError = applyLike.error || qsTr("Profile action failed.");
                    return;
                }
                if (mutProc.mutKind === "capture") {
                    root.captureName = "";
                    root.captureDescription = "";
                    root.actionSuccess = applyLike.message || qsTr("Snapshot captured.");
                } else if (mutProc.mutKind === "revert" || mutProc.mutKind === "restore-baseline") {
                    root.postApplyBannerVisible = false;
                    root.postApplyMissingApps = [];
                    root.postApplyWarnings = [];
                    root.diffData = null;
                    root.actionSuccess = applyLike.message || qsTr("Profile restored.");
                } else if (mutProc.mutKind === "launch-apps") {
                    root.postApplyMissingApps = applyLike.missingApps;
                    root.actionSuccess = applyLike.message || qsTr("Companion apps launched.");
                } else if (mutProc.mutKind === "delete") {
                    if (root.diffData && root.diffData.id === mutProc.targetId)
                        root.diffData = null;
                    root.actionSuccess = applyLike.message || qsTr("Profile deleted.");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.actionError.length === 0 && root.actionSuccess.length === 0)
                    root.actionError = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.actionError.length === 0)
                root.actionError = qsTr("Profile action failed (exit %1).").arg(exitCode);
            root.refresh();
        }
    }

    StyledClippingRect {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: Appearance.rounding.small
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: contentLayout.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: contentLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: implicitHeight
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "profiles"
                    intro: qsTr("Capture and switch complete workspace snapshots across Experience, Audio & Routing, Power, Extensions, and Companion Apps.")
                }

                // ── (a) Active Profile & Safety Strip ─────────────────────────
                ChannelPanel {
                    title: qsTr("Active profile")
                    readoutAvailable: root.available
                    readout: {
                        if (!root.available)
                            return "";
                        const activeObj = root.activeProfileObj();
                        if (activeObj)
                            return activeObj.name;
                        return root.activeProfileId.length > 0 ? root.activeProfileId : qsTr("Custom / Unsaved");
                    }

                    SettingRow {
                        label: {
                            if (root.loading && root.profilesModel.length === 0)
                                return qsTr("Reading profiles…");
                            if (!root.available)
                                return qsTr("Profile service unavailable");
                            const activeObj = root.activeProfileObj();
                            if (activeObj)
                                return activeObj.name;
                            return root.activeProfileId.length > 0 ? root.activeProfileId : qsTr("Custom / Unsaved");
                        }
                        description: {
                            if (root.statusError.length > 0)
                                return root.statusError;
                            const activeObj = root.activeProfileObj();
                            if (activeObj && activeObj.description.length > 0)
                                return activeObj.description;
                            if (root.activeProfileId.length > 0)
                                return qsTr("ID: %1").arg(root.activeProfileId);
                            return qsTr("Current workspace has unsaved changes or no active profile.");
                        }

                        below: Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Revert to Previous")
                                type: TextButton.Tonal
                                disabled: !root.available || !root.hasPrevious || root.busy
                                onClicked: root.revertProfile()
                            }

                            TextButton {
                                text: qsTr("Restore Baseline")
                                type: TextButton.Tonal
                                disabled: !root.available || !root.hasBaseline || root.busy
                                onClicked: root.restoreBaseline()
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Text
                                disabled: root.busy || root.loading
                                onClicked: root.refresh()
                            }
                        }
                    }

                    SettingRow {
                        visible: root.actionError.length > 0 || root.actionSuccess.length > 0
                        label: root.actionError.length > 0 ? root.actionError : root.actionSuccess

                        StyledText {
                            text: root.actionError.length > 0 ? qsTr("Error") : qsTr("OK")
                            mono: true
                            font.pointSize: Appearance.font.size.small
                            color: root.actionError.length > 0 ? Signal.palette.alert : Signal.palette.phosphor
                        }
                    }
                }

                // ── (b) 15-second Post-Apply Safety Banner ────────────────────
                ChannelPanel {
                    visible: root.postApplyBannerVisible
                    title: qsTr("Safety check")
                    readout: qsTr("%1s").arg(root.postApplySeconds)
                    readoutColor: Signal.palette.signal

                    SettingRow {
                        label: qsTr("Profile applied. Revert in %1s if audio or layout feels wrong.").arg(root.postApplySeconds)
                        description: {
                            const parts = [];
                            if (root.postApplyPipewireRestarted)
                                parts.push(qsTr("PipeWire restarted during activation."));
                            for (let i = 0; i < root.postApplyWarnings.length; i++)
                                parts.push(root.postApplyWarnings[i]);
                            return parts.join(" ");
                        }

                        below: RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Keep")
                                disabled: root.busy
                                onClicked: root.keepAppliedProfile()
                            }

                            TextButton {
                                text: qsTr("Revert Now")
                                type: TextButton.Tonal
                                disabled: root.busy
                                onClicked: root.revertProfile()
                            }
                        }
                    }
                }

                // ── (c) Companion Apps Offer Banner ───────────────────────────
                ChannelPanel {
                    visible: root.activeMissingApps().length > 0
                    title: qsTr("Companion apps")
                    readout: qsTr("%1 not running").arg(root.activeMissingApps().length)
                    readoutColor: Signal.palette.signal

                    SettingRow {
                        readonly property var missingList: root.activeMissingApps()
                        readonly property string targetId: root.activeMissingAppsTargetId()

                        label: qsTr("This profile uses %1 app(s) that are not running: %2").arg(missingList.length).arg(missingList.map(a => a.name).join(", "))
                        description: qsTr("Launch missing apps in the background without leaving Settings.")

                        below: Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Launch missing apps")
                                disabled: root.busy
                                onClicked: root.launchMissingApps(root.activeMissingAppsTargetId(), "")
                            }

                            Repeater {
                                model: root.activeMissingApps()

                                delegate: TextButton {
                                    required property var modelData

                                    text: qsTr("Launch %1").arg(modelData.name)
                                    type: TextButton.Tonal
                                    disabled: root.busy
                                    onClicked: root.launchMissingApps(root.activeMissingAppsTargetId(), modelData.id)
                                }
                            }
                        }
                    }
                }

                // ── (f) Diff Preview Card ─────────────────────────────────────
                ChannelPanel {
                    visible: root.diffData !== null
                    title: qsTr("Profile preview")
                    readout: root.diffData ? root.diffData.id : ""

                    SettingRow {
                        visible: !!(root.diffData && root.diffData.willRestartPipewire)
                        label: qsTr("PipeWire restart required")
                        description: qsTr("Activating this profile will restart PipeWire briefly, which may interrupt active audio or calls.")

                        Glyph {
                            name: "alert-triangle"
                            color: Signal.palette.signal
                        }
                    }

                    SettingRow {
                        visible: !!(root.diffData && root.diffData.hardwareMissing && root.diffData.hardwareMissing.length > 0)
                        label: qsTr("Missing hardware detected")
                        description: root.diffData && root.diffData.hardwareMissing ? root.diffData.hardwareMissing.join(", ") : ""

                        Glyph {
                            name: "alert-triangle"
                            color: Signal.palette.signal
                        }
                    }

                    SettingRow {
                        visible: !!(root.diffData && root.diffData.missingApps && root.diffData.missingApps.length > 0)
                        label: qsTr("Companion apps not running")
                        description: root.diffData && root.diffData.missingApps ? root.diffData.missingApps.map(a => a.name).join(", ") : ""
                    }

                    Repeater {
                        model: root.diffData ? root.diffData.changes : []

                        delegate: SettingRow {
                            required property var modelData

                            label: {
                                if (modelData.summary && modelData.summary.length > 0)
                                    return modelData.summary;
                                const prefix = modelData.domain ? `[${root.domainLabel(modelData.domain)}] ` : "";
                                return prefix + (modelData.key || qsTr("Change"));
                            }
                            description: (modelData.from || modelData.to) ? `${modelData.from} → ${modelData.to}` : ""
                        }
                    }

                    SettingRow {
                        visible: !!(root.diffData && root.diffData.changes && root.diffData.changes.length === 0)
                        label: qsTr("No configuration differences reported.")
                    }

                    SettingRow {
                        label: root.diffData ? qsTr("Ready to switch to %1?").arg(root.diffData.name || root.diffData.id) : ""

                        below: RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Activate now")
                                disabled: root.busy || !root.diffData
                                onClicked: root.executeActivate(root.diffData.id)
                            }

                            TextButton {
                                text: qsTr("Cancel")
                                type: TextButton.Tonal
                                disabled: root.busy
                                onClicked: root.diffData = null
                            }
                        }
                    }
                }

                // ── (d) Capture Current State Card ────────────────────────────
                ChannelPanel {
                    title: qsTr("Capture current state")
                    readout: root.captureSlug.length > 0 ? root.captureSlug : ""

                    SettingRow {
                        label: qsTr("Profile name")
                        description: qsTr("Give this snapshot a clear name; its file-safe ID is generated automatically.")

                        below: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledInputField {
                                Layout.fillWidth: true
                                horizontalAlignment: TextInput.AlignLeft
                                text: root.captureName
                                enabled: !root.busy
                                Accessible.name: qsTr("Profile name")
                                onTextEdited: text => root.captureName = text
                            }

                            Well {
                                Layout.fillWidth: true
                                implicitHeight: slugText.implicitHeight + Appearance.padding.small * 2

                                StyledText {
                                    id: slugText

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.normal
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: root.captureSlug.length > 0 ? Signal.palette.ink : Signal.palette.inkMuted
                                    text: root.captureSlug.length > 0 ? qsTr("ID: %1").arg(root.captureSlug) : qsTr("Type a profile name above (e.g. Guitar + Discord)")
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    SettingRow {
                        label: qsTr("Description (optional)")

                        below: StyledInputField {
                            Layout.fillWidth: true
                            horizontalAlignment: TextInput.AlignLeft
                            text: root.captureDescription
                            enabled: !root.busy
                            Accessible.name: qsTr("Profile description")
                            onTextEdited: text => root.captureDescription = text
                        }
                    }

                    SettingRow {
                        label: qsTr("Domains to include")
                        description: qsTr("Choose which system domains this snapshot captures and restores.")

                        below: Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: Profiles.PROFILE_DOMAINS

                                delegate: ToggleButton {
                                    required property var modelData

                                    readonly property bool checkedDomain: root.captureDomains[modelData.id] === true

                                    toggled: checkedDomain
                                    icon: checkedDomain ? "square-check" : "square"
                                    label: root.domainLabel(modelData.id)
                                    accent: "signal"
                                    horizontalPadding: Appearance.padding.normal
                                    verticalPadding: Appearance.padding.smaller
                                    disabled: root.busy
                                    onClicked: root.toggleCaptureDomain(modelData.id)
                                }
                            }
                        }
                    }

                    SettingRow {
                        label: qsTr("Create snapshot")
                        description: qsTr("Reads current state via horneroctl and stores a portable profile.")

                        TextButton {
                            text: qsTr("Capture Snapshot")
                            disabled: !root.available || root.busy || root.captureSlug.length === 0 || root.selectedDomainsList().length === 0
                            onClicked: root.captureSnapshot()
                        }
                    }
                }

                // ── (e) Saved Profiles List ───────────────────────────────────
                ChannelPanel {
                    title: qsTr("Saved profiles")
                    readoutAvailable: root.available
                    readout: root.available ? qsTr("%1 profiles").arg(root.profilesModel.length) : ""

                    SettingRow {
                        visible: !root.loading && root.available && root.profilesModel.length === 0
                        label: qsTr("No profiles saved yet")
                        description: qsTr("Capture your first snapshot above to save your current setup.")
                    }

                    Repeater {
                        model: root.profilesModel

                        delegate: SettingRow {
                            id: profileRow

                            required property var modelData

                            readonly property bool isCurrent: modelData.id === root.activeProfileId
                            readonly property bool deleteArmed: root.armedDeleteId === modelData.id

                            label: modelData.name
                            description: {
                                const parts = [modelData.id];
                                if (modelData.description.length > 0)
                                    parts.push(modelData.description);
                                return parts.join(" · ");
                            }

                            OnAirChip {
                                visible: profileRow.isCurrent
                                text: qsTr("Active")
                            }

                            Well {
                                visible: profileRow.modelData.isBaseline
                                implicitWidth: baselineLbl.implicitWidth + Appearance.padding.normal
                                implicitHeight: 20

                                StyledText {
                                    id: baselineLbl

                                    anchors.centerIn: parent
                                    text: qsTr("Baseline")
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }

                            Well {
                                implicitWidth: hwRow.implicitWidth + Appearance.padding.normal
                                implicitHeight: 20
                                outline: profileRow.modelData.hardwareOk ? Signal.palette.phosphor : Signal.palette.signal

                                Row {
                                    id: hwRow

                                    anchors.centerIn: parent
                                    spacing: 4

                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: profileRow.modelData.hardwareOk ? "circle-check" : "alert-triangle"
                                        size: Appearance.font.size.small
                                        color: profileRow.modelData.hardwareOk ? Signal.palette.phosphor : Signal.palette.signal
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profileRow.modelData.hardwareOk ? qsTr("Hardware OK") : qsTr("Missing hardware")
                                        mono: true
                                        font.pointSize: Appearance.font.size.small
                                        color: profileRow.modelData.hardwareOk ? Signal.palette.phosphor : Signal.palette.signal
                                    }
                                }
                            }

                            Well {
                                visible: profileRow.modelData.appCount > 0
                                implicitWidth: appCountLbl.implicitWidth + Appearance.padding.normal
                                implicitHeight: 20

                                StyledText {
                                    id: appCountLbl

                                    anchors.centerIn: parent
                                    text: qsTr("Apps %1/%2").arg(profileRow.modelData.runningAppCount).arg(profileRow.modelData.appCount)
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }

                            below: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: !profileRow.modelData.hardwareOk && profileRow.modelData.hardwareMissing.length > 0
                                    text: qsTr("Missing hardware: %1").arg(profileRow.modelData.hardwareMissing.join(", "))
                                    color: Signal.palette.signal
                                    font.pointSize: Appearance.font.size.small
                                    wrapMode: Text.WordWrap
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    visible: profileRow.modelData.domains.length > 0
                                    spacing: Appearance.spacing.smaller

                                    Repeater {
                                        model: profileRow.modelData.domains

                                        delegate: Well {
                                            required property string modelData

                                            implicitWidth: domLbl.implicitWidth + Appearance.padding.normal
                                            implicitHeight: domLbl.implicitHeight + Appearance.padding.smaller

                                            StyledText {
                                                id: domLbl

                                                anchors.centerIn: parent
                                                text: root.domainLabel(modelData)
                                                font.pointSize: Appearance.font.size.small
                                                color: Signal.palette.inkMuted
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    TextButton {
                                        text: profileRow.isCurrent ? qsTr("Active") : qsTr("Activate")
                                        disabled: root.busy || profileRow.isCurrent
                                        onClicked: root.requestDiff(profileRow.modelData.id, true)
                                    }

                                    TextButton {
                                        text: qsTr("Preview diff")
                                        type: TextButton.Tonal
                                        disabled: root.busy
                                        onClicked: root.requestDiff(profileRow.modelData.id, false)
                                    }

                                    TextButton {
                                        visible: profileRow.modelData.appCount > 0
                                        text: qsTr("Launch apps")
                                        type: TextButton.Tonal
                                        disabled: root.busy
                                        onClicked: root.launchMissingApps(profileRow.modelData.id, "")
                                    }

                                    TextButton {
                                        visible: !profileRow.modelData.isBaseline
                                        text: profileRow.deleteArmed ? qsTr("Confirm delete") : qsTr("Delete")
                                        type: profileRow.deleteArmed ? TextButton.Filled : TextButton.Text
                                        disabled: root.busy
                                        onClicked: root.deleteProfile(profileRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

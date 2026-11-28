import "../../services/store.js" as Store
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// App Detail drawer/sheet inside Hornero Apps.
// Presents provenance, recommended vs alternative sources, sandbox/permissions,
// Wayland/GPU compatibility notes, proprietary/AUR consent gates, and error retry.
StyledRect {
    id: root

    required property var app
    property bool loading: false
    property string error: ""

    property string selectedSourceId: ""
    property bool proprietaryConfirmed: false
    property bool aurReviewConfirmed: false
    property bool removeArmed: false
    property bool guideExpanded: false

    readonly property var allSources: {
        const list = [];
        if (app && app.recommendedSource)
            list.push(app.recommendedSource);
        const alts = app && Array.isArray(app.alternativeSources) ? app.alternativeSources : [];
        for (let i = 0; i < alts.length; i++) {
            const s = alts[i];
            if (!s)
                continue;
            const dup = list.some(x => x.id === s.id && x.backend === s.backend);
            if (!dup)
                list.push(s);
        }
        return list;
    }

    readonly property var activeSource: {
        if (allSources.length === 0)
            return null;
        if (root.selectedSourceId !== "") {
            for (let i = 0; i < allSources.length; i++) {
                if (allSources[i].id === root.selectedSourceId || `${allSources[i].backend}:${allSources[i].id}` === root.selectedSourceId)
                    return allSources[i];
            }
        }
        return allSources[0];
    }

    readonly property string effectiveBackend: activeSource ? activeSource.backend : String(app ? app.backend : "")
    readonly property string effectiveProv: activeSource ? activeSource.provenance : String(app ? app.provenance : "")
    readonly property string provLabel: Store.provenanceLabel(effectiveProv)
    readonly property string provTone: Store.provenanceBadgeTone(effectiveProv)
    readonly property string actionKind: {
        if (!app)
            return "guide";
        if (activeSource && (activeSource.backend === "aur" || activeSource.provenance === "community_package"))
            return app.installed ? "open" : "aur_review";
        if (activeSource && (activeSource.backend === "webapp" || activeSource.provenance === "official_web_app"))
            return app.installed ? "open" : "webapp";
        if (activeSource && (activeSource.backend === "guided" || activeSource.provenance === "guided_setup_required"))
            return "guide";
        return Store.primaryActionKind(app, AppsStore.policy);
    }

    onAppChanged: {
        root.selectedSourceId = "";
        root.proprietaryConfirmed = false;
        root.aurReviewConfirmed = false;
        root.removeArmed = false;
        root.guideExpanded = false;
    }

    color: Signal.palette.base
    radius: Appearance.rounding.small
    border.width: 1
    border.color: Signal.palette.rule

    StyledFlickable {
        id: detailFlick

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailCol.implicitHeight
        clip: true

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: detailFlick
        }

        ColumnLayout {
            id: detailCol

            width: detailFlick.width
            spacing: Appearance.spacing.large

            // Top bar: Back button + Queue button
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                IconTextButton {
                    icon: "arrow-left"
                    text: qsTr("Back to catalog")
                    type: IconTextButton.Tonal
                    onClicked: AppsStore.clearSelectedApp()
                }

                Item {
                    Layout.fillWidth: true
                }

                IconTextButton {
                    visible: root.actionKind === "install" && !AppsStore.busy
                    icon: "playlist"
                    text: qsTr("Add to Queue")
                    type: IconTextButton.Text
                    onClicked: AppsStore.queueAdd([root.app.id])
                }
            }

            // Loading / Error banner
            StyledRect {
                visible: root.loading || root.error !== "" || AppsStore.lastError !== "" || AppsStore.lastSuccess !== ""
                Layout.fillWidth: true
                implicitHeight: bannerRow.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: (root.error !== "" || AppsStore.lastError !== "") ? Signal.palette.alertWell : (AppsStore.lastSuccess !== "" ? Signal.palette.phosphorWell : Signal.palette.panel)
                border.width: 1
                border.color: (root.error !== "" || AppsStore.lastError !== "") ? Signal.palette.alert : (AppsStore.lastSuccess !== "" ? Signal.palette.phosphor : Signal.palette.rule)

                RowLayout {
                    id: bannerRow

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    Glyph {
                        name: (root.error !== "" || AppsStore.lastError !== "") ? "alert-circle" : (AppsStore.lastSuccess !== "" ? "circle-check" : "hourglass")
                        color: (root.error !== "" || AppsStore.lastError !== "") ? Signal.palette.onAlertWell : (AppsStore.lastSuccess !== "" ? Signal.palette.onPhosphorWell : Signal.palette.signal)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.error !== "" ? root.error : (AppsStore.lastError !== "" ? AppsStore.lastError : (AppsStore.lastSuccess !== "" ? AppsStore.lastSuccess : qsTr("Loading application details…")))
                        color: (root.error !== "" || AppsStore.lastError !== "") ? Signal.palette.onAlertWell : (AppsStore.lastSuccess !== "" ? Signal.palette.onPhosphorWell : Signal.palette.ink)
                        wrapMode: Text.WordWrap
                    }

                    TextButton {
                        visible: (root.error !== "" || AppsStore.lastError !== "") && !AppsStore.busy
                        text: qsTr("Retry")
                        type: TextButton.Tonal
                        onClicked: {
                            if (AppsStore.lastError !== "")
                                AppsStore.retryLastAction();
                            else
                                AppsStore.loadAppDetail(root.app.id);
                        }
                    }
                }
            }

            // Header identity block
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + Appearance.padding.large * 2
                radius: Appearance.rounding.small
                color: Signal.palette.panel
                border.width: 1
                border.color: Signal.palette.rule

                RowLayout {
                    id: heroRow

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.large

                    StyledRect {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 68
                        radius: Appearance.rounding.small
                        color: Signal.palette.sunken
                        border.width: 1
                        border.color: Signal.palette.rule

                        IconImage {
                            anchors.centerIn: parent
                            visible: root.app && (root.app.icon || "") !== ""
                            source: (root.app && root.app.icon) ? Quickshell.iconPath(root.app.icon, "application-x-executable") : ""
                            implicitSize: 48
                            asynchronous: true
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !root.app || (root.app.icon || "") === ""
                            name: "apps"
                            color: Signal.palette.signal
                            font.pointSize: Appearance.font.size.extraLarge
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: root.app ? root.app.name : ""
                            font.family: Appearance.font.family.display
                            font.pointSize: Appearance.font.size.extraLarge
                            font.weight: Appearance.font.weight.strong
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.app && (root.app.publisher || "") !== ""
                            text: qsTr("By %1").arg(root.app ? root.app.publisher : "")
                            color: Signal.palette.inkMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.smaller

                            ProvenancePill {
                                text: root.provLabel
                                icon: root.provTone === "phosphor" ? "rosette-discount-check" : "info-circle"
                                tone: root.provTone
                            }

                            ProvenancePill {
                                text: Store.backendLabel(root.effectiveBackend)
                                tone: "muted"
                            }

                            ProvenancePill {
                                visible: root.app && (root.app.license || "") !== ""
                                text: root.app ? root.app.license : ""
                                tone: root.app && root.app.isOpenSource ? "phosphor" : "muted"
                            }

                            ProvenancePill {
                                visible: root.app && (root.app.pricing || "") !== ""
                                text: root.app ? root.app.pricing : ""
                                tone: "muted"
                            }

                            ProvenancePill {
                                visible: root.app && (root.app.stability || "") !== ""
                                text: root.app ? root.app.stability : ""
                                tone: "muted"
                            }
                        }
                    }
                }
            }

            // Primary Action & Consent Card
            SectionContainer {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    // Proprietary consent gate
                    StyledRect {
                        visible: root.app && root.app.isOpenSource === false && !root.app.installed && root.actionKind === "install"
                        Layout.fillWidth: true
                        implicitHeight: propRow.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.signalWell
                        border.width: 1
                        border.color: Signal.palette.signal

                        RowLayout {
                            id: propRow

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.normal

                            Glyph {
                                name: "info-circle"
                                color: Signal.palette.onSignalWell
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("This application is proprietary software (%1). Confirm below to acknowledge its license before installing.").arg(root.app && root.app.license ? root.app.license : qsTr("Proprietary"))
                                color: Signal.palette.onSignalWell
                                wrapMode: Text.WordWrap
                            }

                            ToggleButton {
                                toggled: root.proprietaryConfirmed
                                icon: root.proprietaryConfirmed ? "square-check" : "square"
                                label: qsTr("I accept")
                                onClicked: root.proprietaryConfirmed = !root.proprietaryConfirmed
                            }
                        }
                    }

                    // AUR PKGBUILD review warning
                    StyledRect {
                        visible: root.actionKind === "aur_review" && !root.app.installed
                        Layout.fillWidth: true
                        implicitHeight: aurCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.alertWell
                        border.width: 1
                        border.color: Signal.palette.alert

                        ColumnLayout {
                            id: aurCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Glyph {
                                    name: "alert-triangle"
                                    color: Signal.palette.onAlertWell
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Community AUR package — PKGBUILD review required")
                                    font.weight: Appearance.font.weight.strong
                                    color: Signal.palette.onAlertWell
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("AUR packages are community-maintained scripts built locally as your user (never as root). Inspect the PKGBUILD before confirming installation.")
                                color: Signal.palette.onAlertWell
                                font.pointSize: Appearance.font.size.smaller
                                wrapMode: Text.WordWrap
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: (root.app && root.app.pkgbuildUrl !== "") || (root.activeSource && root.activeSource.url !== "")
                                    text: qsTr("Review AUR PKGBUILD")
                                    type: TextButton.Tonal
                                    onClicked: AppsStore.openExternalUrl(root.app.pkgbuildUrl || root.activeSource.url)
                                }

                                ToggleButton {
                                    toggled: root.aurReviewConfirmed
                                    icon: root.aurReviewConfirmed ? "square-check" : "square"
                                    label: qsTr("I reviewed the PKGBUILD")
                                    onClicked: root.aurReviewConfirmed = !root.aurReviewConfirmed
                                }
                            }
                        }
                    }

                    // Action buttons row
                    Flow {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        IconTextButton {
                            visible: root.actionKind === "open"
                            icon: "player-play"
                            text: qsTr("Open")
                            onClicked: AppsStore.launchApp(root.app)
                        }

                        IconTextButton {
                            visible: root.actionKind === "update"
                            icon: "download"
                            text: AppsStore.busy ? AppsStore.activeJobLabel : qsTr("Update")
                            onClicked: {
                                if (!AppsStore.busy)
                                    AppsStore.updateApp(root.app.id);
                            }
                        }

                        IconTextButton {
                            visible: root.actionKind === "install"
                            icon: "download"
                            text: AppsStore.busy ? AppsStore.activeJobLabel : qsTr("Install")
                            onClicked: {
                                if (AppsStore.busy)
                                    return;
                                if (root.app && root.app.isOpenSource === false && !root.proprietaryConfirmed) {
                                    AppsStore.lastError = qsTr("Please confirm the proprietary license notice before installing.");
                                    return;
                                }
                                AppsStore.installApp(root.app.id, root.activeSource ? root.activeSource.id : "", root.proprietaryConfirmed, false);
                            }
                        }

                        IconTextButton {
                            visible: root.actionKind === "aur_review"
                            icon: "shield-lock"
                            text: AppsStore.busy ? AppsStore.activeJobLabel : (root.aurReviewConfirmed ? qsTr("Install from AUR") : qsTr("Review AUR PKGBUILD"))
                            type: root.aurReviewConfirmed ? IconTextButton.Filled : IconTextButton.Tonal
                            onClicked: {
                                if (AppsStore.busy)
                                    return;
                                if (!root.aurReviewConfirmed) {
                                    if (root.app && (root.app.pkgbuildUrl !== "" || (root.activeSource && root.activeSource.url !== "")))
                                        AppsStore.openExternalUrl(root.app.pkgbuildUrl || root.activeSource.url);
                                    else
                                        AppsStore.lastError = qsTr("Confirm that you reviewed the PKGBUILD first.");
                                    return;
                                }
                                if (root.app && root.app.isOpenSource === false && !root.proprietaryConfirmed) {
                                    AppsStore.lastError = qsTr("Please confirm the proprietary license notice before installing.");
                                    return;
                                }
                                AppsStore.installApp(root.app.id, root.activeSource ? root.activeSource.id : "", root.proprietaryConfirmed, true);
                            }
                        }

                        IconTextButton {
                            visible: root.actionKind === "webapp"
                            icon: "world"
                            text: qsTr("Open Web App")
                            onClicked: {
                                const url = (root.app && root.app.webAppUrl) ? root.app.webAppUrl : (root.activeSource ? root.activeSource.url : "");
                                if (url !== "")
                                    AppsStore.openExternalUrl(url);
                            }
                        }

                        IconTextButton {
                            visible: root.actionKind === "webapp" && !AppsStore.busy
                            icon: "plus"
                            text: qsTr("Pin as Isolated Web App")
                            type: IconTextButton.Tonal
                            onClicked: {
                                const url = (root.app && root.app.webAppUrl) ? root.app.webAppUrl : (root.activeSource ? root.activeSource.url : "");
                                if (url !== "")
                                    AppsStore.addWebApp(root.app.name, url, root.app.id);
                            }
                        }

                        IconTextButton {
                            visible: root.actionKind === "guide"
                            icon: "info-circle"
                            text: qsTr("View Setup Guide")
                            type: IconTextButton.Tonal
                            onClicked: root.guideExpanded = !root.guideExpanded
                        }

                        TextButton {
                            visible: root.actionKind === "policy_blocked"
                            text: qsTr("Blocked by software policy")
                            type: TextButton.Tonal
                            disabled: true
                        }

                        TextButton {
                            visible: root.app && root.app.installed && !AppsStore.busy
                            text: root.removeArmed ? qsTr("Confirm Remove") : qsTr("Remove")
                            type: root.removeArmed ? TextButton.Filled : TextButton.Tonal
                            onClicked: {
                                if (!root.removeArmed) {
                                    root.removeArmed = true;
                                    return;
                                }
                                root.removeArmed = false;
                                AppsStore.removeApp(root.app.id);
                            }
                        }
                    }

                    StyledText {
                        visible: root.app && root.app.installed
                        Layout.fillWidth: true
                        text: qsTr("User data is preserved: removing an application keeps your configuration and personal files intact.")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.smaller
                        wrapMode: Text.WordWrap
                    }

                    // Busy progress strip
                    RowLayout {
                        visible: AppsStore.busy
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        CircularIndicator {
                            running: AppsStore.busy
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: AppsStore.activeJobLabel || qsTr("Working…")
                            color: Signal.palette.signal
                        }
                    }

                    // Setup guide disclosure (for guided_setup_required)
                    StyledRect {
                        visible: root.guideExpanded || (root.actionKind === "guide" && root.app && root.app.setupGuide !== "")
                        Layout.fillWidth: true
                        implicitHeight: guideCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.sunken
                        border.width: 1
                        border.color: Signal.palette.rule

                        ColumnLayout {
                            id: guideCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.small

                            Eyebrow {
                                label: qsTr("Guided setup instructions")
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (root.app && root.app.setupGuide !== "") ? root.app.setupGuide : qsTr("This software requires vendor download or manual licensing outside automatic package repositories. Follow the official upstream guide.")
                                wrapMode: Text.WordWrap
                            }

                            TextButton {
                                visible: root.app && root.app.setupGuideUrl !== ""
                                text: qsTr("Open official instructions")
                                type: TextButton.Tonal
                                onClicked: AppsStore.openExternalUrl(root.app.setupGuideUrl)
                            }
                        }
                    }
                }
            }

            // Description & Compatibility Notes
            SectionContainer {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    Eyebrow {
                        label: qsTr("About this application")
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.app ? (root.app.description || root.app.summary || qsTr("No detailed description available.")) : ""
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        visible: root.app && (root.app.waylandNotes || "") !== ""
                        Layout.fillWidth: true
                        text: qsTr("Wayland support: %1").arg(root.app ? root.app.waylandNotes : "")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.smaller
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        visible: root.app && (root.app.gpuNotes || "") !== ""
                        Layout.fillWidth: true
                        text: qsTr("GPU & acceleration: %1").arg(root.app ? root.app.gpuNotes : "")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Recommended Source + Alternative Sources Switcher
            SectionContainer {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    Eyebrow {
                        label: qsTr("Recommended source & provenance")
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: recCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.sunken
                        border.width: 1
                        border.color: Signal.palette.rule

                        ColumnLayout {
                            id: recCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 via %2").arg(root.provLabel).arg(Store.backendLabel(root.effectiveBackend))
                                    font.weight: Appearance.font.weight.strong
                                }

                                ProvenancePill {
                                    visible: root.activeSource && root.activeSource.recommended
                                    text: qsTr("Recommended")
                                    tone: "phosphor"
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (root.activeSource && root.activeSource.reason !== "") ? root.activeSource.reason : qsTr("Selected by HorneroOS catalog policy for reliability, security updates, and native Wayland integration.")
                                color: Signal.palette.inkMuted
                                font.pointSize: Appearance.font.size.smaller
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                visible: root.activeSource && root.activeSource.packageName !== ""
                                Layout.fillWidth: true
                                mono: true
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                text: qsTr("Package / ref: %1").arg(root.activeSource ? root.activeSource.packageName : "")
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.allSources.length > 1
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Eyebrow {
                            label: qsTr("Alternative sources")
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: root.allSources

                                delegate: ToggleButton {
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: root.activeSource === modelData

                                    toggled: isSelected
                                    icon: modelData.recommended ? "rosette-discount-check" : "arrows-exchange"
                                    label: `${Store.backendLabel(modelData.backend)} (${Store.provenanceLabel(modelData.provenance)})`
                                    onClicked: {
                                        root.selectedSourceId = `${modelData.backend}:${modelData.id}`;
                                        root.aurReviewConfirmed = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Permissions & Sandbox Section
            SectionContainer {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        Eyebrow {
                            Layout.fillWidth: true
                            label: qsTr("Permissions & sandbox")
                        }

                        IconTextButton {
                            visible: root.effectiveBackend === "flatpak"
                            icon: "shield-lock"
                            text: qsTr("Manage in Flatseal")
                            type: IconTextButton.Tonal
                            onClicked: AppsStore.openFlatseal()
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (root.effectiveBackend === "appimage")
                                return qsTr("Not sandboxed by default. AppImages run directly under your user account; verify checksums and origin before launching.");
                            if (root.effectiveBackend === "flatpak")
                                return AppsStore.selectedPermissions.note !== "" ? AppsStore.selectedPermissions.note : qsTr("Sandboxed with Flatpak portals. Review or adjust filesystem, network, and device permissions in Flatseal.");
                            if (root.effectiveBackend === "webapp")
                                return qsTr("Runs inside an isolated browser application profile.");
                            if (root.app && root.app.sandboxNote !== "")
                                return root.app.sandboxNote;
                            return qsTr("Native package managed by pacman with standard user permissions.");
                        }
                        color: root.effectiveBackend === "appimage" ? Signal.palette.signal : Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    Flow {
                        visible: AppsStore.selectedPermissions.permissions.length > 0 || (root.app && root.app.permissions.length > 0)
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        Repeater {
                            model: AppsStore.selectedPermissions.permissions.length > 0 ? AppsStore.selectedPermissions.permissions : (root.app ? root.app.permissions : [])

                            delegate: ProvenancePill {
                                required property string modelData
                                text: modelData
                                tone: "muted"
                            }
                        }
                    }
                }
            }
        }
    }
}

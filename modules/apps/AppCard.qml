import "../../services/store.js" as Store
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Accessible Signal app card for Discover, AI & Agents, Categories, and Collections.
StyledRect {
    id: root

    required property var app
    property var policy: null

    signal selected(string appId)

    readonly property string provLabel: Store.provenanceLabel(app.provenance)
    readonly property string provTone: Store.provenanceBadgeTone(app.provenance)
    readonly property string bLabel: Store.backendLabel(app.backend)
    readonly property string statusText: Store.statusLabel(app.status)
    readonly property string translatedProv: {
        const p = String(app.provenance || "").toLowerCase();
        if (p === "vendor_official_repo" || p === "vendor_official_binary" || p === "vendor_official")
            return qsTr("Official Vendor");
        if (p === "arch_official")
            return qsTr("Arch Official");
        if (p === "hornero_official")
            return qsTr("Hornero Official");
        if (p === "flathub_verified")
            return qsTr("Flathub Verified");
        if (p === "flathub_community")
            return qsTr("Community Flathub");
        if (p === "community_package" || p === "aur")
            return qsTr("Community AUR");
        if (p === "official_web_app" || p === "webapp")
            return qsTr("Official Web App");
        if (p === "guided_setup_required" || p === "guided")
            return qsTr("Guided Setup");
        if (p === "appimage" || p === "local_appimage")
            return qsTr("Local AppImage");
        return qsTr("Unverified");
    }
    readonly property string translatedStatus: {
        if (app.updateAvailable)
            return qsTr("Update available");
        if (app.installed)
            return qsTr("Installed");
        const s = String(app.status || "").toLowerCase();
        if (s === "queued")
            return qsTr("Queued");
        if (s === "guided" || s === "guided_setup_required")
            return qsTr("Guided setup");
        if (Store.isAppBlockedByPolicy(app, root.policy))
            return qsTr("Blocked by policy");
        return qsTr("Available");
    }

    Accessible.role: Accessible.Button
    Accessible.name: `${app.name}, ${translatedProv}, ${translatedStatus}`
    Accessible.description: app.summary || ""
    Accessible.onPressAction: root.selected(app.id)

    implicitHeight: Math.max(128, cardLayout.implicitHeight + Appearance.padding.normal * 2)
    radius: Appearance.rounding.small
    color: cardInteractive.containsMouse ? Signal.palette.raised : Signal.palette.panel
    border.width: 1
    border.color: cardInteractive.activeFocus ? Signal.palette.focus : Signal.palette.rule

    Behavior on color {
        CAnim {}
    }

    Interactive {
        id: cardInteractive

        radius: root.radius
        showHoverBackground: false
        onClicked: root.selected(root.app.id)
    }

    ColumnLayout {
        id: cardLayout

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Appearance.rounding.small
                color: Signal.palette.sunken
                border.width: 1
                border.color: Signal.palette.rule

                IconImage {
                    id: appIconImg

                    anchors.centerIn: parent
                    readonly property string resolvedSource: {
                        const desktopIcon = DesktopEntries.byId(root.app.desktopId || root.app.id)?.icon || "";
                        const key = root.app.icon || desktopIcon || root.app.id || "";
                        return key !== "" ? Quickshell.iconPath(key, true) : "";
                    }
                    visible: resolvedSource !== ""
                    source: resolvedSource
                    implicitSize: 28
                    asynchronous: true
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: !appIconImg.visible
                    name: "apps"
                    color: Signal.palette.signal
                    font.pointSize: Appearance.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.app.name
                    font.weight: Appearance.font.weight.strong
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (root.app.publisher || "") !== ""
                    text: root.app.publisher
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.smaller
                    elide: Text.ElideRight
                }
            }

            ProvenancePill {
                visible: root.app.installed || root.app.updateAvailable
                text: root.translatedStatus
                icon: root.app.updateAvailable ? "download" : "circle-check"
                tone: root.app.updateAvailable ? "signal" : "phosphor"
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.app.summary || root.app.description || qsTr("No description provided.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            ProvenancePill {
                text: root.translatedProv
                icon: root.provTone === "phosphor" ? "rosette-discount-check" : (root.provTone === "alert" ? "alert-triangle" : "info-circle")
                tone: root.provTone
            }

            ProvenancePill {
                text: root.bLabel
                tone: "muted"
            }

            ProvenancePill {
                visible: root.app.isOpenSource === false
                text: qsTr("Proprietary")
                tone: "muted"
            }
        }
    }
}

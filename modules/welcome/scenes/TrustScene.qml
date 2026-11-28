pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.modules.welcome.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 08 — Trust ("A System You Can Trust"):
// Calm telemetry ledger calling real horneroctl diagnostics via TrustDiagnostics
// and AppsStore.doctorReport. Explicitly separates Hornero Config/Profile
// snapshots from OS Btrfs recovery readiness — never invents health scores.
Item {
    id: root

    property bool windowActive: true

    Component.onCompleted: {
        if (!TrustDiagnostics.probed && !TrustDiagnostics.loading)
            TrustDiagnostics.refresh();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: qsTr("DIAGNOSTICS & RECOVERY")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("A system you can trust")
                    font.pointSize: Appearance.font.size.extraLarge * 0.78
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Read-only telemetry from horneroctl. Config profiles and OS-level filesystem snapshots are tracked separately so nothing is overstated.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            TextButton {
                type: TextButton.Tonal
                text: TrustDiagnostics.loading ? qsTr("Checking…") : qsTr("Run Checks")
                disabled: TrustDiagnostics.loading
                onClicked: TrustDiagnostics.refresh()
            }
        }

        // 2-column honest telemetry ledger
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            // Left column: Health & Updates
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: 1
                border.color: Signal.palette.rule

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("System & Store Diagnostics")
                            font.pointSize: Appearance.font.size.large
                            font.weight: Appearance.font.weight.strong
                        }

                        AvailabilityPill {
                            availability: "probe-only"
                            available: TrustDiagnostics.doctorOk
                        }
                    }

                    Hairline { Layout.fillWidth: true }

                    StyledText {
                        Layout.fillWidth: true
                        text: TrustDiagnostics.loading
                            ? qsTr("Probing horneroctl doctor…")
                            : (TrustDiagnostics.doctorTotal > 0
                                ? qsTr("horneroctl doctor: %1 / %2 checks passed").arg(TrustDiagnostics.doctorPassed).arg(TrustDiagnostics.doctorTotal)
                                : (TrustDiagnostics.doctorSummary || qsTr("Doctor summary unavailable")))
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: TrustDiagnostics.horneroUpdates >= 0
                            ? qsTr("Pending updates: %1 Hornero package(s), %2 system package(s)").arg(TrustDiagnostics.horneroUpdates).arg(TrustDiagnostics.systemUpdates)
                            : qsTr("Package update probe pending or unavailable")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Actions.storeDoctor && Actions.storeDoctor.available
                            ? qsTr("Hornero Apps backend: Ready")
                            : qsTr("Hornero Apps backend: Checked on demand")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        TextButton {
                            type: TextButton.Tonal
                            text: qsTr("System Diagnostics")
                            onClicked: Actions.openControlCenter("system", false)
                        }

                        TextButton {
                            type: TextButton.Tonal
                            text: qsTr("Updates & Backups")
                            onClicked: Actions.openControlCenter("updates", false)
                        }
                    }
                }
            }

            // Right column: Profiles vs OS Btrfs Recovery Readiness
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: 1
                border.color: Signal.palette.rule

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Profiles & OS Recovery")
                            font.pointSize: Appearance.font.size.large
                            font.weight: Appearance.font.weight.strong
                        }

                        AvailabilityPill {
                            availability: TrustDiagnostics.btrfsReady ? "supported" : "probe-only"
                            available: TrustDiagnostics.btrfsReady
                        }
                    }

                    Hairline { Layout.fillWidth: true }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Universal Profiles saved: %1 (Baseline recorded: %2)")
                            .arg(TrustDiagnostics.profileCount)
                            .arg(TrustDiagnostics.hasBaselineProfile ? qsTr("Yes") : qsTr("No"))
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: btrfsCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: TrustDiagnostics.btrfsReady ? Signal.palette.phosphorWell : Signal.palette.sunken
                        border.width: 1
                        border.color: TrustDiagnostics.btrfsReady ? Signal.palette.phosphor : Signal.palette.ruleStrong

                        ColumnLayout {
                            id: btrfsCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: 4

                            StyledText {
                                text: TrustDiagnostics.btrfsReady
                                    ? qsTr("OS Btrfs Snapshots: Configured (%1)").arg(TrustDiagnostics.snapshotBackend)
                                    : qsTr("OS Btrfs Snapshots: Not configured (%1)").arg(TrustDiagnostics.rootFsType || qsTr("probe"))
                                font.weight: Appearance.font.weight.strong
                                color: TrustDiagnostics.btrfsReady ? Signal.palette.onPhosphorWell : Signal.palette.ink
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Config backups and Universal Profiles roll back Hornero settings only — they do not replace full OS filesystem snapshots.")
                                font.pointSize: Appearance.font.size.smaller
                                color: TrustDiagnostics.btrfsReady ? Signal.palette.onPhosphorWell : Signal.palette.inkMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    TextButton {
                        type: TextButton.Tonal
                        text: qsTr("Manage Universal Profiles")
                        onClicked: Actions.openControlCenter("profiles", false)
                    }
                }
            }
        }
    }
}

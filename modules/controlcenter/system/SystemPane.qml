pragma ComponentBehavior: Bound

import ".." as CC
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.components.misc
import qs.services
import qs.config
import qs.modules.welcome
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Qualified: `import qs.modules.welcome` below also brings a `Session`
    // name into scope (its singleton); unqualified, the loader's session
    // value fails assignment and the pane stays blank.
    required property CC.Session session

    anchors.fill: parent
    function run(command: var): void {
        if (Array.isArray(command) && command.length > 0) {
            Quickshell.execDetached(command);
            root.session.root.close();
        }
    }

    // Activate polling services while this pane is visible
    Ref {
        service: SystemUsage
    }

    Ref {
        service: NetworkUsage
    }

    // ── Reusable tile ────────────────────────────────────────────────────────
    component ActionTile: Item {
        id: tile

        required property string icon
        required property string label
        required property string description
        required property var action

        readonly property bool isFirst: tile.parent && tile.parent.children.length > 0 && tile.parent.children[0] === tile

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Appearance.padding.normal * 2

        Hairline {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !tile.isFirst
        }

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            spacing: Appearance.spacing.normal

            Glyph {
                Layout.minimumWidth: Appearance.font.size.extraLarge * 1.5
                Layout.preferredWidth: Appearance.font.size.extraLarge * 1.5
                Layout.maximumWidth: Appearance.font.size.extraLarge * 1.5
                Layout.alignment: Qt.AlignVCenter
                name: tile.icon
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.large
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: tile.label
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.description
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            ActionCell {
                text: qsTr("Run")
                type: TextButton.Tonal
                onClicked: tile.action()
            }
        }
    }

    // ── Stat row ─────────────────────────────────────────────────────────────
    component StatBar: Item {
        id: bar

        required property string label
        required property real value  // 0–1
        required property string detail

        readonly property bool isFirst: bar.parent && bar.parent.children.length > 0 && bar.parent.children[0] === bar

        Layout.fillWidth: true
        implicitHeight: barColumn.implicitHeight + Appearance.padding.normal * 2

        Hairline {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !bar.isFirst
        }

        ColumnLayout {
            id: barColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: bar.label
                    elide: Text.ElideRight
                }

                StyledText {
                    mono: true
                    text: bar.detail
                    font.pointSize: Appearance.font.size.small
                }
            }

            SegmentMeter {
                Layout.fillWidth: true
                implicitWidth: 0
                count: Math.max(8, Math.floor((width + gap) / (segmentThickness + gap)))
                segmentThickness: 6
                segmentLength: 10
                value: bar.value
                critical: -1
                accessibleName: bar.label
            }
        }
    }

    // ── Main layout ──────────────────────────────────────────────────────────
    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
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
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "system"
                }

                // ── Live stats ───────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Resources")

                    ColumnLayout {
                        id: statsCol

                        Layout.fillWidth: true
                        spacing: 0

                        StatBar {
                            label: SystemUsage.cpuName !== "" ? `CPU — ${SystemUsage.cpuName}` : qsTr("CPU")
                            value: SystemUsage.cpuPerc
                            detail: {
                                const pct = `${Math.round(SystemUsage.cpuPerc * 100)}%`;
                                return SystemUsage.cpuTemp > 0 ? `${pct} · ${Math.round(SystemUsage.cpuTemp)}°C` : pct;
                            }
                        }

                        StatBar {
                            visible: SystemUsage.gpuType !== "NONE"
                            label: SystemUsage.gpuName !== "" ? `GPU — ${SystemUsage.gpuName}` : qsTr("GPU")
                            value: SystemUsage.gpuPerc
                            detail: {
                                const pct = `${Math.round(SystemUsage.gpuPerc * 100)}%`;
                                return SystemUsage.gpuTemp > 0 ? `${pct} · ${Math.round(SystemUsage.gpuTemp)}°C` : pct;
                            }
                        }

                        StatBar {
                            label: qsTr("RAM")
                            value: SystemUsage.memPerc
                            detail: {
                                const used = SystemUsage.formatKib(SystemUsage.memUsed);
                                const total = SystemUsage.formatKib(SystemUsage.memTotal);
                                return `${used.value.toFixed(1)} / ${total.value.toFixed(1)} ${total.unit}`;
                            }
                        }

                        Repeater {
                            model: SystemUsage.disks

                            StatBar {
                                required property var modelData

                                label: qsTr("Disk — %1").arg(modelData.mount)
                                value: modelData.perc
                                detail: {
                                    const used = SystemUsage.formatKib(modelData.used);
                                    const total = SystemUsage.formatKib(modelData.total);
                                    return `${used.value.toFixed(1)} / ${total.value.toFixed(1)} ${total.unit}`;
                                }
                            }
                        }

                        StatBar {
                            visible: UPower.displayDevice.isLaptopBattery
                            label: UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge ? qsTr("Battery — Charging") : UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? qsTr("Battery — Full") : qsTr("Battery")
                            value: UPower.displayDevice.percentage
                            detail: {
                                const pct = `${Math.round(UPower.displayDevice.percentage * 100)}%`;
                                const s = UPower.displayDevice.timeToEmpty;
                                if (s > 0)
                                    return `${pct} · ~${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
                                return pct;
                            }
                        }

                        StatBar {
                            readonly property real dl: NetworkUsage.downloadSpeed
                            readonly property real ul: NetworkUsage.uploadSpeed

                            function fmtSpeed(bps: real): string {
                                const fmt = NetworkUsage.formatBytes(bps);
                                return `${fmt.value.toFixed(1)} ${fmt.unit}`;
                            }

                            label: qsTr("Network")
                            value: Math.min(dl / 125000000, 1)
                            detail: `↓ ${fmtSpeed(dl)}  ↑ ${fmtSpeed(ul)}`
                        }
                    }
                }

                // ── Actions ──────────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Quick actions")

                    ColumnLayout {
                        id: actionsCol

                        Layout.fillWidth: true
                        spacing: 0

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "hand-stop"
                            label: qsTr("Hornero Welcome")
                            description: qsTr("Open the Welcome Center tour")
                            action: () => Welcome.open("start")
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "lock"
                            label: qsTr("Lock screen")
                            description: qsTr("Activate the configured lock screen immediately")
                            action: () => root.run(["horneroctl", "lock", "now", "--yes"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "screenshot"
                            label: qsTr("Screenshot")
                            description: qsTr("Capture the screen with selection")
                            action: () => root.run(["horneroctl", "capture", "screenshot", "--region", "--yes"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "point"
                            label: qsTr("Screen recorder")
                            description: qsTr("Open GPU screen recorder")
                            action: () => root.run(["gsr-ui", "launch-hide-announce"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "clipboard"
                            label: qsTr("Clipboard")
                            description: qsTr("Open clipboard history")
                            action: () => root.run(["copyq", "show"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "moon"
                            label: qsTr("Night mode")
                            description: qsTr("Toggle blue-light filter")
                            action: () => root.run(["horneroctl", "appearance", "night-mode", "toggle", "--yes"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "download"
                            label: qsTr("System updates")
                            description: qsTr("Pending updates and backups")
                            action: () => Actions.openControlCenter("updates")
                        }
                    }
                }

                // ── Tools ────────────────────────────────────────────────────
                ChannelPanel {
                    title: qsTr("Tools")

                    ColumnLayout {
                        id: toolsCol

                        Layout.fillWidth: true
                        spacing: 0

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "device-desktop"
                            label: qsTr("Monitor layout")
                            description: qsTr("Configure display arrangement")
                            action: () => root.run(["nwg-displays"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "bolt"
                            label: qsTr("Performance profile")
                            description: qsTr("CPU frequency and power mode")
                            action: () => root.run(["auto-cpufreq-gtk"])
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "palette"
                            label: qsTr("GTK theme")
                            description: qsTr("Open Appearance to pick GTK theme and icons")
                            action: () => Actions.openControlCenter("appearance")
                        }

                        ActionTile {
                            Layout.fillWidth: true
                            icon: "keyboard"
                            label: qsTr("Keyboard shortcuts")
                            description: qsTr("Show current keybinding reference")
                            action: () => root.run(["horneroctl", "hardware", "keyboard", "keys"])
                        }
                    }
                }

                // ── Diagnostics (read-only horneroctl probes) ────────────
                ChannelPanel {
                    title: qsTr("Diagnostics")
                    readout: qsTr("read-only")

                    SettingRow {
                        label: qsTr("Run on demand")
                        description: qsTr("All checks are read-only; nothing is changed or fixed from here.")
                    }
                }

                CtlCard {
                    title: qsTr("Environment doctor")
                    description: qsTr("Session, compositor, terminal and shell-config health")
                    probeArgv: ["horneroctl", "--json", "doctor"]
                }

                CtlCard {
                    title: qsTr("Config validation")
                    description: qsTr("Shell config syntax and config paths")
                    probeArgv: ["horneroctl", "--json", "config", "validate"]
                }

                CtlCard {
                    title: qsTr("System info")
                    description: qsTr("Installed edition and active compositor")
                    probeArgv: ["horneroctl", "--json", "system", "info"]
                }

                CtlCard {
                    title: qsTr("Shell status")
                    description: qsTr("Quickshell CLI, config and compositor wiring")
                    probeArgv: ["horneroctl", "--json", "shell", "status"]
                }

                CtlCard {
                    title: qsTr("Recent shell logs")
                    description: qsTr("Last 20 shell log lines (read-only)")
                    probeArgv: ["horneroctl", "--json", "shell", "logs", "--lines", "20"]
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}

pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.config
import qs.services
import qs.modules.layoutpicker
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

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
                spacing: Appearance.spacing.normal

                PaneHeader {
                    paneId: "layout"
                }

                // Readout of what the preset catalogue says is live. Real
                // data only: with no catalogue (horneroctl missing) it says
                // so instead of showing a stale name.
                Well {
                    Layout.fillWidth: true
                    implicitHeight: readout.implicitHeight + Appearance.padding.normal * 2

                    RowLayout {
                        id: readout

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Eyebrow {
                            label: qsTr("Active layout")
                        }

                        StyledText {
                            Layout.fillWidth: true
                            mono: true
                            text: grid.count === 0 ? qsTr("Catalogue unavailable") : grid.currentPreset ? `${grid.currentPreset.display} · ${grid.topologyLabel(grid.currentPreset)}` : qsTr("Custom (no catalogue preset matches)")
                            font.pointSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            mono: true
                            visible: grid.count > 0
                            text: qsTr("%1 presets").arg(grid.count)
                            color: Signal.palette.inkMuted
                            font.pointSize: Appearance.font.size.small
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Pick a bar arrangement. It applies instantly, no restart needed. Presets marked “After” credit the project that inspired them.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.small
                    color: Signal.layer(Signal.palette.panel, 1)
                    implicitHeight: grid.implicitHeight + Appearance.padding.large * 2

                    PresetGrid {
                        id: grid

                        anchors.centerIn: parent
                        availableWidth: parent.width - Appearance.padding.large * 2
                    }
                }

                ClearStyleRow {
                    Layout.fillWidth: true
                }

                LayoutTweaksRow {
                    Layout.fillWidth: true
                    layoutId: grid.currentPreset?.name ?? ""
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Tip: Super+Shift+B opens the quick layout picker")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.layer(Signal.palette.inkMuted, 2)
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

pragma ComponentBehavior: Bound

import ".."
import "../effects"
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Elevation {
    id: root

    property list<MenuItem> items
    property MenuItem active: items[0] ?? null
    property bool expanded

    signal itemSelected(item: MenuItem)

    // Single tab stop while open; items stay mouse-driven (roving
    // active index, not N tab stops). Escape closes before the S3
    // drawer cascade (inner-state-first); focus entering on open
    // preserves the trigger's input modality.
    activeFocusOnTab: root.expanded

    property bool internalProgrammaticFocus
    onExpandedChanged: {
        if (expanded) {
            // Entering on open preserves the trigger's modality
            // (mouse-opened menus show no ring); Tab arrivals report
            // keyboard below.
            root.internalProgrammaticFocus = true;
            root.forceActiveFocus();
        }
    }
    onActiveFocusChanged: {
        if (activeFocus) {
            if (root.internalProgrammaticFocus)
                root.internalProgrammaticFocus = false;
            else
                FocusMode.reportFocus(false);
        }
    }

    function moveActive(delta: int): void {
        if (root.items.length === 0)
            return;
        const i = root.items.indexOf(root.active);
        const next = (i < 0 ? (delta > 0 ? 0 : root.items.length - 1) : (i + delta + root.items.length) % root.items.length);
        root.active = root.items[next];
    }

    function selectActive(): void {
        if (root.active) {
            root.itemSelected(root.active);
            root.expanded = false;
        }
    }

    Keys.onUpPressed: {
        if (root.expanded)
            root.moveActive(-1);
    }
    Keys.onDownPressed: {
        if (root.expanded)
            root.moveActive(1);
    }
    Keys.onReturnPressed: {
        if (root.expanded)
            root.selectActive();
    }
    Keys.onEnterPressed: {
        if (root.expanded)
            root.selectActive();
    }
    Keys.onSpacePressed: {
        if (root.expanded)
            root.selectActive();
    }
    Keys.onEscapePressed: event => {
        if (root.expanded) {
            root.expanded = false;
            event.accepted = true;
        }
    }

    radius: Appearance.rounding.small / 2
    level: 2

    implicitWidth: Math.max(200, column.implicitWidth)
    implicitHeight: root.expanded ? column.implicitHeight : 0
    opacity: root.expanded ? 1 : 0

    StyledClippingRect {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.palette.m3surfaceContainer

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: root.items

                StyledRect {
                    id: item

                    required property int index
                    required property MenuItem modelData
                    readonly property bool active: modelData === root.active

                    Layout.fillWidth: true
                    implicitWidth: menuOptionRow.implicitWidth + Appearance.padding.normal * 2
                    implicitHeight: menuOptionRow.implicitHeight + Appearance.padding.normal * 2

                    color: Qt.alpha(Colours.palette.m3secondaryContainer, active ? 1 : 0)

                    StateLayer {
                        color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        disabled: !root.expanded

                        function onClicked(): void {
                            root.itemSelected(item.modelData);
                            root.active = item.modelData;
                            root.expanded = false;
                        }
                    }

                    RowLayout {
                        id: menuOptionRow

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            text: item.modelData.icon
                            color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            text: item.modelData.text
                            color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }

                        Loader {
                            Layout.alignment: Qt.AlignVCenter
                            active: item.modelData.trailingIcon.length > 0
                            visible: active

                            sourceComponent: MaterialIcon {
                                text: item.modelData.trailingIcon
                                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    FocusRing {
        radius: root.radius + 2
    }
}

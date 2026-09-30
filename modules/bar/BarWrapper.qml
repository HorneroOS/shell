pragma ComponentBehavior: Bound

import qs.components
import qs.config
import "popouts" as BarPopouts
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    required property bool disabled
    required property bool frameVisible
    // Resolved bar spec (Config.bar.barsFor): edge, style, reserve, margin,
    // thickness, density, groups.
    required property var spec

    readonly property string screenName: screen.name
    readonly property string position: spec.edge
    readonly property string style: spec.style
    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool floating: style !== "attached"
    readonly property bool reserves: spec.reserve
    readonly property int frameInset: frameVisible ? Config.border.thickness : 0
    readonly property int padding: Math.max(Appearance.padding.smaller, Config.border.thickness)
    // Gap between a floating pill and the screen edge; part of the strip so
    // the reservation and panel insets include it.
    readonly property int gap: floating ? spec.margin : 0
    // Size of the bar across its screen edge (including the float gap)
    readonly property int thickness: spec.thickness + padding * 2 + gap
    readonly property int contentWidth: thickness // kept for external references
    readonly property int exclusiveZone: reserves && !disabled && (Config.bar.persistent || visibilities.bar) ? thickness : frameInset
    readonly property bool shouldBeVisible: !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    clip: true

    // Animated size along the bar's main axis
    readonly property int currentThickness: vertical ? implicitWidth : implicitHeight
    readonly property Item visualItem: content.item?.visualItem ?? null
    readonly property real visualX: x + (visualItem?.x ?? 0)
    readonly property real visualY: y + (visualItem?.y ?? 0)
    readonly property real visualWidth: visualItem?.width ?? 0
    readonly property real visualHeight: visualItem?.height ?? 0
    // Every visible island, in the parent's (drawers window) coordinates
    readonly property var visualRects: visible ? (content.item?.visualRects ?? []).map(r => ({
                x: x + r.x,
                y: y + r.y,
                width: r.width,
                height: r.height
            })) : []

    // Shell panels avoid the visible bar even when a floating bar overlays clients.
    readonly property int marginLeft: position === "left" ? currentThickness : frameInset
    readonly property int marginRight: position === "right" ? currentThickness : frameInset
    readonly property int marginTop: position === "top" ? currentThickness : frameInset
    readonly property int marginBottom: position === "bottom" ? currentThickness : frameInset

    // Layer-shell reservations are independent from shell panel placement.
    readonly property int reservedLeft: position === "left" ? exclusiveZone : frameInset
    readonly property int reservedRight: position === "right" ? exclusiveZone : frameInset
    readonly property int reservedTop: position === "top" ? exclusiveZone : frameInset
    readonly property int reservedBottom: position === "bottom" ? exclusiveZone : frameInset

    function containsVisualPoint(px: real, py: real): bool {
        if (!root.visible || !content.item)
            return false;
        return content.item.containsPoint(px - x, py - y);
    }

    function closeTray(): void {
        content.item?.closeTray();
    }

    function checkPopoutAt(px: real, py: real): void {
        content.item?.checkPopoutAt(px - x, py - y);
    }

    function handleWheelAt(px: real, py: real, angleDelta: point): void {
        content.item?.handleWheelAt(px - x, py - y, angleDelta);
    }

    visible: (vertical ? width : height) > frameInset
    implicitWidth: frameInset
    implicitHeight: frameInset

    states: [
        State {
            name: "visibleV"
            when: root.vertical && root.shouldBeVisible

            PropertyChanges {
                root.implicitWidth: root.thickness
            }
        },
        State {
            name: "visibleH"
            when: !root.vertical && root.shouldBeVisible

            PropertyChanges {
                root.implicitHeight: root.thickness
            }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "visibleV,visibleH"

            Anim {
                target: root
                properties: "implicitWidth,implicitHeight"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "visibleV,visibleH"
            to: ""

            Anim {
                target: root
                properties: "implicitWidth,implicitHeight"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Loader {
        id: content

        // The bar always fills the wrapper (which is the edge strip). Bar.qml
        // positions its inner "pill" itself, which keeps anchors static and
        // avoids anchor conflicts during live config reloads.
        anchors.fill: parent

        active: root.shouldBeVisible || root.visible

        sourceComponent: Bar {
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
            spec: root.spec
        }
    }
}

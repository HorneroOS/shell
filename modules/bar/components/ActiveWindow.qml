pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import QtQuick

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    Accessible.role: Accessible.StaticText
    Accessible.name: Compositor.activeWindowTitle || qsTr("Desktop")
    Accessible.description: Compositor.activeWindowAppId || qsTr("Current window")

    readonly property bool vertical: bar.vertical
    readonly property bool compactRail: vertical && Config.bar.popouts.activeWindow

    readonly property int maxLength: {
        const children = bar.container.children;
        const otherModules = children.filter(c => c.id && c.item !== this && c.id !== "spacer");
        const otherLength = otherModules.reduce((acc, curr) => acc + ((root.vertical ? curr.item.nonAnimHeight : curr.item.nonAnimWidth) ?? (root.vertical ? curr.height : curr.width)), 0);
        // Length - 1 cause repeater counts as a child
        return (root.vertical ? bar.height : bar.width) - otherLength - Appearance.spacing.normal * (children.length - 1) - bar.vPadding * 2;
    }
    property Title current: text1

    clip: true
    // A rail has little room for a rotated window title. Its icon identifies
    // the app; hover opens the adjacent window-info card with the full title
    // and live preview. Keep titles inline on horizontal bars.
    implicitWidth: {
        if (root.compactRail)
            return Config.bar.sizes.innerWidth;
        if (root.vertical)
            return Math.max(icon.implicitWidth, current.implicitHeight);
        return icon.implicitWidth + current.implicitWidth + current.anchors.leftMargin;
    }
    implicitHeight: {
        if (root.compactRail)
            return Config.bar.sizes.innerWidth;
        if (root.vertical)
            return icon.implicitHeight + current.implicitWidth + current.anchors.topMargin;
        return Math.max(icon.implicitHeight, current.implicitHeight);
    }

    Item {
        id: icon

        implicitWidth: root.compactRail ? Config.bar.sizes.innerWidth : glyph.implicitWidth
        implicitHeight: root.compactRail ? Config.bar.sizes.innerWidth : glyph.implicitHeight
        width: implicitWidth
        height: implicitHeight
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? (root.compactRail ? parent.verticalCenter : undefined) : parent.verticalCenter

        MaterialIcon {
            id: glyph

            anchors.centerIn: parent
            animate: true
            text: Icons.getAppCategoryIcon(Compositor.activeWindowAppId, "desktop_windows")
            color: root.colour
        }
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        readonly property string rawTitle: Compositor.activeWindowTitle || qsTr("Desktop")
        readonly property string compactTitle: {
            const idx = Math.max(rawTitle.lastIndexOf(" — "), rawTitle.lastIndexOf(" - "), rawTitle.lastIndexOf(" – "));
            return idx > 0 ? rawTitle.slice(idx + 3).trim() : rawTitle;
        }
        text: Config.bar.activeWindow.compact ? compactTitle : rawTitle
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        elide: Qt.ElideRight
        elideWidth: root.maxLength - (root.vertical ? icon.height : icon.width + Appearance.spacing.small)

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    component Title: StyledText {
        id: text

        anchors.horizontalCenter: root.vertical ? icon.horizontalCenter : undefined
        anchors.top: root.vertical ? icon.bottom : undefined
        anchors.topMargin: Appearance.spacing.small
        anchors.verticalCenter: root.vertical ? undefined : icon.verticalCenter
        anchors.left: root.vertical ? undefined : icon.right
        anchors.leftMargin: Appearance.spacing.small

        font.pointSize: metrics.font.pointSize
        font.family: metrics.font.family
        color: root.colour
        opacity: root.current === this ? 1 : 0
        visible: !root.compactRail

        transform: root.vertical ? [vertTranslate, vertRotation] : []

        width: root.vertical ? implicitHeight : implicitWidth
        height: root.vertical ? implicitWidth : implicitHeight

        Translate {
            id: vertTranslate

            x: Config.bar.activeWindow.inverted ? -text.implicitWidth + text.implicitHeight : 0
        }

        Rotation {
            id: vertRotation

            angle: Config.bar.activeWindow.inverted ? 270 : 90
            origin.x: text.implicitHeight / 2
            origin.y: text.implicitHeight / 2
        }

        Behavior on opacity {
            Anim {}
        }
    }
}

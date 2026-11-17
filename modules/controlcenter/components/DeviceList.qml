pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    // DeviceList is frequently placed directly inside a Flickable rather than
    // a parent Layout. Preserve the content size for the Flickable viewport.
    height: implicitHeight

    property Session session: null
    property var model: null
    property Component delegate: null

    property string title: ""
    property string description: ""
    property var activeItem: null
    property Component headerComponent: null
    property Component titleSuffix: null
    property bool showHeader: true

    signal itemSelected(var item)

    spacing: Appearance.spacing.small

    Loader {
        id: headerLoader

        Layout.fillWidth: true
        sourceComponent: root.headerComponent
        visible: root.headerComponent !== null && root.showHeader
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: root.headerComponent ? 0 : 0
        spacing: Appearance.spacing.small
        visible: root.title !== "" || root.description !== ""

        Eyebrow {
            visible: root.title !== ""
            label: root.title
            color: Signal.palette.ink
            Accessible.ignored: false
            Accessible.role: Accessible.Heading
            Accessible.name: root.title
        }

        Loader {
            sourceComponent: root.titleSuffix
            visible: root.titleSuffix !== null
        }

        Item {
            Layout.fillWidth: true
        }
    }

    property alias view: view

    StyledText {
        visible: root.description !== ""
        Layout.fillWidth: true
        text: root.description
        color: Signal.palette.inkMuted
    }

    StyledListView {
        id: view

        Layout.fillWidth: true
        implicitHeight: contentHeight

        model: root.model
        delegate: root.delegate

        spacing: Appearance.spacing.small / 2
        interactive: false
        clip: false
    }
}

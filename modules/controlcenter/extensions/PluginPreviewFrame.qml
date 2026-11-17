pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Live preview of one extension instance inside Control Center ›
// Extensions (RFC 0003 section 5.2). It instantiates the extension's own
// visible surface — desktop widget, else bar item, else dashboard card —
// in a host-owned frame at the manifest's size. Because every setting flows
// through the shared Settings storage, a control change in the generated
// settings UI is visible here immediately, with no extension code written
// for it.
//
// Same rules as the real surface: its own asynchronous Loader, a failure is
// shown inline and marks that surface failed through the Plugins service,
// nothing is instantiated in safe mode or for a disabled/uninstalled
// extension, and the preview exists only while its section is on screen
// (`active`). Honest trust note: this is in-process QML running as your user
// without a sandbox, exactly like the surface it previews.
ColumnLayout {
    id: root

    required property string pluginId
    // Instance key for per-instance settings ("" = primary); the extension
    // reads it through the hostInstanceId host-context property.
    property string instanceId: ""
    property bool active: false

    readonly property string surfaceName: ["desktop", "bar", "dashboard"].find(name => Plugins.hasSurface(root.pluginId, name)) ?? ""
    readonly property var surface: root.surfaceName !== "" ? Plugins.surfaceFor(Plugins.entryFor(root.pluginId), root.surfaceName) : null
    readonly property bool available: root.active && root.surface !== null && typeof root.surface.entrypoint === "string" && root.surface.entrypoint !== ""
    readonly property int frameWidth: Math.min(Math.max(120, root.surface?.width ?? (root.surfaceName === "dashboard" ? 380 : 320)), Math.max(160, root.width))
    readonly property int frameHeight: root.surface?.height ?? (root.surfaceName === "bar" ? 44 : root.surfaceName === "dashboard" ? 220 : 200)
    readonly property bool loadFailed: pluginLoader.status === Loader.Error

    // Callers show the frame only while `shown` (an extension with no
    // previewable surface, e.g. a headless one, shows nothing at all).
    readonly property bool shown: root.available || root.loadFailed
    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Preview")
        font.weight: 500
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("This is the extension itself, running with your current settings. Changes below show here immediately.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.Wrap
    }

    Rectangle {
        Layout.alignment: Qt.AlignLeft
        implicitWidth: root.frameWidth
        implicitHeight: root.surfaceName === "dashboard" ? Math.max(root.frameHeight, 60) : root.frameHeight
        radius: Appearance.rounding.small
        color: Signal.palette.panel
        border.width: 1
        border.color: Signal.palette.rule
        clip: true
        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("Live preview")

        Loader {
            id: pluginLoader

            readonly property int hostAvailableWidth: Math.max(0, Math.round(parent.width - Appearance.padding.larger * 2))
            readonly property int hostAvailableHeight: Math.max(0, Math.round(parent.height - Appearance.padding.larger * 2))

            anchors.fill: parent
            anchors.margins: Appearance.padding.larger
            palette.windowText: Signal.palette.ink
            active: root.available
            asynchronous: true
            source: active ? Plugins.entrypointUrl(root.pluginId, root.surface.entrypoint) : ""

            onStatusChanged: {
                if (status === Loader.Ready)
                    Plugins.markLoaded(root.pluginId, root.surfaceName);
                else if (status === Loader.Error)
                    Plugins.markFailed(root.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "preview failed to load (see shell log)", root.surfaceName);
            }

            Binding {
                target: pluginLoader.item
                property: "hostSurface"
                value: root.surfaceName
                when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostOrientation"
                value: "horizontal"
                when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostEdge"
                value: "none"
                when: pluginLoader.item !== null && "hostEdge" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostAvailableWidth"
                value: pluginLoader.hostAvailableWidth
                when: pluginLoader.item !== null && "hostAvailableWidth" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostAvailableHeight"
                value: pluginLoader.hostAvailableHeight
                when: pluginLoader.item !== null && "hostAvailableHeight" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostCompact"
                value: pluginLoader.hostAvailableWidth < 280
                when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostScreenName"
                value: ""
                when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostInstanceId"
                value: root.instanceId
                when: pluginLoader.item !== null && "hostInstanceId" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.loadFailed
        text: qsTr("The preview failed to load.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.alert
        wrapMode: Text.Wrap
    }
}

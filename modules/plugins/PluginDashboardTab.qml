pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

// Full Dashboard page host (PluginKit 5, shell#709): loads one
// contributed `dashboardTab` surface as a top-level Dashboard tab.
// The entrypoint gets its own asynchronous Loader and the standard
// dashboard host context (hostSurface "dashboardTab", full tab width),
// so a failing page is marked failed for that surface only and never
// takes the dashboard or another extension down. Plugin QML runs with
// the logged-in user's permissions; it is NOT sandboxed.
Item {
    id: root

    // One tab descriptor from Plugins.dashboardTabList():
    // {pluginId, pluginName, id, title, glyph, entrypoint, key}
    required property var tab
    readonly property var live: Plugins.entryFor(root.tab.pluginId) ?? null

    implicitWidth: 840
    implicitHeight: Math.max(pluginLoader.item ? pluginLoader.item.implicitHeight : 0, errorText.visible ? errorText.implicitHeight : 120)

    Accessible.role: Accessible.Pane
    Accessible.name: root.tab.title || root.tab.pluginId

    Loader {
        id: pluginLoader

        readonly property int hostAvailableWidth: root.implicitWidth
        readonly property int hostAvailableHeight: 0
        readonly property string hostSurface: "dashboardTab"

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        clip: true
        palette.windowText: Signal.palette.ink
        palette.window: Signal.palette.panel
        palette.base: Signal.palette.raised
        palette.alternateBase: Signal.palette.lifted
        palette.text: Signal.palette.ink
        palette.placeholderText: Signal.palette.inkMuted
        palette.button: Signal.palette.raised
        palette.buttonText: Signal.palette.ink
        palette.highlight: Signal.palette.signal
        palette.highlightedText: Signal.palette.onSignal
        palette.mid: Signal.palette.ruleStrong
        palette.dark: Signal.palette.ruleStrong
        palette.light: Signal.palette.lifted
        source: root.tab.entrypoint ? Plugins.entrypointUrl(root.tab.pluginId, root.tab.entrypoint) : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Loading)
                Plugins.markLoading(root.tab.pluginId);
            else if (status === Loader.Ready)
                Plugins.markLoaded(root.tab.pluginId, "dashboardTab");
            else if (status === Loader.Error)
                Plugins.markFailed(root.tab.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "dashboard tab entrypoint failed to load (see shell log)", "dashboardTab");
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
            property: "hostSurface"
            value: "dashboardTab"
            when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
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
            value: false
            when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
    }

    StyledText {
        id: errorText

        visible: pluginLoader.status === Loader.Error
        anchors.top: parent.top
        text: qsTr("This extension page failed to load.")
        color: Signal.palette.alert
    }
}

pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Bar placement for community plugins (M2 slice 2): renders every
// enabled plugin whose manifest declares `placement: "bar"` inside the
// bar's end group. Each plugin gets its own Loader, so a failing
// entrypoint is marked failed through the Plugins service and never
// takes the bar (or other plugins) down. Plugin QML runs with the
// logged-in user's permissions; it is NOT sandboxed.
//
// Responsive host context (#372): the host — never the plugin — knows
// which edge, orientation and thickness it rendered into, so it
// injects that context into the loaded entrypoint root for every
// property the plugin opted into by declaring it (see
// docs/PLUGINS.md, "Host context"). Injection is guarded per property
// (`"host…" in item`), so plugins that declare none of them load and
// render exactly as before; the API is purely additive. The size caps
// below are the same numbers reported as hostAvailableWidth/Height,
// so a plugin that honours them is never clipped, and a vertical rail
// reports hostCompact so horizontal button rows can stack instead of
// being forced into the rail's cross-axis thickness.
Repeater {
    id: root

    required property bool vertical
    property bool surfaceActive: true
    // Screen edge this bar sits on: "top" | "bottom" | "left" |
    // "right". Empty when the embedder does not know; plugins then
    // receive "none" and must rely on orientation alone.
    property string edge: ""
    // Cross-axis content thickness of the bar (spec.thickness), in
    // logical pixels (already scale-corrected by Qt). 0 = unknown,
    // which falls back to the pre-#372 default cap.
    property int thickness: 0
    // Narrow horizontal surface (Bar.compact width breakpoint).
    property bool compact: false
    // Display hosting this bar instance (multi-monitor: the same
    // plugin is instantiated once per bar/screen).
    property string screenName: ""

    // Explicit layout constraints for this surface. Cross-axis space
    // comes from the bar's real thickness so no control is clipped by
    // a thinner rail than the plugin assumed; the main-axis cap keeps
    // one plugin from starving its neighbours.
    readonly property int availableCross: thickness > 0 ? thickness : 64
    readonly property int availableMain: 240
    readonly property int availableWidth: vertical ? availableCross : availableMain
    readonly property int availableHeight: vertical ? availableMain : availableCross
    readonly property string hostOrientation: vertical ? "vertical" : "horizontal"
    readonly property string hostEdge: edge !== "" ? edge : "none"
    readonly property bool hostCompact: vertical || compact

    model: surfaceActive ? Plugins.barPlugins() : []

    delegate: Loader {
        id: pluginLoader

        required property var modelData

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.maximumWidth: root.availableWidth
        Layout.maximumHeight: root.availableHeight
        clip: true
        // Plugins cannot import Shell theming; give their default text the
        // bar's themed foreground through palette inheritance instead of
        // Qt's default black (invisible on the dark bar).
        palette.windowText: Colours.palette.m3onSurface
        source: modelData.entrypoint ? `file://${Plugins.pluginsDir}/${modelData.id}/${modelData.entrypoint}` : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Ready)
                Plugins.markLoaded(modelData.id);
            else if (status === Loader.Error)
                Plugins.markFailed(modelData.id, pluginLoader.errorString || "bar entrypoint failed to load (see shell log)");
        }

        // Host-context injection (#372): live bindings, so an edge,
        // thickness or compact change reaches the plugin without a
        // reload. Each binding only engages when the entrypoint root
        // declares the property — existing plugins are untouched.
        Binding {
            target: pluginLoader.item
            property: "hostOrientation"
            value: root.hostOrientation
            when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostEdge"
            value: root.hostEdge
            when: pluginLoader.item !== null && "hostEdge" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostSurface"
            value: "bar"
            when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostAvailableWidth"
            value: root.availableWidth
            when: pluginLoader.item !== null && "hostAvailableWidth" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostAvailableHeight"
            value: root.availableHeight
            when: pluginLoader.item !== null && "hostAvailableHeight" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostCompact"
            value: root.hostCompact
            when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostScreenName"
            value: root.screenName
            when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
    }
}

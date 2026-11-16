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
    // Native bar island this instance renders into (shell#439):
    // "status", "actions", "clock" or "end" (after the end group).
    // Each island embeds one instance with its own icon style, so an
    // extension indicator looks like its native neighbours.
    property string section: "end"
    // Inside a Column/Row island (Extensions, tray-like) the indicators are
    // centred across the island like tray items.
    property bool centerChildren: false
    property color iconColour: "transparent"
    property int iconSize: 0
    property int textSize: 0
    // Sections whose island is absent from this bar layout: their
    // indicators fall back to this (end) instance instead of vanishing.
    property var fallbackSections: []
    // Plugin ids hidden on this island (bar.extensions.hiddenIcons,
    // mirroring bar.tray.hiddenIcons); other islands leave it empty.
    property var hiddenIds: []

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

    model: surfaceActive ? Plugins.barPlugins().filter(p => !root.hiddenIds.includes(p.id) && ((p.barSection || "end") === root.section || root.fallbackSections.includes(p.barSection || "end"))) : []

    delegate: Loader {
        id: pluginLoader

        required property var modelData

        // Native popout bridge (shell#449): the extension's UiPopover hands
        // its content to the bar's shared popout panel (modules/bar/popouts)
        // instead of opening its own window, so it opens on hover, grows from
        // the bar edge and animates exactly like native popouts. The bar
        // hit-tests by `name`; Content.qml shows `hostPopoutContent`.
        readonly property string name: "plugin:" + modelData.id
        property Item hostPopoutContent: null
        property bool hostPopoutOpen: false

        function hostRegisterPopout(item: Item): void {
            pluginLoader.hostPopoutContent = item;
        }
        function hostTogglePopout(): void {
            Plugins.requestPopout(pluginLoader, !pluginLoader.hostPopoutOpen);
        }
        function hostOpenPopout(): void {
            Plugins.requestPopout(pluginLoader, true);
        }
        function hostClosePopout(): void {
            Plugins.requestPopout(pluginLoader, false);
        }

        // Host context advertised on the Loader itself, so PluginKit
        // primitives find it by ancestry even when the entrypoint does not
        // opt in to the host* properties (it still wins when it does).
        readonly property string hostSurface: "bar"
        readonly property int hostAvailableWidth: root.availableWidth
        readonly property bool hostCompact: root.hostCompact
        // Island style advertised to PluginKit (0 / transparent = generic
        // bar style for the end section).
        readonly property string hostSection: root.section
        readonly property color hostIconColor: root.iconColour
        readonly property int hostIconSize: root.iconSize
        readonly property int hostTextSize: root.textSize

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        anchors.horizontalCenter: root.centerChildren && root.vertical ? parent?.horizontalCenter : undefined
        anchors.verticalCenter: root.centerChildren && !root.vertical ? parent?.verticalCenter : undefined
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

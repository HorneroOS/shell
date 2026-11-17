pragma ComponentBehavior: Bound

import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts
import "baroverflow.js" as Overflow

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
//
// Overflow (shell#531): every indicator is clamped to
// bar.extensions.itemMaxWidth, and a native island (actions, clock,
// status) keeps its indicators inside bar.extensions.sectionBudget % of
// the bar's main axis. Indicators that do not fit, lowest priority
// first (declaration order), move to the Extensions island instead of
// being painted over their neighbours. A plugin whose root declares
// `available: false` has nothing to show and takes no room at all.
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
    // The Extensions island takes the indicators other islands could not
    // fit (shell#531).
    property bool acceptOverflow: false
    // Plugin ids hidden on this island (bar.extensions.hiddenIcons,
    // mirroring bar.tray.hiddenIcons); other islands leave it empty.
    property var hiddenIds: []

    // Explicit layout constraints for this surface. Cross-axis space
    // comes from the bar's real thickness so no control is clipped by
    // a thinner rail than the plugin assumed; the main-axis cap keeps
    // one plugin from starving its neighbours.
    readonly property int availableCross: thickness > 0 ? thickness : 64
    readonly property int availableMain: Config.bar.extensions.itemMaxWidth
    readonly property int availableWidth: vertical ? availableCross : availableMain
    readonly property int availableHeight: vertical ? availableMain : availableCross
    readonly property string hostOrientation: vertical ? "vertical" : "horizontal"
    readonly property string hostEdge: edge !== "" ? edge : "none"
    readonly property bool hostCompact: vertical || compact

    // ---- Overflow (shell#531) ----

    // The island hosts the Extensions island's own end section: it never
    // overflows (it collapses behind its chevron instead).
    readonly property bool canOverflow: root.section !== "end" && Plugins.hasOverflowSink(root.screenName)
    readonly property real barMain: root.vertical ? (Window.window?.height ?? 0) : (Window.window?.width ?? 0)
    readonly property real budget: root.canOverflow ? Overflow.budgetFor(root.barMain, Config.bar.extensions.sectionBudget) : 0
    readonly property int itemGap: 6
    property var overflowIds: []

    function replan(): void {
        const items = [];
        for (let i = 0; i < root.count; i++) {
            const d = root.itemAt(i);
            if (!d)
                continue;
            items.push({
                id: d.modelData.id,
                width: d.measuredMain,
                // Declared order is the priority: earlier indicators stay.
                priority: Math.max(0, 100 - i)
            });
        }
        const result = Overflow.plan(items, root.budget, root.itemGap, root.availableMain);
        const next = result.overflow;
        if (JSON.stringify(next) !== JSON.stringify(root.overflowIds))
            root.overflowIds = next;
    }

    function queueReplan(): void {
        Qt.callLater(root.replan);
    }

    onBudgetChanged: root.queueReplan()
    onItemAdded: root.queueReplan()
    onItemRemoved: root.queueReplan()
    onOverflowIdsChanged: Plugins.setBarOverflow(root.screenName, root.section, root.overflowIds)
    Component.onDestruction: Plugins.setBarOverflow(root.screenName, root.section, [])

    // Structurally stable (StableList.qml): a plugin reporting loaded or
    // failed must not rebuild every other indicator's Loader.
    // Repeater's default property is its delegate, so the helper goes in
    // `data` explicitly.
    data: [
        StableList {
            id: stable

            source: root.surfaceActive ? Plugins.barPlugins().filter(p => !root.hiddenIds.includes(p.id) && ((p.barSection || "end") === root.section || root.fallbackSections.includes(p.barSection || "end") || (root.acceptOverflow && Plugins.isBarOverflowed(root.screenName, p.id)))) : []
        }
    ]

    model: stable.list

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

        // Main-axis size last reported by the loaded entrypoint, kept while
        // an overflowed indicator is unloaded so the plan stays stable.
        property real measuredMain: 0
        // Natural size of the entrypoint: its implicit size, else the size it
        // was given. The Loader is clamped to itemMaxWidth along the main axis
        // (Row and Column parents ignore Layout.maximum*), and the loaded
        // item is resized to it, so a long label elides instead of spilling.
        readonly property real natWidth: pluginLoader.item ? (pluginLoader.item.implicitWidth > 0 ? pluginLoader.item.implicitWidth : pluginLoader.item.width) : 0
        readonly property real natHeight: pluginLoader.item ? (pluginLoader.item.implicitHeight > 0 ? pluginLoader.item.implicitHeight : pluginLoader.item.height) : 0
        readonly property real liveMain: root.vertical ? pluginLoader.natHeight : pluginLoader.natWidth
        // Opt-in: an entrypoint with nothing to show (no player, no device)
        // declares `available: false` and leaves the bar entirely.
        readonly property bool hasData: !pluginLoader.item || !("available" in pluginLoader.item) || pluginLoader.item.available !== false
        readonly property bool overflowed: !root.acceptOverflow && root.overflowIds.includes(pluginLoader.modelData.id)

        onLiveMainChanged: {
            if (pluginLoader.liveMain > 0 && Math.abs(pluginLoader.liveMain - pluginLoader.measuredMain) > 0.5)
                pluginLoader.measuredMain = pluginLoader.hasData ? pluginLoader.liveMain : 0;
        }
        onHasDataChanged: {
            if (!pluginLoader.hasData)
                pluginLoader.measuredMain = 0;
            else
                pluginLoader.measuredMain = pluginLoader.liveMain;
        }
        onMeasuredMainChanged: root.queueReplan()

        active: !pluginLoader.overflowed
        visible: !pluginLoader.overflowed && pluginLoader.hasData

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        anchors.horizontalCenter: root.centerChildren && root.vertical ? parent?.horizontalCenter : undefined
        anchors.verticalCenter: root.centerChildren && !root.vertical ? parent?.verticalCenter : undefined
        width: root.vertical ? pluginLoader.natWidth : Math.min(pluginLoader.natWidth, root.availableMain)
        height: root.vertical ? Math.min(pluginLoader.natHeight, root.availableMain) : pluginLoader.natHeight
        Layout.maximumWidth: root.availableWidth
        Layout.maximumHeight: root.availableHeight
        // Breathing room from the native items before it (Layout parents; a
        // Row or Column spaces its children itself).
        Layout.leftMargin: root.vertical ? 0 : root.itemGap
        Layout.topMargin: root.vertical ? root.itemGap : 0
        clip: true
        // Plugins cannot import Shell theming; give their default text the
        // bar's themed foreground through palette inheritance instead of
        // Qt's default black (invisible on the dark bar).
        // Raw Qt Controls an extension uses in its bar popover (TextField,
        // ComboBox, ...) take the shell palette instead of the Basic style's
        // white field, as on the dashboard host.
        // On a Clear bar the island's region ink (iconColour) is the foreground.
        palette.windowText: root.iconColour.a > 0 ? root.iconColour : Signal.palette.ink
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
        source: modelData.entrypoint ? Plugins.entrypointUrl(modelData.id, modelData.entrypoint) : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Loading)
                Plugins.markLoading(modelData.id);
            else if (status === Loader.Ready)
                Plugins.markLoaded(modelData.id, "bar");
            else if (status === Loader.Error)
                Plugins.markFailed(modelData.id, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "bar entrypoint failed to load (see shell log)", "bar");
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

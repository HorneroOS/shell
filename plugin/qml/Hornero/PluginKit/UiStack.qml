import QtQuick
import QtQuick.Layouts

// Adaptive one-dimensional layout for PluginKit (#372): children lay
// out along a row on roomy horizontal surfaces and stack into a
// column when the host surface is vertical or compact, so a
// horizontal multi-button row is never forced into a narrow rail.
// Bind `orientation`/`compact` to the entrypoint's injected host
// context (hostOrientation/hostCompact, docs/PLUGINS.md "Host
// context"); with no bindings it behaves like a plain row, which is
// the pre-host-context default.
GridLayout {
    id: root

    // "horizontal" | "vertical" (hostOrientation values).
    property string orientation: "horizontal"
    // Narrow-surface flag (hostCompact): stacks even when horizontal.
    property bool compact: false
    property int spacing: Theme.spacingSmall

    readonly property bool stacked: orientation === "vertical" || compact

    flow: stacked ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: stacked ? -1 : 1
    columns: stacked ? 1 : -1
    rowSpacing: spacing
    columnSpacing: spacing
}

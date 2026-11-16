import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Plugin-defined provider row (shell#250 follow-up): one result
// from a hosted surfaces.launcher plugin. Activation goes through
// the registry (Providers.activate), which copies the plugin's
// result text with wl-copy and closes the launcher — the built-in
// calc provider's convention; plugins have no activation hook.
LauncherRow {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        Providers.activate(root.modelData, root.list);
    }

    glyph: root.modelData?.icon ?? "puzzle"
    title: root.modelData?.title ?? ""
    detail: root.modelData?.subtitle ?? ""
    onActivated: root.onClicked()
}

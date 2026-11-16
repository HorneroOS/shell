import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Launcher window provider (shell#250 slice 1): `>win <query>` lists
// open windows from the compositor toplevels and focuses the chosen
// one through the Windows provider's activation (Hypr.dispatch, the
// shell's existing window-activation path). Hyprland-only today —
// the toplevel source is Hypr.toplevels; Niri rows arrive with its
// window read model.
LauncherRow {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        Windows.activate(root.modelData);
        root.list.visibilities.launcher = false;
    }

    glyph: "app-window"
    title: root.modelData?.title ?? ""
    detail: root.modelData?.appClass ?? ""
    kind: qsTr("WS %1").arg(root.modelData?.workspaceName ?? "?")
    onActivated: root.onClicked()
}

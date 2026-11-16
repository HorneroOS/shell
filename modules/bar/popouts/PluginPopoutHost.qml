import QtQuick

// Shows an extension popover inside the native popout panel (shell#449).
// The extension's UiPopover registers its content item with the bar host
// Loader; this host borrows it (visual reparent only — the extension keeps
// ownership) while the popout is active and hands it back when it closes or
// another extension's popout replaces it, so nothing is ever destroyed.
Item {
    id: root

    property Item content: null
    property Item _held: null
    property Item _home: null

    implicitWidth: root._held ? root._held.implicitWidth : 0
    implicitHeight: root._held ? root._held.implicitHeight : 0

    function release(): void {
        if (root._held) {
            root._held.parent = root._home;
            root._held = null;
            root._home = null;
        }
    }

    function adopt(): void {
        if (root._held === root.content)
            return;
        root.release();
        if (!root.content)
            return;
        root._home = root.content.parent;
        root._held = root.content;
        root.content.parent = root;
        root.content.x = 0;
        root.content.y = 0;
        root.content.visible = true;
    }

    onContentChanged: adopt()
    Component.onCompleted: adopt()
    Component.onDestruction: release()
}

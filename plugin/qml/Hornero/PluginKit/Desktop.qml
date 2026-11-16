pragma Singleton

import qs.config
import qs.services
import QtQuick

// Desktop widget facade (PluginKit 3, RFC 0001 §5b). Desktop widgets are
// hosted by the shell on the desktop layer of each screen: the host owns
// the module frame, position, size, persistence and edit mode; the
// extension owns only its content. See docs/PLUGINS.md "Desktop widgets".
QtObject {
    // True while the person is moving/resizing desktop widgets. Widgets
    // may hide interactive controls while editing (the frame takes the
    // pointer).
    readonly property bool editing: Plugins.desktopEditing

    // The anchor a widget starts from on a screen (one of nine names,
    // e.g. "top-right"), before the person moves it.
    function anchor(pluginId: string, screenName: string): string {
        if (!Plugins.hasPlacement(pluginId, "desktop") && !Plugins.hasSurface(pluginId, "desktop"))
            return "bottom-right";
        return Config.plugins.desktopWidgetSlot(pluginId, screenName);
    }

    // Saved geometry {fx, fy, width, height} or null when the widget is
    // at its anchor with its default size.
    function geometry(pluginId: string, screenName: string): var {
        return Config.plugins.desktopWidgetGeometry(pluginId, screenName);
    }
}

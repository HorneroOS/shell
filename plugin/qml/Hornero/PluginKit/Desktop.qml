pragma Singleton

import qs.config
import qs.services
import QtQuick

QtObject {
    function position(pluginId: string, screenName: string): string {
        if (!Plugins.hasPlacement(pluginId, "desktop"))
            return "bottom-right";

        return Config.plugins.desktopWidgetSlot(pluginId, screenName);
    }
}

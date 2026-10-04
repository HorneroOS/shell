pragma Singleton

import Quickshell
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: var): void {
        const updated = new Map(screens);
        updated.set(screen.name, visibilities);
        screens = updated;
    }

    function setBar(screen: ShellScreen, bar: var): void {
        const updated = new Map(bars);
        updated.set(screen, bar);
        bars = updated;
    }

    function getForActive(): PersistentProperties {
        const focused = Compositor.focusedOutputName || Quickshell.screens[0]?.name || "";
        return screens.get(focused);
    }
}

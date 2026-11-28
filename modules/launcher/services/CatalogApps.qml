pragma Singleton

import "../../../services/store.js" as Store
import qs.modules.apps
import Quickshell
import QtQuick

// Lazy, debounced catalog discovery bridge for the Launcher.
// Installed DesktopEntries always rank first in Apps.search(); this helper
// only supplies matching uninstalled Hornero Apps catalog entries once the
// query has >= 2 characters and no special/action prefix is active.
Singleton {
    id: root

    property int revision: 0
    property string pendingQuery: ""

    Connections {
        target: AppsStore

        function onCatalogAppsChanged(): void {
            root.revision++;
        }

        function onCatalogLoadedChanged(): void {
            root.revision++;
        }
    }

    Timer {
        id: lazyLoadTimer

        interval: 160
        repeat: false
        onTriggered: AppsStore.ensureCatalogLoaded()
    }

    function search(queryText: string, installedEntries: var): var {
        // Touch revision so QML bindings re-evaluate when lazy catalog arrives.
        const _rev = root.revision;
        const q = (queryText ?? "").trim();
        if (q.length < 2)
            return [];
        if (!AppsStore.catalogLoaded) {
            root.pendingQuery = q;
            lazyLoadTimer.restart();
            return [];
        }
        return Store.filterUninstalledForLauncher(AppsStore.catalogApps, installedEntries, q, 4);
    }
}

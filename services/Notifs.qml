pragma Singleton
pragma ComponentBehavior: Bound

import qs.components.misc
import qs.config
import qs.utils
import Hornero
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property list<Notif> list: []
    readonly property list<Notif> notClosed: list.filter(n => !n.closed)
    readonly property list<Notif> popups: list.filter(n => n.popup)
    property alias dnd: props.dnd

    // S12: hard bound on live notifications. A spammy sender must
    // not grow memory, the center list, or the persisted JSON
    // without limit; legitimate flows never hold this many live
    // at once. Overflow closes oldest-first (locked ones are
    // marked closed and drop on unlock, via Notif.close()).
    readonly property int maxListSize: 100

    // Flood policy (shell#224): identical re-sends collapse inside a
    // short window, and one chatty app cannot hold the whole list.
    // Critical-urgency notifications are exempt from both: losing a
    // battery/VPN-critical alert to a flood is the failure this
    // policy exists to prevent (they also survive DND as popups via
    // the urgency path in the popup filter below).
    readonly property int dedupWindowMs: 60000
    readonly property int maxPerApp: 20

    function _isDuplicate(notif: var): bool {
        const now = new Date().getTime();
        for (const n of root.list) {
            if (n.closed)
                continue;
            if (n.appName === notif.appName && n.summary === notif.summary && n.body === notif.body
                    && now - n.time.getTime() < root.dedupWindowMs)
                return true;
        }
        return false;
    }

    function _enforcePerApp(appName: string): void {
        const open = root.list.filter(n => !n.closed && n.appName === appName);
        // list is newest-first; close everything past the cap, oldest last.
        for (const old of open.slice(root.maxPerApp))
            old.close();
    }

    // Critical promotion (shell#224): shell-detected critical
    // conditions (battery critical, unexpected VPN drop) are filed
    // as real notifications so they remain in history and pop up
    // under DND, exactly like external critical-urgency ingress.
    // This is the one deliberate exception to the "shell never files
    // its own messages" source rule in docs/NOTIFICATIONS.md, and it
    // is reserved for conditions the user must be able to review
    // after the moment has passed. Callers keep their toast as the
    // momentary voice; this files the durable record.
    function promoteCritical(summary: string, body: string, appIcon: string): void {
        const comp = notifComp.createObject(root, {
            popup: ![...Visibilities.screens.values()].some(v => v.sidebar),
            summary: summary,
            body: body,
            appName: qsTr("HorneroOS"),
            appIcon: appIcon,
            urgency: NotificationUrgency.Critical
        });
        root.list = [comp, ...root.list];
        if (root.list.length > root.maxListSize)
            for (const old of root.list.slice(root.maxListSize))
                old.close();
    }

    property bool loaded


    function _loadNotifs(rawText: string): void {
        const data = JSON.parse(rawText);
        for (const notif of data)
            root.list.push(notifComp.createObject(root, notif));
        root.list.sort((a, b) => b.time - a.time);
        root.loaded = true;
    }

    onDndChanged: {
        if (!Config.utilities.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(qsTr("Do not disturb enabled"), qsTr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(qsTr("Do not disturb disabled"), qsTr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            // Flood policy first (shell#224): duplicates collapse and
            // critical urgency is never dropped by the policy.
            if (notif.urgency !== NotificationUrgency.Critical && root._isDuplicate(notif)) {
                notif.close();
                return;
            }

            const comp = notifComp.createObject(root, {
                popup: (notif.urgency === NotificationUrgency.Critical || !props.dnd) && ![...Visibilities.screens.values()].some(v => v.sidebar),
                notification: notif
            });
            root.list = [comp, ...root.list];
            if (notif.urgency !== NotificationUrgency.Critical)
                root._enforcePerApp(notif.appName);
            if (root.list.length > root.maxListSize)
                for (const old of root.list.slice(root.maxListSize))
                    old.close();
        }
    }

    FileView {
        id: storage

        path: `${Paths.state}/notifs.json`
        onLoaded: root._loadNotifs(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                storage.setText("[]");
            } else {
                console.warn("Notifications: could not load stored history:", FileViewError.toString(err));
            }
        }
    }

    CustomShortcut {
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
        }
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function isDndEnabled(): bool {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }
    }

    component Notif: QtObject {
        id: notif

        property bool popup
        property bool closed
        property var locks: new Set()

        property date time: new Date()
        readonly property string timeStr: {
            const diff = Time.date.getTime() - time.getTime();
            const m = Math.floor(diff / 60000);

            if (m < 1)
                return qsTr("now");

            const h = Math.floor(m / 60);
            const d = Math.floor(h / 24);

            if (d > 0)
                return `${d}d`;
            if (h > 0)
                return `${h}h`;
            return `${m}m`;
        }

        property Notification notification
        property string id
        property string summary
        property string body
        property string appIcon
        property string appName
        property string image
        property real expireTimeout: Config.notifs.defaultExpireTimeout
        property int urgency: NotificationUrgency.Normal
        property bool resident
        property bool hasActionIcons
        property list<var> actions

        readonly property Timer timer: Timer {
            running: true
            interval: notif.expireTimeout > 0 ? notif.expireTimeout : Config.notifs.defaultExpireTimeout
            onTriggered: {
                if (Config.notifs.expire)
                    notif.popup = false;
            }
        }

        readonly property LazyLoader dummyImageLoader: LazyLoader {
            active: false

            PanelWindow {
                implicitWidth: Config.notifs.sizes.image
                implicitHeight: Config.notifs.sizes.image
                color: "transparent"
                mask: Region {}

                Image {
                    function tryCache(): void {
                        if (status !== Image.Ready || width != Config.notifs.sizes.image || height != Config.notifs.sizes.image)
                            return;

                        const cacheKey = notif.appName + notif.summary + notif.id;
                        let h1 = 0xdeadbeef, h2 = 0x41c6ce57, ch;
                        for (let i = 0; i < cacheKey.length; i++) {
                            ch = cacheKey.charCodeAt(i);
                            h1 = Math.imul(h1 ^ ch, 2654435761);
                            h2 = Math.imul(h2 ^ ch, 1597334677);
                        }
                        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
                        h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
                        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
                        h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
                        const hash = (h2 >>> 0).toString(16).padStart(8, 0) + (h1 >>> 0).toString(16).padStart(8, 0);

                        // Contract row 10: new captures go to the canonical
                        // Hornero cache; absolute paths stored in
                        // notifs.json keep resolving directly.
                        const cache = `${Paths.notifimagecache}/${hash}.png`;
                        CUtils.saveItem(this, Qt.resolvedUrl(cache), () => {
                            notif.image = cache;
                            notif.dummyImageLoader.active = false;
                        });
                    }

                    anchors.fill: parent
                    source: Qt.resolvedUrl(notif.image)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    opacity: 0

                    onStatusChanged: tryCache()
                    onWidthChanged: tryCache()
                    onHeightChanged: tryCache()
                }
            }
        }

        readonly property Connections conn: Connections {
            target: notif.notification

            function onClosed(): void {
                notif.close();
            }

            function onSummaryChanged(): void {
                notif.summary = notif.notification.summary;
            }

            function onBodyChanged(): void {
                notif.body = notif.notification.body;
            }

            function onAppIconChanged(): void {
                notif.appIcon = notif.notification.appIcon;
            }

            function onAppNameChanged(): void {
                notif.appName = notif.notification.appName;
            }

            function onImageChanged(): void {
                notif.image = notif.notification.image;
                if (notif.notification?.image)
                    notif.dummyImageLoader.active = true;
            }

            function onExpireTimeoutChanged(): void {
                notif.expireTimeout = notif.notification.expireTimeout;
            }

            function onUrgencyChanged(): void {
                notif.urgency = notif.notification.urgency;
            }

            function onResidentChanged(): void {
                notif.resident = notif.notification.resident;
            }

            function onHasActionIconsChanged(): void {
                notif.hasActionIcons = notif.notification.hasActionIcons;
            }

            function onActionsChanged(): void {
                notif.actions = notif.notification.actions.map(a => ({
                            identifier: a.identifier,
                            text: a.text,
                            invoke: () => a.invoke()
                        }));
            }
        }

        function lock(item: Item): void {
            locks.add(item);
        }

        function unlock(item: Item): void {
            locks.delete(item);
            if (closed)
                close();
        }

        function close(): void {
            closed = true;
            if (locks.size === 0 && root.list.includes(this)) {
                root.list = root.list.filter(n => n !== this);
                notification?.dismiss();
                destroy();
            }
        }

        Component.onCompleted: {
            if (!notification)
                return;

            id = notification.id;
            summary = notification.summary;
            body = notification.body;
            appIcon = notification.appIcon;
            appName = notification.appName;
            image = notification.image;
            if (notification?.image)
                dummyImageLoader.active = true;
            expireTimeout = notification.expireTimeout;
            urgency = notification.urgency;
            resident = notification.resident;
            hasActionIcons = notification.hasActionIcons;
            actions = notification.actions.map(a => ({
                        identifier: a.identifier,
                        text: a.text,
                        invoke: () => a.invoke()
                    }));
        }
    }

    Component {
        id: notifComp

        Notif {}
    }
}

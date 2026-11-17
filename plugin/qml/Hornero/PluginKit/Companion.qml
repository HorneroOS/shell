pragma Singleton

import qs.modules.companion
import QtQuick

// Governed way for an extension to make Javi (the Companion) react to
// something that really happened in the extension: a build, a download,
// a device, a finished task. It is a request, not a command: the shell
// decides (user switches per kind and per Experience mode, quiet hours,
// cooldowns, a per-extension rate limit and a per-extension mute in
// Control Center > Companion). Native kinds (battery, notification,
// charger, mode) cannot be raised from here.
QtObject {
    // The kinds an extension may raise.
    readonly property var kinds: ["build.done", "build.failed", "download.done", "device.connected", "device.disconnected", "task.done", "attention"]

    // react("example-ci", "build.done", "Build 412 passed") -> bool
    // pluginId is a namespace (like Settings.pluginId), not proof of
    // identity. `text` is optional plain text, one line, at most 80
    // characters; markup is shown literally. Returns whether Javi showed
    // the reaction.
    function react(pluginId: string, kind: string, text: string): bool {
        const id = (pluginId ?? "").toString().toLowerCase();
        if (!/^[a-z0-9][a-z0-9._-]{0,63}$/.test(id))
            return false;
        return CompanionReactions.react((kind ?? "").toString(), "plugin:" + id, (text ?? "").toString());
    }
}

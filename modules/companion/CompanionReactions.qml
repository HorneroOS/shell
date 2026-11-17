pragma Singleton

import "reactions.js" as Reactions
import qs.services
import Quickshell
import QtQuick

// Reaction bus: the one entry point through which real events make Javi
// react. Native emitters (Notifs, BatteryMonitor, Experience) call
// react(kind, "shell"); IPC and PluginKit extensions call it with source
// "ipc" / "plugin:<id>" and only reach the kinds reactions.js marks
// external. reactions.js decides (settings, Experience mode, quiet hours,
// cooldowns, rate limits); CompanionStore.playReaction shows the beat.
// Nothing here polls or animates: an unused bus costs nothing.
Singleton {
    id: root

    property var history: Reactions.emptyHistory()
    // Last decision for diagnostics (`qs ipc call companion reactStatus`).
    property var lastDecision: ({ ok: false, reason: "none" })
    property int shown: 0
    property int dropped: 0

    readonly property var catalog: Reactions.catalog()
    readonly property list<string> modeIds: Reactions.MODE_IDS
    readonly property list<string> levels: Reactions.LEVELS

    function react(kind: string, source: string, text: string): bool {
        const now = Date.now();
        const d = new Date(now);
        const decision = Reactions.decide({
            settings: CompanionStore.reactionSettings,
            kind: kind,
            source: source,
            text: text,
            mode: Experience.mode,
            nowMs: now,
            minute: d.getHours() * 60 + d.getMinutes(),
            history: root.history,
            hasAnimation: name => Companion.hasAnimation(CompanionStore.skin, name)
        });
        root.lastDecision = decision;
        if (!decision.ok) {
            root.dropped += 1;
            return false;
        }
        // The built-in English bubble becomes Javi's line in the user's
        // language and tone; an external sender's own text is never
        // replaced (it is only shown, bounded and sanitised).
        let bubble = decision.bubble;
        if (bubble !== "" && bubble === Reactions.KINDS[decision.kind].bubble) {
            const spoken = JaviVoice.line("reaction." + decision.kind);
            if (spoken.indexOf("reaction.") !== 0)
                bubble = spoken;
        }
        if (!CompanionStore.playReaction(decision.anim, bubble, decision.bubbleMs, decision.priority)) {
            root.lastDecision = { ok: false, reason: "not-visible" };
            root.dropped += 1;
            return false;
        }
        root.history = Reactions.record(root.history, decision.kind, decision.source, now);
        root.shown += 1;
        return true;
    }

    function status(): var {
        return {
            enabled: CompanionStore.reactionSettings.enabled,
            mode: Experience.mode,
            level: Reactions.effectiveLevel(CompanionStore.reactionSettings, Experience.mode, new Date().getHours() * 60 + new Date().getMinutes()),
            shown: root.shown,
            dropped: root.dropped,
            last: root.lastDecision
        };
    }
}

pragma Singleton

import "reactions.js" as Reactions
import "companionpacks.js" as Packs
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
    // Extension/IPC sources that asked this session (plus any already
    // muted), so Control Center can list them for muting.
    property var seenSources: []
    property int shown: 0
    property int dropped: 0

    readonly property var catalog: Reactions.catalog()
    readonly property list<string> modeIds: Reactions.MODE_IDS
    readonly property list<string> levels: Reactions.LEVELS

    // Translatable text: reactions.js owns the policy and the English
    // defaults, these literals are what translators see.
    function defaultBubble(kind: string): string {
        switch (kind) {
        case "battery.low":
            return qsTr("Battery is getting low.");
        case "battery.critical":
            return qsTr("Battery is critical. Plug in soon.");
        case "build.done":
            return qsTr("Build finished.");
        case "build.failed":
            return qsTr("The build failed.");
        case "download.done":
            return qsTr("Download finished.");
        default:
            return "";
        }
    }

    function label(kind: string): string {
        switch (kind) {
        case "notification":
            return qsTr("New notification");
        case "battery.low":
            return qsTr("Battery low");
        case "battery.critical":
            return qsTr("Battery critical");
        case "charger.plugged":
            return qsTr("Charger connected");
        case "charger.unplugged":
            return qsTr("Charger removed");
        case "mode.changed":
            return qsTr("Experience mode changed");
        case "build.done":
            return qsTr("Build finished");
        case "build.failed":
            return qsTr("Build failed");
        case "download.done":
            return qsTr("Download finished");
        case "device.connected":
            return qsTr("Device connected");
        case "device.disconnected":
            return qsTr("Device disconnected");
        case "task.done":
            return qsTr("Task finished");
        case "attention":
            return qsTr("Needs your attention");
        case "agent.quota":
            return qsTr("Agent quota approaching a limit");
        default:
            return kind;
        }
    }

    function react(kind: string, source: string, text: string): bool {
        const now = Date.now();
        const d = new Date(now);
        const route = CompanionInstances.reactionTarget;
        const routedInstance = route !== "primary" && route !== "none" ? CompanionInstances.instanceById(route) : null;
        const routedCharacter = routedInstance ? CompanionRegistry.characterByKey(routedInstance.characterId) : null;
        const decision = Reactions.decide({
            settings: CompanionStore.reactionSettings,
            kind: kind,
            source: source,
            text: text,
            mode: Experience.mode,
            nowMs: now,
            minute: d.getHours() * 60 + d.getMinutes(),
            history: root.history,
            hasAnimation: name => {
                if (routedInstance && routedCharacter && routedCharacter.definition)
                    return !!Packs.resolveAnimation(routedCharacter.definition, routedInstance.skin, name);
                if (route === "none")
                    return true;
                return Companion.hasAnimation(CompanionStore.effectiveSkin, name);
            }
        });
        root.lastDecision = decision;
        const src = Reactions.sourceKey(source);
        if (src !== "" && src !== "shell" && root.seenSources.indexOf(src) < 0 && root.seenSources.length < 64)
            root.seenSources = root.seenSources.concat([src]);
        if (!decision.ok) {
            root.dropped += 1;
            return false;
        }
        // Built-in bubbles become Javi's line in the user's language and
        // tone (falling back to the translated default); an external
        // sender's own text (decision.custom) is never replaced (it is
        // only shown, bounded and sanitised).
        let bubble = decision.bubble;
        if (bubble !== "" && !decision.custom && !routedInstance) {
            const spoken = JaviVoice.line("reaction." + decision.kind);
            bubble = spoken.indexOf("reaction.") !== 0 ? spoken : (root.defaultBubble(decision.kind) || decision.bubble);
        }
        if (route === "none") {
            root.lastDecision = { ok: false, reason: "route-none" };
            root.dropped += 1;
            return false;
        }
        if (routedInstance) {
            if (!routedCharacter || !routedCharacter.definition || !routedInstance.enabled || !routedInstance.reactions) {
                root.lastDecision = { ok: false, reason: "route-unavailable" };
                root.dropped += 1;
                return false;
            }
            if (!decision.custom && routedCharacter.definition.personality) {
                const options = routedCharacter.definition.personality.options || [];
                const personality = options.find(o => o.id === routedInstance.personalityId) || options.find(o => o.id === routedCharacter.definition.personality.default);
                const line = personality && personality.lines ? Packs.localizedText(personality.lines[decision.anim], Qt.locale().name) : "";
                if (line)
                    bubble = line;
            }
            CompanionInstances.requestReaction(routedInstance.id, decision.anim, bubble);
        } else if (route !== "primary") {
            root.lastDecision = { ok: false, reason: "route-unavailable" };
            root.dropped += 1;
            return false;
        } else if (!CompanionStore.playReaction(decision.anim, bubble, decision.bubbleMs, decision.priority)) {
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

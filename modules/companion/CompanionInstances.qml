pragma Singleton

import Quickshell
import QtQuick
import "companionpacks.js" as Packs

// Versioned generic companion instance document. The legacy Javi
// record is an identity/routing adapter only; every editable Javi
// preference remains in CompanionStore and is never copied here.
Singleton {
    id: root

    property var document: ({
            "schemaVersion": 1,
            "nextSerial": 2,
            "reactionTarget": "primary",
            "instances": []
        })
    property bool dirty: false
    property bool savePending: false
    property bool loaded: false

    signal reactionRequested(string instanceId, string animation, string bubble)
    signal greetRequested(string instanceId)

    readonly property var instances: document.instances || []
    readonly property var genericInstances: root.instances.filter(i => !i.legacy)
    readonly property var genericIds: root.genericInstances.map(i => i.id)
    readonly property string reactionTarget: document.reactionTarget || "primary"
    readonly property int maxGenericInstances: 6

    function _replace(doc: var): void {
        const mergedByKey = {};
        for (const character of CompanionRegistry.characters)
            mergedByKey[character.key] = CompanionRegistry.characterByKey(character.key);
        root.document = Packs.sanitizeInstanceDocument(doc, mergedByKey);
    }

    function prime(text: string): void {
        let parsed = null;
        try {
            parsed = text ? JSON.parse(text) : null;
        } catch (e) {
            parsed = null;
        }
        root._replace(parsed);
        root.loaded = true;
        // Seed/migrate once: persisting the sanitized seed makes the
        // legacy identity explicit without touching CompanionStore.
        if (!text || !parsed)
            root.markDirty();
    }

    function serialize(): string {
        return JSON.stringify(root.document, null, 2) + "\n";
    }

    function markDirty(): void {
        root.dirty = true;
    }

    function clearDirty(): void {
        root.dirty = false;
        root.savePending = false;
    }

    function instanceById(id: string): var {
        return root.instances.find(i => i.id === id) || null;
    }

    function addInstance(characterKey: string): string {
        const character = CompanionRegistry.characterByKey(characterKey);
        if (!character || character.legacy || !character.definition)
            return "";
        if (root.genericInstances.length >= root.maxGenericInstances)
            return "";
        const next = JSON.parse(JSON.stringify(root.document));
        const serial = next.nextSerial || 2;
        const id = `instance-${serial}`;
        const def = character.definition;
        const skin = def.skins[def.defaultSkin];
        next.nextSerial = serial + 1;
        next.instances.push({
            id: id,
            characterId: characterKey,
            legacy: false,
            enabled: true,
            skin: def.defaultSkin,
            posX: Math.max(0.08, Math.min(0.92, 0.72 + (serial % 3) * 0.08)),
            posY: 0.9,
            screenName: "",
            scale: 1,
            habitatEnabled: !!def.habitat,
            accessories: skin ? skin.defaultAccessories.slice() : [],
            personalityId: def.personality ? def.personality.default : "",
            reactions: false,
            assistantBinding: "none"
        });
        root._replace(next);
        root.markDirty();
        return id;
    }

    function updateInstance(id: string, patch: var): void {
        if (!patch || typeof patch !== "object")
            return;
        const next = JSON.parse(JSON.stringify(root.document));
        const item = next.instances.find(i => i.id === id);
        if (!item || item.legacy)
            return;
        for (const key of ["enabled", "skin", "posX", "posY", "screenName", "scale", "habitatEnabled", "habitatPosX", "habitatPosY", "accessories", "personalityId", "reactions", "assistantBinding"]) {
            if (patch[key] !== undefined)
                item[key] = patch[key];
        }
        root._replace(next);
        root.markDirty();
    }

    function removeInstance(id: string): void {
        const next = JSON.parse(JSON.stringify(root.document));
        const before = next.instances.length;
        next.instances = next.instances.filter(i => i.id !== id || i.legacy);
        if (next.instances.length !== before) {
            if (next.reactionTarget === id)
                next.reactionTarget = "primary";
            root._replace(next);
            root.markDirty();
        }
    }

    function duplicateInstance(id: string): string {
        const source = root.instanceById(id);
        if (!source || source.legacy)
            return "";
        const created = root.addInstance(source.characterId);
        if (created) {
            root.updateInstance(created, {
                enabled: source.enabled,
                skin: source.skin,
                posX: Math.max(0, Math.min(1, source.posX - 0.12)),
                posY: source.posY,
                screenName: source.screenName,
                scale: source.scale,
                habitatEnabled: source.habitatEnabled,
                accessories: source.accessories.slice(),
                personalityId: source.personalityId,
                reactions: false,
                assistantBinding: "none"
            });
        }
        return created;
    }

    function setReactionTarget(target: string): void {
        if (target !== "primary" && target !== "none" && !root.instanceById(target))
            return;
        const next = JSON.parse(JSON.stringify(root.document));
        next.reactionTarget = target;
        root._replace(next);
        root.markDirty();
    }

// Ambient companion-to-companion beat (host-scheduled, opt-in via
    // idle animations in the host; never a model call).
    function requestGreet(id: string): void {
        const item = root.instanceById(id);
        if (item && !item.legacy && item.enabled)
            root.greetRequested(id);
    }

    function requestReaction(instanceId: string, animation: string, bubble: string): void {
        const item = root.instanceById(instanceId);
        if (item && !item.legacy && item.enabled)
            root.reactionRequested(instanceId, animation, bubble || "");
    }
}


pragma Singleton

import qs.services
import Quickshell.Io
import QtQml
import Quickshell
import QtQuick
import "companionpacks.js" as Packs

// Character registry for the companion platform (docs/COMPANION_PLATFORM.md).
// The built-in Javi descriptor is an adapter over the existing legacy
// runtime; plugin characters arrive only from validated data-only
// packages. This singleton reads JSON definitions as data — it never
// instantiates package QML.
Singleton {
    id: root

    property var _definitions: ({})
    property var _addons: ({})
    property var _loaders: []
    property string _fingerprint: ""
    property var diagnostics: []

    readonly property var contributions: Plugins.companionList()
    readonly property var addonContributions: Plugins.companionAddonList()

    function _addonsFor(key: string): var {
        return root._addons[key] || [];
    }

    function _builtInJavi(): var {
        return ({
            "key": "hornero:javi",
            "pluginId": "hornero",
            "characterId": "javi",
            "legacy": true,
            "available": true,
            "version": "built-in",
            "names": {
                "en": "Javi",
                "es": "Javi"
            },
            "descriptions": {
                "en": "The official HorneroOS rufous hornero and Hermes assistant.",
                "es": "El hornero oficial de HorneroOS y asistente Hermes."
            },
            "previewUrl": Companion.frameSource("default", "idle"),
            "definition": null,
            "basePath": ""
        });
    }

    readonly property var characters: {
        const loaded = [root._builtInJavi()];
        for (const key of Object.keys(root._definitions).sort())
            loaded.push(root._definitions[key]);
        return loaded;
    }

    readonly property var byKey: {
        const out = {};
        for (const character of root.characters)
            out[character.key] = character;
        return out;
    }

    function characterByKey(key: string): var {
        const base = root.byKey[key] || null;
        if (!base || !base.definition)
            return base;
        const addons = root._addonsFor(key);
        if (!addons.length)
            return base;
        return Object.assign({}, base, { definition: Packs.mergeAddons(base.definition, addons) });
    }

    function displayName(character: var): string {
        return character ? Packs.localizedText(character.names, Qt.locale().name) : "";
    }

    function _directoryOf(path: string): string {
        const slash = path.lastIndexOf("/");
        return slash >= 0 ? path.slice(0, slash) : path;
    }

    function refresh(): void {
        const list = Plugins.companionList();
        const fingerprint = JSON.stringify(list.map(c => [c.key, c.definition, c.version || ""]));
        if (fingerprint === root._fingerprint)
            return;
        root._fingerprint = fingerprint;
        for (const loader of root._loaders)
            loader.destroy();
        root._loaders = [];
        root._definitions = ({});
        root.diagnostics = [];
        for (const addon of Plugins.companionAddonList()) {
            const loader = addonLoader.createObject(root, {
                "contributionData": addon,
                "path": `${Plugins.pluginsDir}/${addon.pluginId}/${addon.definition}`
            });
            if (loader)
                root._loaders.push(loader);
        }
        for (const contribution of list) {
            const loader = definitionLoader.createObject(root, {
                "contributionData": contribution,
                "path": `${Plugins.pluginsDir}/${contribution.pluginId}/${contribution.definition}`
            });
            if (loader)
                root._loaders.push(loader);
        }
    }

    Component {
        id: definitionLoader

        FileView {
            id: loader

            property var contributionData: null

            printErrors: false

            onLoaded: {
                try {
                    const contribution = loader.contributionData;
                    const definition = Packs.sanitizeDefinition(JSON.parse(loader.text()), contribution.id);
                    if (!definition) {
                        root.diagnostics = root.diagnostics.concat([`${contribution.key}: invalid definition`]);
                        return;
                    }
                    // Frame/preview paths in a definition are
                    // package-relative, so the render base is the
                    // package root, not the definition directory.
                    const basePath = `${Plugins.pluginsDir}/${contribution.pluginId}`;
                    const next = Object.assign({}, root._definitions);
                    next[contribution.key] = {
                        key: contribution.key,
                        pluginId: contribution.pluginId,
                        characterId: contribution.id,
                        legacy: false,
                        available: true,
                        version: contribution.version || definition.version,
                        names: definition.names,
                        descriptions: definition.descriptions,
                        previewUrl: "file://" + basePath + "/" + definition.preview,
                        definition: definition,
                        basePath: basePath
                    };
                    root._definitions = next;
                } catch (e) {
                    root.diagnostics = root.diagnostics.concat([`${loader.contributionData.key}: unreadable definition`]);
                }
            }

            onLoadFailed: root.diagnostics = root.diagnostics.concat([`${loader.contributionData.key}: definition could not be read`])
        }
    }

    Connections {
        target: Plugins

        function onEntriesChanged(): void {
            root.refresh();
        }
    }

    Component {
        id: addonLoader

        FileView {
            id: loader

            property var contributionData: null

            printErrors: false

            onLoaded: {
                try {
                    const addon = loader.contributionData;
                    const target = root._definitions[addon.key];
                    if (!target || !target.definition) {
                        root.diagnostics = root.diagnostics.concat([`${addon.pluginId}:${addon.addonId}: add-on target not loaded`]);
                        return;
                    }
                    const clean = Packs.sanitizeAddon(JSON.parse(loader.text()), target.definition);
                    if (!clean) {
                        root.diagnostics = root.diagnostics.concat([`${addon.pluginId}:${addon.addonId}: invalid add-on`]);
                        return;
                    }
                    const next = Object.assign({}, root._addons);
                    next[addon.key] = (next[addon.key] || []).concat([clean]);
                    root._addons = next;
                } catch (e) {
                    root.diagnostics = root.diagnostics.concat([`${loader.contributionData.pluginId}: unreadable add-on`]);
                }
            }

            onLoadFailed: root.diagnostics = root.diagnostics.concat([`${loader.contributionData.pluginId}: add-on could not be read`])
        }
    }

    Component.onCompleted: refresh()
}

.pragma library

// Pure data-only companion definition model (docs/COMPANION_PLATFORM.md).
// The Python package validator is the admission authority; this module
// is the runtime's defence-in-depth sanitizer and semantic resolver.
// It never loads files, starts processes or calls a network/model API.
//
// Identity rule: a missing action resolves only inside the selected
// skin, then to that skin's idle reel. It never borrows a frame from
// another skin or character.

var ACTIONS = [
    "idle", "blink", "look", "greet", "walk", "move", "appear", "leave",
    "rest", "sleep", "talk", "listen", "think", "work", "approve",
    "celebrate", "deny", "worry", "error", "drag", "peek", "hover",
    "takeoff", "fly", "land", "perch", "hop", "preen", "stretch",
    "swim", "climb", "roll", "burrow"
];

var CAPABILITIES = [
    "stationary", "grounded", "walk", "fly", "swim", "climb", "roll",
    "burrow", "perch", "talk", "listen", "think", "work", "sleep",
    "greet", "celebrate", "concern"
];

var SEMANTIC_FALLBACKS = {
    "appear": ["greet", "look", "idle"],
    "leave": ["walk", "move", "idle"],
    "move": ["walk", "idle"],
    "rest": ["sleep", "idle"],
    "celebrate": ["approve", "greet", "idle"],
    "approve": ["celebrate", "greet", "idle"],
    "error": ["worry", "look", "idle"],
    "deny": ["worry", "look", "idle"],
    "worry": ["look", "idle"],
    "takeoff": ["fly", "hop", "idle"],
    "land": ["fly", "hop", "idle"],
    "drag": ["look", "idle"]
};

var MAX_SKINS = 16;
var MAX_ANIMATIONS = 32;
var MAX_FRAMES = 120;
var MAX_TOTAL_FRAMES = 2000;

function _obj(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

function _id(value) {
    return typeof value === "string" && /^[a-z][a-zA-Z0-9]{0,31}$/.test(value);
}

function _text(value, max) {
    return typeof value === "string" && /\S/.test(value) && value.length <= max ? value : "";
}

function _safePath(value) {
    return typeof value === "string" && value.length <= 240
        && /^(?!\/)(?!\.{1,2}(?:\/|$))(?!.*\/\.{1,2}(?:\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+$/.test(value)
        && value.indexOf("://") < 0 && value.indexOf("\\") < 0;
}

function _int(value, fallback, min, max) {
    return Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

function _localized(value, max) {
    if (!_obj(value))
        return ({});
    const out = {};
    for (const locale of Object.keys(value)) {
        if (!/^[a-z]{2,3}(_[A-Z]{2})?$/.test(locale))
            continue;
        const text = _text(value[locale], max);
        if (text)
            out[locale] = text;
    }
    return out;
}

function localizedText(map, locale) {
    if (!_obj(map))
        return "";
    const wanted = String(locale || "en");
    if (map[wanted])
        return map[wanted];
    const language = wanted.split(/[-_]/)[0];
    if (map[language])
        return map[language];
    if (map.en)
        return map.en;
    const keys = Object.keys(map);
    return keys.length ? map[keys[0]] : "";
}

function _frameDescriptors(anim) {
    const frameMs = _int(anim.frameMs, 160, 40, 10000);
    const out = [];
    if (Array.isArray(anim.frames)) {
        for (const frame of anim.frames.slice(0, MAX_FRAMES)) {
            if (!_obj(frame))
                continue;
            let layers = [];
            if (typeof frame.file === "string" && _safePath(frame.file))
                layers = [frame.file];
            else if (Array.isArray(frame.layers))
                layers = frame.layers.filter(f => _safePath(f)).slice(0, 4);
            if (!layers.length)
                continue;
            out.push({
                file: layers[0],
                layers: layers.slice(),
                clip: null,
                ms: _int(frame.ms, frameMs, 40, 10000)
            });
        }
        return out;
    }
    if (_obj(anim.atlas) && _safePath(anim.atlas.file)) {
        const atlas = anim.atlas;
        const fw = atlas.frameWidth, fh = atlas.frameHeight;
        const cols = atlas.columns, count = Math.min(MAX_FRAMES, atlas.count || 0);
        if (![fw, fh, cols, count].every(n => Number.isInteger(n) && n > 0))
            return out;
        for (let i = 0; i < count; i++) {
            const duration = Array.isArray(atlas.durations) ? atlas.durations[i] : frameMs;
            out.push({
                file: atlas.file,
                layers: [atlas.file],
                clip: [(i % cols) * fw, Math.floor(i / cols) * fh, fw, fh],
                ms: _int(duration, frameMs, 40, 10000)
            });
        }
    }
    return out;
}

function _sanitizeAnimation(raw, canvasAnchors) {
    if (!_obj(raw))
        return null;
    const frames = _frameDescriptors(raw);
    if (!frames.length)
        return null;
    const anchor = typeof raw.anchor === "string" && canvasAnchors[raw.anchor] ? raw.anchor : "ground";
    return {
        frames: frames,
        frameMs: _int(raw.frameMs, 160, 40, 10000),
        loop: raw.loop === true,
        next: ACTIONS.indexOf(raw.next) >= 0 ? raw.next : "",
        anchor: anchor,
        fallbacks: (Array.isArray(raw.fallbacks) ? raw.fallbacks : []).filter(a => ACTIONS.indexOf(a) >= 0).slice(0, 8),
        reducedMotionFrame: Math.max(0, Math.min(frames.length - 1, _int(raw.reducedMotionFrame, 0, 0, MAX_FRAMES)))
    };
}

function sanitizeDefinition(raw, expectedId) {
    if (!_obj(raw) || raw.schemaVersion !== 1 || !_id(raw.id))
        return null;
    if (expectedId && raw.id !== expectedId)
        return null;
    const names = _localized(raw.names, 48);
    if (!names.en)
        return null;
    if (!_obj(raw.canvas) || !_obj(raw.canvas.anchors))
        return null;
    const width = _int(raw.canvas.width, 0, 32, 2048);
    const height = _int(raw.canvas.height, 0, 32, 2048);
    if (!width || !height || width * height > 4194304)
        return null;
    const anchors = {};
    for (const name of Object.keys(raw.canvas.anchors).slice(0, 16)) {
        const point = raw.canvas.anchors[name];
        if (!_id(name) || !Array.isArray(point) || point.length !== 2)
            continue;
        const x = point[0], y = point[1];
        if (Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x <= width && y >= 0 && y <= height)
            anchors[name] = [x, y];
    }
    if (!anchors.ground || !anchors.center)
        return null;
    if (!_obj(raw.skins) || !raw.skins[raw.defaultSkin])
        return null;

    let totalFrames = 0;
    const skins = {};
    for (const skinId of Object.keys(raw.skins).slice(0, MAX_SKINS)) {
        if (!_id(skinId) || !_obj(raw.skins[skinId]))
            continue;
        const source = raw.skins[skinId];
        const skinNames = _localized(source.names, 48);
        if (!skinNames.en || !_obj(source.animations) || !source.animations.idle)
            continue;
        const animations = {};
        for (const action of Object.keys(source.animations).slice(0, MAX_ANIMATIONS)) {
            if (ACTIONS.indexOf(action) < 0)
                continue;
            const anim = _sanitizeAnimation(source.animations[action], anchors);
            if (anim) {
                animations[action] = anim;
                totalFrames += anim.frames.length;
            }
        }
        if (!animations.idle || totalFrames > MAX_TOTAL_FRAMES)
            continue;
        const accessories = [];
        if (Array.isArray(source.accessories)) {
            for (const item of source.accessories.slice(0, 8)) {
                if (!_obj(item) || !_id(item.id) || !_safePath(item.file))
                    continue;
                accessories.push({
                    id: item.id,
                    names: _localized(item.names, 48),
                    file: item.file,
                    zIndex: _int(item.zIndex, 1, -2, 2)
                });
            }
        }
        const accessoryIds = accessories.map(a => a.id);
        skins[skinId] = {
            id: skinId,
            names: skinNames,
            animations: animations,
            accessories: accessories,
            defaultAccessories: (Array.isArray(source.defaultAccessories) ? source.defaultAccessories : [])
                .filter(id => accessoryIds.indexOf(id) >= 0)
        };
    }
    if (!skins[raw.defaultSkin] || totalFrames > MAX_TOTAL_FRAMES)
        return null;

    let habitat = null;
    if (_obj(raw.habitat) && _id(raw.habitat.id) && _safePath(raw.habitat.image) && anchors[raw.habitat.anchor]) {
        habitat = {
            id: raw.habitat.id,
            names: _localized(raw.habitat.names, 48),
            image: raw.habitat.image,
            anchor: raw.habitat.anchor,
            defaultScale: Math.max(0.25, Math.min(3, Number(raw.habitat.defaultScale) || 1)),
            sleepAnimation: ACTIONS.indexOf(raw.habitat.sleepAnimation) >= 0 ? raw.habitat.sleepAnimation : "sleep"
        };
    }
    let personality = null;
    if (_obj(raw.personality) && Array.isArray(raw.personality.options)) {
        const options = [];
        for (const option of raw.personality.options.slice(0, 8)) {
            if (!_obj(option) || !_id(option.id))
                continue;
            const traits = (Array.isArray(option.traits) ? option.traits : [])
                .filter(t => ["calm", "playful", "curious", "focused", "quiet", "cheerful", "sleepy", "mischievous", "gentle", "technical"].indexOf(t) >= 0)
                .slice(0, 6);
            const lines = {};
            if (_obj(option.lines)) {
                for (const action of Object.keys(option.lines).slice(0, 16)) {
                    if (ACTIONS.indexOf(action) >= 0)
                        lines[action] = _localized(option.lines[action], 120);
                }
            }
            options.push({ id: option.id, names: _localized(option.names, 48), traits: traits, lines: lines });
        }
        if (options.some(o => o.id === raw.personality.default))
            personality = { default: raw.personality.default, options: options };
    }
    return {
        schemaVersion: 1,
        id: raw.id,
        version: _text(raw.version, 80) || "0.0.0",
        names: names,
        descriptions: _localized(raw.descriptions, 280),
        archetype: _id(raw.archetype) ? raw.archetype : "",
        provenance: _obj(raw.provenance) ? {
            author: _text(raw.provenance.author, 120),
            license: _text(raw.provenance.license, 80),
            source: typeof raw.provenance.source === "string" && raw.provenance.source.indexOf("https://") === 0 ? raw.provenance.source : "",
            attribution: _text(raw.provenance.attribution, 500),
            tool: _text(raw.provenance.tool, 120)
        } : ({ author: "", license: "", source: "", attribution: "", tool: "" }),
        preview: _safePath(raw.preview) ? raw.preview : "",
        canvas: { width: width, height: height, anchors: anchors },
        defaultSkin: raw.defaultSkin,
        skins: skins,
        capabilities: (Array.isArray(raw.capabilities) ? raw.capabilities : []).filter(c => CAPABILITIES.indexOf(c) >= 0),
        personality: personality,
        habitat: habitat,
        assistantCompatibility: (Array.isArray(raw.assistantCompatibility) ? raw.assistantCompatibility : [])
            .filter(c => ["none", "hermes", "veasel"].indexOf(c) >= 0)
    };
}

function resolveSkin(definition, skinId) {
    if (!definition || !definition.skins)
        return null;
    return definition.skins[skinId] || definition.skins[definition.defaultSkin] || null;
}

function resolveAnimation(definition, skinId, action) {
    const skin = resolveSkin(definition, skinId);
    if (!skin)
        return null;
    const wanted = ACTIONS.indexOf(action) >= 0 ? action : "idle";
    const direct = skin.animations[wanted];
    if (direct)
        return { skinId: skin.id, action: wanted, animation: direct };
    const chain = [].concat(SEMANTIC_FALLBACKS[wanted] || [], ["idle"]);
    for (const candidate of chain) {
        if (skin.animations[candidate])
            return { skinId: skin.id, action: candidate, animation: skin.animations[candidate] };
    }
    return skin.animations.idle ? { skinId: skin.id, action: "idle", animation: skin.animations.idle } : null;
}

function sanitizeInstance(raw, charactersByKey) {
    if (!_obj(raw) || typeof raw.id !== "string" || !/^[a-z0-9][a-z0-9-]{0,63}$/.test(raw.id))
        return null;
    if (typeof raw.characterId !== "string" || !/^[a-z0-9][a-z0-9-]{0,47}:[a-z][a-zA-Z0-9]{0,31}$/.test(raw.characterId))
        return null;
    const character = charactersByKey ? charactersByKey[raw.characterId] : null;
    const skinIds = character && character.definition ? Object.keys(character.definition.skins) : [];
    const fallbackSkin = character && character.definition ? character.definition.defaultSkin : "default";
    const finite = (value, fallback, min, max) => {
        const n = Number(value);
        return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback;
    };
    return {
        id: raw.id,
        characterId: raw.characterId,
        legacy: raw.legacy === true,
        enabled: raw.enabled !== false,
        skin: skinIds.indexOf(raw.skin) >= 0 ? raw.skin : (character ? fallbackSkin : (_id(raw.skin) ? raw.skin : fallbackSkin)),
        posX: finite(raw.posX, 0.82, 0, 1),
        posY: finite(raw.posY, 0.88, 0, 1),
        screenName: typeof raw.screenName === "string" ? raw.screenName.slice(0, 80) : "",
        scale: finite(raw.scale, 1, 0.5, 2),
        habitatEnabled: raw.habitatEnabled !== false,
        habitatPosX: finite(raw.habitatPosX, 0.82, 0, 1),
        habitatPosY: finite(raw.habitatPosY, 0.9, 0, 1),
        accessories: Array.isArray(raw.accessories) ? raw.accessories.filter(a => typeof a === "string").slice(0, 8) : [],
        personalityId: typeof raw.personalityId === "string" ? raw.personalityId : "",
        reactions: raw.reactions === true,
        assistantBinding: ["none", "hermes", "veasel"].indexOf(raw.assistantBinding) >= 0 ? raw.assistantBinding : "none"
    };
}

function sanitizeInstanceDocument(raw, charactersByKey) {
    const source = _obj(raw) ? raw : {};
    const instances = [];
    const seen = {};
    if (Array.isArray(source.instances)) {
        for (const item of source.instances.slice(0, 32)) {
            const clean = sanitizeInstance(item, charactersByKey);
            if (clean && !seen[clean.id]) {
                seen[clean.id] = true;
                instances.push(clean);
            }
        }
    }
    if (!instances.some(i => i.characterId === "hornero:javi")) {
        instances.unshift({
            id: "javi-default", characterId: "hornero:javi", legacy: true, enabled: true,
            skin: "default", posX: 0.82, posY: 0.88, screenName: "", scale: 1,
            habitatEnabled: true, accessories: [], personalityId: "", reactions: true,
            assistantBinding: "hermes"
        });
    }
    return {
        schemaVersion: 1,
        nextSerial: Math.max(2, _int(source.nextSerial, 2, 2, 1000000)),
        reactionTarget: typeof source.reactionTarget === "string" && source.reactionTarget.length <= 80 ? source.reactionTarget : "primary",
        instances: instances
    };
}

// Sanitize one add-on definition against its target character.
// Returns only new skins (ids the character does not already own)
// and a habitat when the character has none; identity conflicts are
// dropped, never overwritten.
function sanitizeAddon(raw, targetDefinition) {
    if (!_obj(raw) || raw.schemaVersion !== 1 || !targetDefinition)
        return null;
    if (raw.character !== targetDefinition.id)
        return null;
    const anchors = targetDefinition.canvas.anchors;
    const out = { character: raw.character, skins: {}, habitat: null };
    if (_obj(raw.skins)) {
        for (const skinId of Object.keys(raw.skins).slice(0, MAX_SKINS)) {
            if (!_id(skinId) || targetDefinition.skins[skinId] || !_obj(raw.skins[skinId]))
                continue;
            const source = raw.skins[skinId];
            const skinNames = _localized(source.names, 48);
            if (!skinNames.en || !_obj(source.animations) || !source.animations.idle)
                continue;
            const animations = {};
            let frames = 0;
            for (const action of Object.keys(source.animations).slice(0, MAX_ANIMATIONS)) {
                if (ACTIONS.indexOf(action) < 0)
                    continue;
                const anim = _sanitizeAnimation(source.animations[action], anchors);
                if (anim) {
                    animations[action] = anim;
                    frames += anim.frames.length;
                }
            }
            if (animations.idle && frames <= MAX_TOTAL_FRAMES)
                out.skins[skinId] = { id: skinId, names: skinNames, animations: animations, accessories: [], defaultAccessories: [] };
        }
    }
    if (!targetDefinition.habitat && _obj(raw.habitat) && _id(raw.habitat.id)
            && _safePath(raw.habitat.image) && anchors[raw.habitat.anchor]) {
        out.habitat = {
            id: raw.habitat.id,
            names: _localized(raw.habitat.names, 48),
            image: raw.habitat.image,
            anchor: raw.habitat.anchor,
            defaultScale: Math.max(0.25, Math.min(3, Number(raw.habitat.defaultScale) || 1)),
            sleepAnimation: ACTIONS.indexOf(raw.habitat.sleepAnimation) >= 0 ? raw.habitat.sleepAnimation : "sleep"
        };
    }
    if (!Object.keys(out.skins).length && !out.habitat)
        return null;
    return out;
}

// Pure merge used by the registry (and Node tests): returns a new
// definition; the input is never mutated.
function mergeAddons(definition, addons) {
    if (!definition || !Array.isArray(addons) || !addons.length)
        return definition;
    const merged = JSON.parse(JSON.stringify(definition));
    for (const addon of addons) {
        if (!addon || addon.character !== definition.id)
            continue;
        for (const skinId of Object.keys(addon.skins || {})) {
            if (!merged.skins[skinId])
                merged.skins[skinId] = addon.skins[skinId];
        }
        if (!merged.habitat && addon.habitat)
            merged.habitat = addon.habitat;
    }
    return merged;
}

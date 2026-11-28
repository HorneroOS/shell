.pragma library

// Pure state machine for Reversible Live Preview transactions in Hornero Welcome.
// Tracks baseline vs staged appearance changes, dirty state, commit/revert
// transitions, and crash recovery serialization for
// $XDG_STATE_HOME/hornero/welcome-preview-tx.json.

var TX_SCHEMA_VERSION = 1;

function _copyBaseline(b) {
    if (!b || typeof b !== "object")
        return {
            themeId: "",
            themeMode: "dark",
            wallpaperPath: "",
            layoutPreset: "",
            chromaticActive: false
        };
    return {
        themeId: typeof b.themeId === "string" ? b.themeId : "",
        themeMode: b.themeMode === "light" ? "light" : "dark",
        wallpaperPath: typeof b.wallpaperPath === "string" ? b.wallpaperPath : "",
        layoutPreset: typeof b.layoutPreset === "string" ? b.layoutPreset : "",
        chromaticActive: b.chromaticActive === true
    };
}

function _copyStaged(s, baseline) {
    var b = _copyBaseline(baseline);
    if (!s || typeof s !== "object")
        return b;
    return {
        themeId: typeof s.themeId === "string" ? s.themeId : b.themeId,
        themeMode: s.themeMode === "light" || s.themeMode === "dark" ? s.themeMode : b.themeMode,
        wallpaperPath: typeof s.wallpaperPath === "string" ? s.wallpaperPath : b.wallpaperPath,
        layoutPreset: typeof s.layoutPreset === "string" ? s.layoutPreset : b.layoutPreset,
        chromaticActive: typeof s.chromaticActive === "boolean" ? s.chromaticActive : b.chromaticActive
    };
}

function createInitialTx() {
    return {
        schemaVersion: TX_SCHEMA_VERSION,
        active: false,
        dirty: false,
        txId: "",
        startedAt: "",
        baseline: null,
        staged: null
    };
}

function isDirty(baseline, staged) {
    if (!baseline || !staged)
        return false;
    return baseline.themeId !== staged.themeId
        || baseline.wallpaperPath !== staged.wallpaperPath
        || baseline.layoutPreset !== staged.layoutPreset
        || baseline.chromaticActive !== staged.chromaticActive;
}

function begin(tx, baseline, nowMs, nowIso) {
    if (tx && tx.active === true && tx.baseline) {
        return {
            schemaVersion: TX_SCHEMA_VERSION,
            active: true,
            dirty: isDirty(tx.baseline, tx.staged),
            txId: tx.txId,
            startedAt: tx.startedAt,
            baseline: _copyBaseline(tx.baseline),
            staged: _copyStaged(tx.staged, tx.baseline)
        };
    }
    var b = _copyBaseline(baseline);
    var ts = typeof nowMs === "number" ? Math.round(nowMs) : 0;
    return {
        schemaVersion: TX_SCHEMA_VERSION,
        active: true,
        dirty: false,
        txId: "tx-" + String(ts),
        startedAt: typeof nowIso === "string" ? nowIso : "",
        baseline: b,
        staged: _copyBaseline(b)
    };
}

function update(tx, patch) {
    if (!tx || tx.active !== true || !tx.baseline)
        return createInitialTx();
    var nextStaged = _copyStaged(tx.staged, tx.baseline);
    if (patch && typeof patch === "object") {
        if (typeof patch.themeId === "string")
            nextStaged.themeId = patch.themeId;
        if (patch.themeMode === "light" || patch.themeMode === "dark")
            nextStaged.themeMode = patch.themeMode;
        if (typeof patch.wallpaperPath === "string")
            nextStaged.wallpaperPath = patch.wallpaperPath;
        if (typeof patch.layoutPreset === "string")
            nextStaged.layoutPreset = patch.layoutPreset;
        if (typeof patch.chromaticActive === "boolean")
            nextStaged.chromaticActive = patch.chromaticActive;
    }
    return {
        schemaVersion: TX_SCHEMA_VERSION,
        active: true,
        dirty: isDirty(tx.baseline, nextStaged),
        txId: tx.txId,
        startedAt: tx.startedAt,
        baseline: _copyBaseline(tx.baseline),
        staged: nextStaged
    };
}

function commit(tx) {
    if (!tx || tx.active !== true || !tx.baseline) {
        return {
            tx: createInitialTx(),
            persistTheme: false,
            persistWallpaper: false,
            persistLayout: false,
            targetThemeId: "",
            targetWallpaperPath: "",
            targetLayoutPreset: ""
        };
    }
    var b = tx.baseline;
    var s = tx.staged || b;
    return {
        tx: createInitialTx(),
        persistTheme: s.themeId !== "" && s.themeId !== b.themeId,
        persistWallpaper: s.wallpaperPath !== "" && s.wallpaperPath !== b.wallpaperPath,
        persistLayout: s.layoutPreset !== "" && s.layoutPreset !== b.layoutPreset,
        targetThemeId: s.themeId,
        targetWallpaperPath: s.wallpaperPath,
        targetLayoutPreset: s.layoutPreset
    };
}

function revert(tx) {
    if (!tx || !tx.baseline) {
        return {
            tx: createInitialTx(),
            restoreTheme: false,
            restoreWallpaper: false,
            restoreLayout: false,
            baseline: null
        };
    }
    var b = _copyBaseline(tx.baseline);
    var s = tx.staged || b;
    return {
        tx: createInitialTx(),
        restoreTheme: b.themeId !== "" && s.themeId !== b.themeId,
        restoreWallpaper: b.wallpaperPath !== "" && s.wallpaperPath !== b.wallpaperPath,
        restoreLayout: b.layoutPreset !== "" && s.layoutPreset !== b.layoutPreset,
        baseline: b
    };
}

function serialize(tx) {
    if (!tx || tx.active !== true || !tx.baseline)
        return JSON.stringify({ schemaVersion: TX_SCHEMA_VERSION, active: false }, null, 2);
    return JSON.stringify({
        schemaVersion: TX_SCHEMA_VERSION,
        active: true,
        dirty: tx.dirty === true,
        txId: String(tx.txId || ""),
        startedAt: String(tx.startedAt || ""),
        baseline: _copyBaseline(tx.baseline),
        staged: _copyStaged(tx.staged, tx.baseline)
    }, null, 2);
}

function parse(rawText) {
    var fallback = createInitialTx();
    if (typeof rawText !== "string" || rawText.trim() === "")
        return fallback;
    var o = null;
    try {
        o = JSON.parse(rawText);
    } catch (e) {
        return fallback;
    }
    if (!o || typeof o !== "object" || Array.isArray(o) || o.schemaVersion !== TX_SCHEMA_VERSION)
        return fallback;
    if (o.active !== true || !o.baseline || typeof o.baseline !== "object")
        return fallback;
    var b = _copyBaseline(o.baseline);
    var s = _copyStaged(o.staged, b);
    return {
        schemaVersion: TX_SCHEMA_VERSION,
        active: true,
        dirty: o.dirty === true || isDirty(b, s),
        txId: typeof o.txId === "string" ? o.txId : "",
        startedAt: typeof o.startedAt === "string" ? o.startedAt : "",
        baseline: b,
        staged: s
    };
}

function needsCrashRecovery(txOrRaw) {
    var tx = typeof txOrRaw === "string" ? parse(txOrRaw) : txOrRaw;
    if (!tx || tx.active !== true || !tx.baseline)
        return false;
    var b = tx.baseline;
    return b.themeId !== "" || b.wallpaperPath !== "" || b.layoutPreset !== "";
}

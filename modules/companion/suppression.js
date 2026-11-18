.pragma library

// Companion suppression: the pure rules for "is Javi hidden right now,
// and by what". No QML, no timers, no I/O, so the lock-latch regression
// (shell#652) is unit-tested under node.
//
// shell#652: the session-lock input was only refreshed from the
// upstream `lockStateChanged` notify. WlSessionLock does not emit that
// notify when `locked` drops to false on the unlock path (nor when the
// compositor ends the lock on its own), so the flag latched at true and
// Javi never came back after an unlock. The getter is always right;
// the notify is not. `lockedNow` reads the getter, and `shouldPollLock`
// tells the host to re-read it on a slow timer for as long as the flag
// is set (zero cost while unlocked).

var LOCK_POLL_MS = 500;

// Authoritative read of the session lock. A missing lock (external lock
// owner, early startup) means "not locked".
function lockedNow(lock) {
    return lock !== null && lock !== undefined && lock.locked === true;
}

// The five inputs, named the way `companion status` reports them.
function reasons(inputs) {
    var i = inputs || {};
    return {
        locked: !!i.locked,
        fullscreen: !!i.fullscreen,
        gameMode: !!i.gameMode,
        areaPicker: !!i.areaPicker,
        controlCenter: !!i.controlCenter
    };
}

function isSuppressed(r) {
    return !!(r && (r.locked || r.fullscreen || r.gameMode || r.areaPicker || r.controlCenter));
}

// One reconciliation step: what the stored lock flag should become after
// re-reading the lock, and whether the host must keep polling.
function reconcileLock(storedFlag, lock) {
    var now = lockedNow(lock);
    return { flag: now, changed: now !== !!storedFlag, poll: now };
}

// Visible = enabled, not suppressed (unless an explicit request forces
// it), not persistently hidden, not hidden by the active mode look.
function isVisible(enabled, suppressed, forceVisible, persistedState, modeHidden) {
    return !!enabled && (!suppressed || !!forceVisible) && persistedState !== "hidden" && !modeHidden;
}

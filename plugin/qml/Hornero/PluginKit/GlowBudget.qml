pragma Singleton

import QtQuick

// Internal: rations the luminous accent (visual language §9: at most
// three glowing items on a screen). The budget itself is the shell's
// (Experience.acquireGlow), shared with the native instruments, so the
// deck's traces, the dashboard scopes and the on-air bar can never exceed
// three together. Extension traces leave one slot to the shell. Instruments
// ask for a lease when they want to glow; those that are refused render the
// same trace without glow. Leases are released on destruction.
QtObject {
    id: root

    readonly property int limit: 3
    // Slots extensions never take, kept for the shell's own instruments.
    readonly property int reserved: 1
    readonly property int held: ExperienceBridge.glowHeld

    function acquire(owner: var): bool {
        return ExperienceBridge.acquireGlow(owner, root.reserved);
    }

    function release(owner: var): void {
        ExperienceBridge.releaseGlow(owner);
    }
}

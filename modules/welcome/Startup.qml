import "../../services/welcome_model.js" as WelcomeModel
import qs.modules.welcome as WelcomeModule
import QtQuick

// Login-time auto-open and preview crash-recovery evaluator.
// Evaluates exactly once after State, Session, and PreviewTransaction settle.
// - Never replays First Flight once `firstRunCompleted === true`.
// - Never opens on login when `showOnLogin === false`.
// - Opens What's New automatically only when `showOnLogin === true`,
//   `firstRunCompleted === true`, and a newer release version is unseen.
QtObject {
    id: root

    property bool _done: false
    property bool _recoveryDone: false

    Component.onCompleted: {
        WelcomeModule.State.readyChanged.connect(root.evaluate);
        WelcomeModule.Session.markerKnownChanged.connect(root.evaluate);
        WelcomeModule.PreviewTransaction.readyChanged.connect(root.evaluateRecovery);
        Qt.callLater(root.evaluateRecovery);
        Qt.callLater(root.evaluate);
    }

    function evaluateRecovery(): void {
        if (root._recoveryDone)
            return;
        if (!WelcomeModule.PreviewTransaction.ready)
            return;
        root._recoveryDone = true;
        WelcomeModule.PreviewTransaction.checkAndRecoverOnStartup();
    }

    function evaluate(): void {
        if (root._done)
            return;
        if (!WelcomeModule.State.ready || !WelcomeModule.Session.markerKnown)
            return;
        root._done = true;

        if (!WelcomeModule.Session.shouldAutoOpen)
            return;

        const decision = WelcomeModel.evaluateStartup(
            WelcomeModule.State.snapshotObject(),
            WelcomeModule.Session.markerExists,
            WelcomeModule.Session._noted,
            WelcomeModule.State.currentReleaseVersion,
            WelcomeModule.State.hasUnseenRelease
        );
        if (!decision.shouldOpen)
            return;
        if (decision.reason === "first-run")
            WelcomeModule.Welcome.open("start");
        else if (decision.reason === "release-update")
            WelcomeModule.Welcome.open("whats-new");
    }
}

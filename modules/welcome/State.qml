pragma Singleton

import "../../services/welcome_model.js" as WelcomeModel
import "../../services/welcome_whatsnew.js" as WhatsNew
import qs.utils
import qs.services
import Hornero
import Quickshell
import Quickshell.Io
import QtQuick

// Welcome state reader & v2 onboarding progress tracker.
// Mirrors the Hornero-wide contract owned by HorneroOS/hornero:
// - Reads `$XDG_STATE_HOME/hornero/welcome/state.json` directly via FileView
//   and writes `showOnLogin` / `markSeen` ONLY through `horneroctl welcome ... --yes`.
// - Persists v2 onboarding metadata (`firstRunCompleted`, `lastSeenReleaseVersion`,
//   `completedTutorials`, `selectedInterests`, `mascotEnabled`, `lastVisitedScene`)
//   in `$XDG_STATE_HOME/hornero/welcome/progress.json` via FileView.setText so
//   upgraded v1 users keep `showOnLogin=false` and never replay First Flight.
Singleton {
    id: root

    readonly property string defaultContentRevision: "p2"
    readonly property string currentReleaseVersion: WelcomeModel.CURRENT_RELEASE_VERSION

    property int schemaVersion: 2
    property bool showOnLogin: true
    property string contentRevision: defaultContentRevision
    property string lastSeenContentRevision: ""
    property bool firstRunCompleted: false
    property string firstRunCompletedAt: ""
    property string lastSeenReleaseVersion: ""
    property string lastVisitedScene: "arrival"
    property var completedTutorials: []
    property var selectedInterests: []
    property bool mascotEnabled: true
    property string firstOpenedAt: ""
    property string lastOpenedAt: ""

    property bool _stateLoaded: false
    property bool _progressLoaded: false
    property string _rawStateText: ""
    property string _rawProgressText: ""
    property bool ready: false

    // Write health: set when a horneroctl write fails or times out.
    property bool writeFailed: false
    property string lastWriteError: ""
    property bool horneroctlMissing: false

    readonly property string stateFilePath: `${Paths.state}/welcome/state.json`
    readonly property string progressFilePath: `${Paths.state}/welcome/progress.json`

    readonly property bool hasUnseenRelease: WhatsNew.hasUnseenRelease(root.currentReleaseVersion, root.lastSeenReleaseVersion)

    function _syncFromFiles(): void {
        const base = WelcomeModel.parseState(root._rawStateText);
        const merged = WelcomeModel.mergeProgress(base, root._rawProgressText);
        root.schemaVersion = merged.schemaVersion;
        root.showOnLogin = merged.showOnLogin;
        root.contentRevision = merged.contentRevision;
        root.lastSeenContentRevision = merged.lastSeenContentRevision;
        root.firstRunCompleted = merged.firstRunCompleted;
        root.firstRunCompletedAt = merged.firstRunCompletedAt;
        root.lastSeenReleaseVersion = merged.lastSeenReleaseVersion;
        root.lastVisitedScene = merged.lastVisitedScene;
        root.completedTutorials = merged.completedTutorials;
        root.selectedInterests = merged.selectedInterests;
        root.mascotEnabled = merged.mascotEnabled;
        root.firstOpenedAt = merged.firstOpenedAt;
        root.lastOpenedAt = merged.lastOpenedAt;
        if (root._stateLoaded && root._progressLoaded)
            root.ready = true;
    }

    function parse(text: string): void {
        root._rawStateText = text ?? "";
        root._syncFromFiles();
    }

    function _saveProgress(): void {
        const doc = WelcomeModel.serializeProgress({
            schemaVersion: 2,
            firstRunCompleted: root.firstRunCompleted,
            firstRunCompletedAt: root.firstRunCompletedAt,
            lastSeenReleaseVersion: root.lastSeenReleaseVersion,
            lastVisitedScene: root.lastVisitedScene,
            completedTutorials: root.completedTutorials,
            selectedInterests: root.selectedInterests,
            mascotEnabled: root.mascotEnabled
        });
        progressFile.setText(doc);
    }

    // Single-writer queue: at most one horneroctl child at a time.
    property var _queue: []

    function _enqueue(argv: var): void {
        root._queue.push(argv);
        root._pump();
    }

    function _pump(): void {
        if (writer.running || root._queue.length === 0)
            return;
        writer.command = root._queue.shift();
        watchdog.restart();
        writer.running = true;
    }

    function _fail(message: string, missing: bool): void {
        watchdog.stop();
        root.writeFailed = true;
        if (missing)
            root.horneroctlMissing = true;
        root.lastWriteError = message;
        Toaster.toast(qsTr("Welcome"), message, "refresh-alert", Toast.Warning);
        console.warn("[welcome]", message);
    }

    function writeShowOnLogin(value: bool): void {
        root.showOnLogin = value;
        root.writeFailed = false;
        root.lastWriteError = "";
        root._enqueue(["horneroctl", "welcome", "set-show-on-login", value ? "true" : "false", "--yes"]);
    }

    function markSeen(): void {
        root._enqueue(["horneroctl", "welcome", "mark-seen", "--yes"]);
    }

    function markFirstRunCompleted(): void {
        if (!root.firstRunCompleted) {
            root.firstRunCompleted = true;
            root.firstRunCompletedAt = new Date().toISOString();
        }
        if (root.lastSeenReleaseVersion === "")
            root.lastSeenReleaseVersion = root.currentReleaseVersion;
        root._saveProgress();
    }

    function markReleaseSeen(version: string): void {
        const target = (version ?? "").trim() || root.currentReleaseVersion;
        if (root.lastSeenReleaseVersion === target)
            return;
        root.lastSeenReleaseVersion = target;
        root._saveProgress();
    }

    function setLastVisitedScene(sceneId: string): void {
        const s = (sceneId ?? "").trim().toLowerCase();
        if (s === "" || root.lastVisitedScene === s)
            return;
        root.lastVisitedScene = s;
        root._saveProgress();
    }

    function markTutorialCompleted(tutorialId: string): void {
        const id = (tutorialId ?? "").trim().toLowerCase();
        if (WelcomeModel.TUTORIAL_IDS.indexOf(id) === -1)
            return;
        if (root.completedTutorials.indexOf(id) !== -1)
            return;
        root.completedTutorials = root.completedTutorials.concat([id]);
        root._saveProgress();
    }

    function isTutorialCompleted(tutorialId: string): bool {
        return root.completedTutorials.indexOf((tutorialId ?? "").trim().toLowerCase()) !== -1;
    }

    function toggleInterest(interestId: string): void {
        const id = (interestId ?? "").trim().toLowerCase();
        if (WelcomeModel.INTEREST_IDS.indexOf(id) === -1)
            return;
        const idx = root.selectedInterests.indexOf(id);
        const next = root.selectedInterests.slice();
        if (idx >= 0)
            next.splice(idx, 1);
        else
            next.push(id);
        root.selectedInterests = next;
        root._saveProgress();
    }

    function hasInterest(interestId: string): bool {
        return root.selectedInterests.indexOf((interestId ?? "").trim().toLowerCase()) !== -1;
    }

    function setMascotEnabled(enabled: bool): void {
        root.mascotEnabled = enabled === true;
        root._saveProgress();
    }

    function snapshotObject(): var {
        return {
            schemaVersion: root.schemaVersion,
            showOnLogin: root.showOnLogin,
            firstRunCompleted: root.firstRunCompleted,
            firstRunCompletedAt: root.firstRunCompletedAt,
            lastSeenReleaseVersion: root.lastSeenReleaseVersion,
            contentRevision: root.contentRevision,
            lastSeenContentRevision: root.lastSeenContentRevision,
            lastVisitedScene: root.lastVisitedScene,
            completedTutorials: root.completedTutorials,
            selectedInterests: root.selectedInterests,
            mascotEnabled: root.mascotEnabled
        };
    }

    Process {
        id: writer

        onExited: (exitCode, exitStatus) => {
            watchdog.stop();
            if (exitCode !== 0 || exitStatus !== 0) {
                root._fail(qsTr("Welcome: could not save (horneroctl exit %1)").arg(exitCode), exitCode === 127 || exitStatus !== 0);
            } else {
                root.writeFailed = false;
                root.lastWriteError = "";
                root.horneroctlMissing = false;
            }
            root._pump();
        }
    }

    Timer {
        id: watchdog

        interval: 10000
        repeat: false
        onTriggered: {
            if (writer.running)
                writer.running = false;
            root._fail(qsTr("Welcome: horneroctl did not respond; preference kept for this session"), true);
            root._pump();
        }
    }

    FileView {
        path: root.stateFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root._stateLoaded = true;
            root.parse(text());
        }
        onLoadFailed: {
            root._stateLoaded = true;
            root.parse("");
        }
    }

    FileView {
        id: progressFile

        path: root.progressFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root._progressLoaded = true;
            root._rawProgressText = text();
            root._syncFromFiles();
        }
        onLoadFailed: {
            root._progressLoaded = true;
            root._rawProgressText = "";
            root._syncFromFiles();
        }
    }
}

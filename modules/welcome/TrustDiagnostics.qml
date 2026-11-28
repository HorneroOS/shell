pragma Singleton

import qs.modules.apps
import QtQuick
import Quickshell
import Quickshell.Io

// Read-only system diagnostics probe for TrustScene.
// Executes ONLY fixed `horneroctl --json ...` diagnostic queries and
// reports honest real state (never invents snapshot protection or scores).
Singleton {
    id: root

    property bool loading: false
    property bool probed: false

    property string doctorSummary: ""
    property bool doctorOk: false
    property int doctorPassed: 0
    property int doctorTotal: 0

    property int profileCount: 0
    property string activeProfile: ""
    property bool hasBaselineProfile: false

    property int horneroUpdates: -1
    property int systemUpdates: -1
    property bool rebootRequired: false

    property string snapshotBackend: "none"
    property string snapshotStatus: ""
    property bool btrfsReady: false
    property string rootFsType: ""

    property string editionName: ""
    property string compositorName: ""

    function refresh(): void {
        if (root.loading)
            return;
        root.loading = true;
        AppsStore.refreshDoctor();
        doctorProc.running = true;
        profilesProc.running = true;
        packageProc.running = true;
        recoveryProc.running = true;
        sysProc.running = true;
    }

    function _checkDone(): void {
        if (!doctorProc.running && !profilesProc.running && !packageProc.running && !recoveryProc.running && !sysProc.running) {
            root.loading = false;
            root.probed = true;
        }
    }

    function _parseEnv(raw: string): var {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    Process {
        id: doctorProc

        command: ["horneroctl", "--json", "doctor"]
        stdout: StdioCollector {
            onStreamFinished: {
                const env = root._parseEnv(text);
                if (!env) {
                    root.doctorOk = false;
                    root.doctorSummary = qsTr("horneroctl doctor unavailable");
                    return;
                }
                root.doctorOk = env.ok === true;
                const d = env.data || {};
                root.doctorPassed = parseInt(d.passed || "0", 10) || 0;
                root.doctorTotal = parseInt(d.total || "0", 10) || 0;
                const firstLine = String(env.message || "").split("\n")[0] || "";
                root.doctorSummary = firstLine;
            }
        }
        onExited: root._checkDone()
    }

    Process {
        id: profilesProc

        command: ["horneroctl", "--json", "profile", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const env = root._parseEnv(text);
                if (!env || !env.ok)
                    return;
                const d = env.data || {};
                root.profileCount = parseInt(d.count || "0", 10) || 0;
                root.activeProfile = String(d.active || "");
                root.hasBaselineProfile = String(d.has_baseline || "") === "true";
            }
        }
        onExited: root._checkDone()
    }

    Process {
        id: packageProc

        command: ["horneroctl", "--json", "package", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const env = root._parseEnv(text);
                if (!env || !env.ok)
                    return;
                const d = env.data || {};
                const hp = parseInt(d.hornero_pending_count, 10);
                const sp = parseInt(d.system_pending_count, 10);
                root.horneroUpdates = isNaN(hp) ? -1 : hp;
                root.systemUpdates = isNaN(sp) ? -1 : sp;
                root.rebootRequired = String(d.reboot_required || "") === "true";
            }
        }
        onExited: root._checkDone()
    }

    Process {
        id: recoveryProc

        command: ["horneroctl", "--json", "recovery", "doctor"]
        stdout: StdioCollector {
            onStreamFinished: {
                const env = root._parseEnv(text);
                if (!env)
                    return;
                const d = env.data || {};
                root.snapshotBackend = String(d.snapshot_backend || "none");
                root.rootFsType = String(d.root_fstype || "");
                root.btrfsReady = env.ok === true && root.snapshotBackend !== "none";
                root.snapshotStatus = String(env.message || "").split("\n").slice(-1)[0] || "";
            }
        }
        onExited: root._checkDone()
    }

    Process {
        id: sysProc

        command: ["horneroctl", "--json", "system", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const env = root._parseEnv(text);
                if (!env || !env.ok)
                    return;
                const d = env.data || {};
                root.editionName = String(d.edition || "");
                root.compositorName = String(d.activeCompositor || "");
            }
        }
        onExited: root._checkDone()
    }
}

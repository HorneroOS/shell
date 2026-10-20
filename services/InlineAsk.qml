pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Inline Javi ask for the launcher (shell#250 slice 3): `>ai <question>`
// streams the answer inside the launcher instead of only summoning the
// chat panel. Same trust path as the chat: the shell only runs
// `horneroctl assistant ask --json --stream`; it never talks to Hermes
// directly and never holds the gateway credential. Approvals and
// clarifications are NOT answered here — the final payload says so and
// the user continues in the Javi chat panel.
Singleton {
    id: root

    property bool busy: false
    property string text: ""
    property string errorText: ""
    property string askedPrompt: ""
    property var finalPayload: null

    readonly property int textCap: 16384

    function ask(question: string): void {
        const q = (question ?? "").toString().trim();
        if (q === "" || root.busy)
            return;
        root.askedPrompt = q;
        root.text = "";
        root.errorText = "";
        root.finalPayload = null;
        root.busy = true;
        proc.command = ["horneroctl", "assistant", "ask", q, "--json", "--stream"];
        proc.running = true;
    }

    function stop(): void {
        proc.running = false;
        root.busy = false;
    }

    function consume(line: string): void {
        const trimmed = line.trim();
        if (trimmed === "")
            return;
        let obj = null;
        try {
            obj = JSON.parse(trimmed);
        } catch (e) {
            obj = null;
        }
        if (obj && obj.type === "delta" && obj.text) {
            root.text = (root.text + obj.text.toString()).slice(-root.textCap);
        } else if (obj) {
            root.finalPayload = obj;
        }
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: data => root.consume(data)
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            const payload = root.finalPayload;
            if (payload && payload.ok === false) {
                root.errorText = (payload.message ?? qsTr("The assistant did not answer.")).toString();
            } else if (root.text === "" && payload && payload.data && payload.data.text) {
                root.text = payload.data.text.toString().slice(-root.textCap);
            } else if (root.text === "" && !payload) {
                root.errorText = qsTr("The assistant did not answer. Check: horneroctl assistant status");
            }
        }
    }
}

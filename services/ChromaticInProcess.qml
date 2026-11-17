import QtQuick
import Hornero.Chromatic

// In-process Chromatic engine (RFC 0002 §13.1). Loaded at runtime by
// ChromaticPreview only when the Hornero.Chromatic QML module exists; the
// preview otherwise falls back to the hornero-chromatic helper. Never
// writes anything: horneroctl applies.
QtObject {
    id: root

    readonly property bool available: ChromaticEngine.available
    readonly property string version: ChromaticEngine.engineVersion
    property var _job: null

    signal finished(var result)
    signal failed(string code, string message)

    function generate(request: var): void {
        cancel();
        const job = ChromaticEngine.generate(request);
        root._job = job;
        job.finished.connect(result => {
            if (root._job === job)
                root.finished(result);
        });
        job.failed.connect((code, message) => {
            if (root._job === job)
                root.failed(code, message);
        });
    }

    function cancel(): void {
        if (root._job && root._job.running)
            root._job.cancel();
        root._job = null;
    }
}

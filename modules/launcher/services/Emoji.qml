pragma Singleton

import "emoji.js" as Model
import qs.services
import Quickshell
import QtQuick

// Built-in searchable emoji & symbol picker (HorneroOS/shell#737).
// Zero external plugins or subprocesses; copies via Clipboard.copyText.
Singleton {
    id: root

    function query(text: string): list<var> {
        return Model.searchEmojis(text, 50);
    }

    function activate(result: var): void {
        const ch = result?.char ?? "";
        if (typeof ch === "string" && ch.length > 0)
            Clipboard.copyText(ch);
    }
}

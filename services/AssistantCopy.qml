pragma Singleton

import "assistantcopy.js" as Copy
import QtQuick
import Quickshell

// Workbench microcopy lookup (EN + ES). The table lives in
// assistantcopy.js so tests can execute it under node; surfaces call
// AssistantCopy.t("key", lang) with lang from AssistantCopy.lang().
Singleton {
    function t(key: string, language: string): string {
        return Copy.t(key, language);
    }

    function lang(localeName: string): string {
        return Copy.lang(localeName);
    }
}

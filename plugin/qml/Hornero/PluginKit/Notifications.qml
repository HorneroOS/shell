pragma Singleton

import qs.components.misc
import Hornero
import QtQuick

QtObject {
    function toast(summary: string, body: string, icon: string): void {
        if (!summary || summary.trim().length === 0)
            return;

        Toaster.toast(summary.trim().slice(0, 120), (body ?? "").toString().slice(0, 500), icon || "extension");
    }
}

pragma Singleton

import "GlyphMap.js" as GlyphMap
import Quickshell
import QtQuick

// Hornero Glyphs (RFC 0001 §3.4): the shell's bundled icon font, a
// curated Tabler Icons outline subset built by scripts/build-glyphs.py.
// No system icon font is required. Resolve names with `glyph(name)`;
// components should use `Glyph { name: "wifi" }` (components/Glyph.qml).
Singleton {
    id: root

    readonly property string family: loader.status === FontLoader.Ready ? loader.name : GlyphMap.family
    readonly property bool ready: loader.status === FontLoader.Ready
    readonly property var names: Object.keys(GlyphMap.codepoints)
    property var _warned: ({})

    function has(name: string): bool {
        return GlyphMap.codepoints.hasOwnProperty(name);
    }

    // Character for a glyph name, or "" (with one warning per name) when
    // the name is not part of Hornero Glyphs.
    function glyph(name: string): string {
        if (!name)
            return "";
        const cp = GlyphMap.codepoints[name];
        if (cp === undefined) {
            if (!_warned[name]) {
                _warned[name] = true;
                console.warn(`Glyph: unknown glyph name "${name}" (see assets/fonts/hornero-glyphs.names)`);
            }
            return "";
        }
        return String.fromCodePoint(cp);
    }

    FontLoader {
        id: loader

        source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/fonts/hornero-glyphs.ttf`)
    }
}

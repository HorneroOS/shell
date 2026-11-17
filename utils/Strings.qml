pragma Singleton

import Quickshell

Singleton {
    // Display label for a wallpaper file: basename without extension,
    // without a trailing _WxH resolution suffix, separators as spaces.
    // `wallhaven-73v179_1920x1080.png` -> `wallhaven 73v179`. Display
    // only: search/filter keep matching the raw filename. Never blank.
    function wallpaperDisplayName(name: string): string {
        let s = String(name ?? "");
        const slash = s.lastIndexOf("/");
        if (slash >= 0)
            s = s.slice(slash + 1);
        s = s.replace(/\.[A-Za-z0-9]+$/, "");
        s = s.replace(/[_-]\d+x\d+$/, "");
        s = s.replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
        // Strip a stock-site prefix; a bare site id (`73v179`) is not a
        // name, so it becomes `Untitled 73v1` (file stem stays on hover).
        const bare = s.replace(/^(wallhaven|unsplash|pexels|pixabay|wallpaperflare|wallpaperaccess|wp|photo|image|img) /i, "");
        if (bare !== s && /^[A-Za-z0-9]{4,12}$/.test(bare))
            return qsTr("Untitled %1").arg(bare.slice(0, 4));
        return s === "" ? String(name ?? "") : s;
    }

    function testRegexList(filterList: list<string>, target: string): bool {
        const regexChecker = /^\^.*\$$/;
        for (const filter of filterList) {
            // If filter is a regex
            if (regexChecker.test(filter)) {
                if ((new RegExp(filter)).test(target))
                    return true;
            } else {
                if (filter === target)
                    return true;
            }
        }
        return false;
    }
}

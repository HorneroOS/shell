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
        // A stock-site prefix followed by a bare site id (`73v179`) has no
        // name to show; never print the raw id or "Untitled": say where it
        // is from (`Wallhaven wallpaper`). The file stem stays on hover.
        const site = /^(wallhaven|unsplash|pexels|pixabay|wallpaperflare|wallpaperaccess|wp|photo|image|img) /i.exec(s);
        if (site && /^[A-Za-z0-9]{4,12}$/.test(s.slice(site[0].length))) {
            const brand = site[1].toLowerCase();
            const label = (brand === "wp" || brand === "photo" || brand === "image" || brand === "img") ? qsTr("Wallpaper") : brand.charAt(0).toUpperCase() + brand.slice(1);
            return brand === "wp" || brand === "photo" || brand === "image" || brand === "img" ? label : qsTr("%1 wallpaper").arg(label);
        }
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

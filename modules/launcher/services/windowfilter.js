.pragma library

// Pure window filtering for the launcher windows provider
// (shell#250 slice 1). Input rows are plain objects shaped
// { title, appClass, workspaceName, address } in compositor
// order; the ranked result preserves that order (the order the
// bar already presents windows in). Matching is the historic
// launcher behaviour: case-insensitive substring on title or
// app class, empty query lists every window.

function filterWindows(rows, query) {
    var q = (query || "").toLowerCase();
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (!q || (row.title || "").toLowerCase().indexOf(q) >= 0 || (row.appClass || "").toLowerCase().indexOf(q) >= 0)
            out.push(row);
    }
    return out;
}

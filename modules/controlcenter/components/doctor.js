.pragma library

// Pure parser for `horneroctl --json <edition> doctor` envelopes, shared by
// the Studio and Gaming hubs. The envelope carries `data` (check -> "ok" |
// "fail") and `message` (one `ok  name: detail` / `FAIL  name: detail` line
// per check plus a summary line). Rows keep the CLI's wording: the shell
// never invents a verdict. Anything unparsable is reported as unavailable,
// never as a pass.
function parse(text) {
    let env = null;
    try {
        env = JSON.parse((text || "").trim());
    } catch (e) {
        return { "available": false, "checks": [], "summary": "" };
    }
    const data = env.data || {};
    const details = {};
    let summary = "";
    for (const line of (env.message || "").toString().split("\n")) {
        const m = /^(ok|FAIL|WARN|warn)\s+([^:\s]+):\s*(.*)$/.exec(line);
        if (m)
            details[m[2]] = m[3];
        else if (line.trim().length > 0)
            summary = line.trim();
    }
    const checks = Object.keys(data).sort().map(name => ({
                "name": name,
                "ok": data[name] === "ok",
                "detail": details[name] || ""
            }));
    return { "available": true, "checks": checks, "summary": summary };
}

function passing(checks) {
    return checks.filter(c => c.ok).length;
}

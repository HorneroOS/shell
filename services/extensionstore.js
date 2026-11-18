.pragma library

// Extension store logic for Control Center › Extensions (competitive gap
// #4): what a catalogue row says before install, the horneroctl argv each
// lifecycle verb runs, how a failure code becomes guidance, and what an
// extension costs. Pure functions, run under node in
// tests/test_extension_store.py; ExtensionStore.qml and the pane supply
// the data. Nothing here runs plugin code or writes state.

// Lists arrive from QML models as list-likes (QVariantList), for which
// Array.isArray is false; accept anything with a numeric length.
function asArray(v) {
    if (Array.isArray(v))
        return v;
    if (v && typeof v === "object" && typeof v.length === "number")
        return Array.prototype.slice.call(v);
    return [];
}

function isList(v) {
    return Array.isArray(v) || (!!v && typeof v === "object" && typeof v.length === "number");
}

var CATALOGUE_SOURCE = "https://github.com/HorneroOS/plugins.git";

// Verbs the pane may run, with the argv shape horneroctl documents in
// hornero docs/PLUGIN_LIFECYCLE_JSON.md. Every mutating verb carries
// --yes: the pane's own two-step guard is the consent, the CLI flag
// records it.
var VERBS = ["install", "update", "rollback", "remove", "enable", "disable", "trust"];

function commandFor(verb, pluginId, revision) {
    if (VERBS.indexOf(verb) < 0 || !/^[a-z0-9][a-z0-9-]{0,47}$/.test(String(pluginId || "")) || /-$/.test(pluginId))
        return [];
    var argv = ["horneroctl", "--json", "plugin"];
    if (verb === "install" || verb === "update" || verb === "rollback") {
        argv.push("catalog", verb, pluginId);
        if (verb !== "rollback" && /^[0-9a-f]{40}([0-9a-f]{24})?$/.test(String(revision || "")))
            argv.push("--revision", revision);
    } else {
        argv.push(verb, pluginId);
    }
    argv.push("--yes");
    return argv;
}

// What the person sees while a verb runs. horneroctl does not stream
// progress, so the steps are the real ones it performs, in order, shown
// as one honest line with elapsed seconds (no invented percentage).
function progressText(verb, name, seconds, es) {
    var s = Math.max(0, Math.floor(seconds || 0));
    var steps = {
        "install": es ? "descargando el catálogo, verificando SHA-256, validando y copiando" : "fetching the catalogue, verifying SHA-256, validating, copying",
        "update": es ? "descargando el catálogo, verificando SHA-256, validando y guardando la versión anterior" : "fetching the catalogue, verifying SHA-256, validating, keeping the previous version",
        "rollback": es ? "validando la versión guardada y restaurándola" : "validating the kept version and restoring it",
        "remove": es ? "borrando los archivos y el recibo" : "deleting its files and receipt",
        "enable": es ? "revalidando el paquete" : "re-validating the package",
        "disable": es ? "actualizando el recibo" : "updating the receipt",
        "trust": es ? "calculando el hash del paquete" : "hashing the package"
    };
    var verbText = es
        ? { "install": "Instalando", "update": "Actualizando", "rollback": "Volviendo atrás", "remove": "Quitando", "enable": "Activando", "disable": "Desactivando", "trust": "Confiando en" }
        : { "install": "Installing", "update": "Updating", "rollback": "Rolling back", "remove": "Removing", "enable": "Enabling", "disable": "Disabling", "trust": "Trusting" };
    return (verbText[verb] || verb) + " " + name + "… " + (steps[verb] || "") + " · " + s + " s";
}

// Guidance per stable horneroctl error code (data.error). The CLI
// message is always shown too; this line says what to do next.
var GUIDANCE = {
    "catalogue-changed": ["The catalogue changed while you were reading it. Refresh it and review the new version.", "El catálogo cambió mientras lo leías. Actualizalo y revisá la versión nueva."],
    "catalogue-unavailable": ["The catalogue could not be fetched. Check the network and try Refresh catalogue.", "No se pudo descargar el catálogo. Revisá la red y probá Actualizar catálogo."],
    "hash-mismatch": ["The downloaded files do not match the catalogue hash, so nothing was changed.", "Los archivos descargados no coinciden con el hash del catálogo, así que no se cambió nada."],
    "validation-failed": ["The package failed the shell's contract check, so nothing changed.", "El paquete no pasó la verificación del shell, así que no cambió nada."],
    "already-installed": ["It is already installed. Remove it first to reinstall.", "Ya está instalada. Quitala primero para reinstalarla."],
    "not-installed": ["It is not installed any more. Reload the list.", "Ya no está instalada. Recargá la lista."],
    "locally-modified": ["Its files were changed on this machine. Trust the current files or remove and reinstall it.", "Sus archivos se cambiaron en esta máquina. Confiá en los actuales o quitala y reinstalala."],
    "not-catalogue-source": ["It was installed from another source, so the catalogue will not replace it.", "Se instaló desde otra fuente, así que el catálogo no la reemplaza."],
    "nothing-to-roll-back": ["There is no kept previous version to go back to.", "No hay una versión anterior guardada para volver."],
    "trust-required": ["Review its source, then use Trust… before enabling it.", "Revisá su código y usá Confiar… antes de activarla."],
    "not-in-catalogue": ["It is not in the official catalogue (any more).", "No está (o ya no está) en el catálogo oficial."],
    "unsafe-path": ["A symbolic link was found where Hornero keeps extensions; nothing was touched.", "Hay un enlace simbólico donde Hornero guarda extensiones; no se tocó nada."],
    "receipt-invalid": ["Its install receipt is damaged; nothing was touched.", "Su recibo de instalación está dañado; no se tocó nada."],
    "payload-missing": ["Its files are missing. Remove it and install it again.", "Faltan sus archivos. Quitala e instalala de nuevo."],
    "io-failed": ["A file could not be written. Check free space and permissions.", "No se pudo escribir un archivo. Revisá el espacio libre y los permisos."]
};

function guidance(code, es) {
    var g = GUIDANCE[String(code || "")];
    return g ? g[es ? 1 : 0] : "";
}

// Parse a horneroctl --json stdout. Never throws: an unparsable or empty
// output becomes a failure the pane can show.
function parseEnvelope(text, exitCode) {
    var env = null;
    try {
        env = JSON.parse(String(text || "").trim());
    } catch (e) {
        env = null;
    }
    if (!env || typeof env !== "object")
        return { ok: false, message: "horneroctl gave no JSON (exit " + exitCode + ").", code: "no-output", data: {} };
    var data = env.data && typeof env.data === "object" ? env.data : {};
    return {
        ok: env.ok === true && exitCode === 0,
        message: String(env.message || ""),
        code: env.ok === true ? "" : String(data.error || env.code || "failed"),
        data: data
    };
}

// Local install state of a catalogue row, from the catalogue's own view
// (installed_version / update_available) cross-checked with the
// installed list the shell discovered.
function rowState(catalogueEntry, installed) {
    var e = catalogueEntry || {};
    if (e.state !== "installed" && !installed)
        return "available";
    if (e.update_available === true)
        return "update";
    return "installed";
}

function updateText(catalogueEntry, es) {
    var e = catalogueEntry || {};
    if (e.update_available !== true)
        return "";
    var from = e.installed_version || "?";
    if (from === e.version)
        return es ? "Hay una revisión nueva de " + e.version + " en el catálogo" : "A new build of " + e.version + " is in the catalogue";
    return es ? "Actualización disponible: " + from + " → " + e.version : "Update available: " + from + " → " + e.version;
}

// Who vouches for the code, in words, from horneroctl's signer field and
// the trust state.
function signerText(entry, es) {
    var e = entry || {};
    var signer = String(e.signer || "");
    var trust = String(e.trust || "");
    if (signer.indexOf("official catalogue") >= 0 || (trust === "official" && !signer))
        return es ? "Firmado por: HorneroOS/plugins (catálogo oficial revisado, commit fijado y SHA-256)" : "Signed by: HorneroOS/plugins (reviewed official catalogue, pinned commit and SHA-256)";
    if (signer.indexOf("author key") === 0)
        return (es ? "Firmado por: clave del autor " : "Signed by: author key ") + signer.slice("author key".length).trim() + (es ? " (firma verificada)" : " (signature verified)");
    if (signer.indexOf("local trust") >= 0)
        return es ? "Confianza: la registraste vos para estos archivos exactos" : "Trust: recorded by you for these exact files";
    if (trust === "bad-signature")
        return es ? "Firma inválida: los archivos no coinciden con la firma" : "Bad signature: the files do not match their signature";
    return es ? "Nadie firmó este código" : "Nobody vouches for this code";
}

// Plain-language permission lines. Catalogue entries carry curated
// bilingual lines (HorneroOS/plugins catalog-permissions.json); installed
// entries without them get lines derived from the declarations.
function permissionLines(entry, es) {
    var e = entry || {};
    var lang = es ? "es" : "en";
    if (asArray(e.permissions).length > 0) {
        return asArray(e.permissions).filter(function (p) {
            return p && typeof p === "object" && typeof p[lang] === "string";
        }).map(function (p) {
            return { kind: String(p.kind || ""), value: String(p.value || ""), text: p[lang] };
        });
    }
    var caps = e.capabilities && typeof e.capabilities === "object" ? e.capabilities : {};
    var out = [];
    asArray(caps.processCommands).forEach(function (c) {
        out.push({ kind: "program", value: c, text: es ? "Puede ejecutar " + c + " como tu usuario." : "May run " + c + " as your user." });
    });
    asArray(caps.networkHosts).forEach(function (h) {
        out.push({ kind: "network", value: h, text: es ? "Puede conectarse a " + h + "." : "May contact " + h + "." });
    });
    asArray(caps.providers).forEach(function (d) {
        out.push({ kind: "data", value: d, text: es ? "Lee los datos compartidos \"" + d + "\" (solo lectura)." : "Reads the shared \"" + d + "\" data (read-only)." });
    });
    asArray(caps.actions).forEach(function (a) {
        var name = typeof a === "string" ? a : (a && a.id) || String(a);
        out.push({ kind: "action", value: name, text: es ? "Puede pedir la acción de sistema " + name + " (el intermediario la revisa)." : "May request the system action " + name + " (the broker checks it)." });
    });
    var keys = caps.settings && typeof caps.settings === "object" ? Object.keys(caps.settings).sort() : [];
    if (keys.length)
        out.push({ kind: "settings", value: keys.join(", "), text: es ? "Guarda solo su propia configuración (" + keys.join(", ") + ")." : "Stores only its own settings (" + keys.join(", ") + ")." });
    return out;
}

function hasProgramsOrNetwork(entry) {
    return permissionLines(entry, false).some(function (l) {
        return l.kind === "program" || l.kind === "network";
    });
}

// Measured cost of one extension. What the shell can honestly measure:
// the load time of its entrypoint (Plugins service) and the PluginKit
// cost of the shared data domains it declares (Providers.cost: mean JS
// handling time per sample, sampling period, subscriber count). Per
// extension CPU and memory are NOT measurable: every extension runs in
// the one shell process, so those are reported as not measured, never
// estimated. corePercent is the share of one core the domain sampling
// costs, split evenly across the extensions that lease it.
function costSummary(entry, telemetry) {
    var e = entry || {};
    var t = telemetry && typeof telemetry === "object" ? telemetry : {};
    var caps = e.capabilities && typeof e.capabilities === "object" ? e.capabilities : {};
    var domains = asArray(caps.providers);
    var providers = domains.map(function (d) {
        var c = t[d] || {};
        var interval = typeof c.intervalMs === "number" ? c.intervalMs : -1;
        var mean = typeof c.meanMs === "number" ? c.meanMs : 0;
        var leases = typeof c.leases === "number" && c.leases > 0 ? c.leases : 1;
        var samples = typeof c.samples === "number" ? c.samples : 0;
        var measured = interval > 0 && samples > 0;
        return {
            domain: d,
            intervalMs: interval,
            meanMs: mean,
            leases: leases,
            samples: samples,
            measured: measured,
            corePercent: measured ? (mean / interval) * 100 / leases : null
        };
    });
    var total = 0;
    var any = false;
    providers.forEach(function (p) {
        if (p.corePercent !== null) {
            total += p.corePercent;
            any = true;
        }
    });
    return {
        loadMs: typeof e.loadMs === "number" && e.loadMs >= 0 ? e.loadMs : null,
        providers: providers,
        corePercent: any ? total : null,
        memory: null
    };
}

function formatPercent(value) {
    if (value === null || value === undefined)
        return "";
    if (value < 0.01)
        return "<0.01%";
    return (Math.round(value * 100) / 100) + "%";
}

function costText(entry, telemetry, es) {
    var c = costSummary(entry, telemetry);
    var parts = [];
    parts.push(c.loadMs !== null
        ? (es ? "Carga: " + c.loadMs + " ms" : "Load: " + c.loadMs + " ms")
        : (es ? "Carga: sin medir (no está cargada)" : "Load: not measured (not loaded)"));
    if (c.providers.length === 0)
        parts.push(es ? "Datos compartidos: ninguno" : "Shared data: none");
    else
        parts.push(c.providers.map(function (p) {
            if (!p.measured)
                return p.domain + (es ? ": por evento o sin muestras todavía" : ": event-driven or no samples yet");
            return p.domain + ": " + formatPercent(p.corePercent) + (es ? " de un núcleo" : " of a core") + " (" + Math.round(p.intervalMs / 100) / 10 + " s, " + p.meanMs + " ms" + (p.leases > 1 ? (es ? ", compartido entre " : ", shared by ") + p.leases : "") + ")";
        }).join(" · "));
    parts.push(es ? "CPU y memoria propias: no se miden por extensión (todas corren en el proceso del shell)" : "Own CPU and memory: not measured per extension (all run inside the shell process)");
    return parts.join("\n");
}

// Screenshots for a catalogue row: local files horneroctl hash-verified
// and cached (screenshot_files), or packaged previews of an installed
// copy. Never a remote URL: the pane does not fetch images.
function screenshotSources(catalogueEntry, pluginsDir, installed) {
    var e = catalogueEntry || {};
    var out = [];
    asArray(e.screenshot_files).forEach(function (s) {
        if (s && typeof s.file === "string" && s.file.charAt(0) === "/" && s.file.indexOf("..") < 0)
            out.push({ source: "file://" + s.file, alt: String(s.alt || e.name || e.id || "") });
    });
    if (out.length === 0 && installed && e.marketplace && isList(e.marketplace.screenshots)) {
        asArray(e.marketplace.screenshots).forEach(function (s) {
            if (s && typeof s.path === "string" && s.path.indexOf("..") < 0 && s.path.charAt(0) !== "/")
                out.push({ source: "file://" + pluginsDir + "/" + e.id + "/" + s.path, alt: String(s.alt || e.name || e.id || "") });
        });
    }
    return out;
}

function changelog(entry, limit) {
    var m = entry && entry.marketplace && typeof entry.marketplace === "object" ? entry.marketplace : null;
    if (!m || !isList(m.changelog))
        return [];
    return asArray(m.changelog).filter(function (c) {
        return c && typeof c.version === "string" && typeof c.notes === "string";
    }).slice(0, limit > 0 ? limit : 20);
}

// The consent text shown by the first step of a guarded verb. Install
// and update copy code; enable runs it. Each states exactly that.
function consentText(verb, entry, es) {
    var name = (entry && (entry.name || entry.id)) || "";
    switch (verb) {
    case "install":
        return es
            ? "Instalar " + name + " copia archivos verificados por hash y no los ejecuta. Va a quedar desactivada hasta que la actives; al activarla corre como tu usuario, sin sandbox."
            : "Installing " + name + " copies hash-verified files and does not run them. It stays off until you enable it; once enabled it runs as your user, with no sandbox.";
    case "update":
        return es
            ? "Actualizar reemplaza los archivos de " + name + " por la versión del catálogo y guarda la actual para volver atrás. Si estaba activada, sigue activada."
            : "Updating replaces " + name + "'s files with the catalogue version and keeps the current one so you can roll back. If it was on, it stays on.";
    case "rollback":
        return es
            ? "Volver atrás restaura la versión guardada de " + name + " y descarta la actual."
            : "Rolling back restores the kept version of " + name + " and discards the current one.";
    case "remove":
        return es
            ? "Quitar borra los archivos, el recibo y la copia para volver atrás de " + name + ". Su configuración queda guardada por si la reinstalás."
            : "Removing deletes " + name + "'s files, receipt and rollback copy. Its settings are kept in case you reinstall it.";
    case "enable":
        return es
            ? "Activar ejecuta el código de " + name + " como tu usuario, sin sandbox. Activá solo extensiones cuyo código revisaste."
            : "Enabling runs " + name + "'s code as your user, with no sandbox. Only enable extensions whose source you have read.";
    case "trust":
        return es
            ? "Confiar registra el hash de estos archivos exactos de " + name + ". No la activa; si los archivos cambian, se te vuelve a preguntar."
            : "Trusting records the hash of " + name + "'s exact current files. It does not enable it; if the files change, you are asked again.";
    }
    return "";
}

// Short store lines in both languages (the shell has no translation
// catalogue yet; the store follows plugins.storeLanguage).
var UI = {
    "installed": ["Installed", "Instalada"],
    "available": ["Available", "Disponible"],
    "load": ["Load %1 ms", "Carga %1 ms"],
    "declares": ["What it declares it uses (not enforced):", "Lo que declara usar (no se hace cumplir):"],
    "declaresNothing": ["Declares no programs, network hosts or shared data.", "No declara programas, red ni datos compartidos."],
    "beforeInstall": ["Before you install %1", "Antes de instalar %1"],
    "checkDeclared": ["Check the programs and hosts it declares above: once enabled it can use them.", "Revisá arriba los programas y hosts que declara: cuando la actives podrá usarlos."],
    "installedOff": ["Installed and off — enable it in the list above", "Instalada y apagada: activala en la lista de arriba"]
};

function t(key, es, arg) {
    var pair = UI[key];
    var text = pair ? pair[es ? 1 : 0] : key;
    return arg === undefined ? text : text.replace("%1", String(arg));
}

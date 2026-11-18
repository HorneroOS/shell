.pragma library

// Javi's voice: the small lines the companion speaks, in English and
// Spanish, in two tones. Pure data and functions (no QML, no timers) so the
// whole catalogue runs under node in tests/test_javi_voice.py.
//
// Voice rules (docs/COMPANION.md "Voice and personality"): friendly,
// curious, technically competent, a little playful; short (one line, at most
// 72 characters), no exclamation marks, no emoji, no pet names, nothing that
// blames the user, no forced slang, and never the only carrier of
// information (a line decorates a state the UI already shows). Javi never
// claims to think or feel: lines describe what the shell observed or what
// the user can do.
//
// "warm" is the default voice (the hornero at his workbench); "plain" is the
// neutral wording for people who prefer fewer words of character. Every key
// exists in all four tables (language x tone); the tests enforce it.

var LANGS = ["en", "es"];
var TONES = ["warm", "plain"];
var LANGUAGE_CHOICES = ["auto", "en", "es"];
var LINE_MAX = 72;

var CATALOG = {
    en: {
        warm: {
            "tip.start": "Right-click me for skins, tips and settings.",
            "tip.shell": "Super+Space opens the launcher. Welcome has the tour.",
            "tip.personalize": "Make the shell yours: Welcome has the themes.",
            "tip.workspaces": "Workspaces keep the bench tidy. Welcome shows how.",
            "tip.tools": "Handy tools are one click away. See Welcome.",
            "tip.learn": "Curious what changed? Welcome has the notes.",
            "reaction.battery.low": "Battery is getting low.",
            "reaction.battery.critical": "Battery is critical. Plug in soon.",
            "reaction.build.done": "Build finished.",
            "reaction.build.failed": "The build failed.",
            "reaction.download.done": "Download finished.",
            "summon.greet": "Here I am.",
            "nest.resting": "Resting",
            "nest.working": "Working",
            "nest.building": "Building",
            "nest.sleeping": "Sleeping",
            "nest.summoned": "Summoned",
            "nest.hidden": "Hidden",
            "nest.accessible": "Javi's nest, %1",
            "nest.light.link": "Assistant link",
            "nest.light.run": "Assistant running",
            "nest.light.approval": "Waiting for you",
            "nest.light.radio": "Radio",
            "nest.light.mode": "Mode",
            "nest.art.placeholder": "Placeholder art, the final nest is still being drawn.",
            "radio.title": "Javi Radio",
            "radio.placeholder": "Ask Javi something quick",
            "radio.hint": "Quick questions only. Nothing runs without you.",
            "radio.busy": "Listening on the radio.",
            "radio.unavailable": "The assistant is not available right now.",
            "radio.handoff": "This needs your approval. Open the Workbench to continue.",
            "radio.disabled": "Javi Radio is switched off in settings.",
            "voice.quiet": "Quiet hours are on. I will keep it down."
        },
        plain: {
            "tip.start": "Right-click for skins, tips and settings.",
            "tip.shell": "Press Super+Space for the launcher. See Welcome.",
            "tip.personalize": "Themes are in Welcome under personalize.",
            "tip.workspaces": "Workspaces are explained in Welcome.",
            "tip.tools": "Tools are listed in Welcome.",
            "tip.learn": "Release notes are in Welcome.",
            "reaction.battery.low": "Battery low.",
            "reaction.battery.critical": "Battery critical. Plug in.",
            "reaction.build.done": "Build finished.",
            "reaction.build.failed": "Build failed.",
            "reaction.download.done": "Download finished.",
            "summon.greet": "Hello.",
            "nest.resting": "Resting",
            "nest.working": "Working",
            "nest.building": "Building",
            "nest.sleeping": "Sleeping",
            "nest.summoned": "Summoned",
            "nest.hidden": "Hidden",
            "nest.accessible": "Javi's nest, %1",
            "nest.light.link": "Assistant link",
            "nest.light.run": "Assistant running",
            "nest.light.approval": "Approval pending",
            "nest.light.radio": "Radio",
            "nest.light.mode": "Mode",
            "nest.art.placeholder": "Placeholder art. Final artwork is pending.",
            "radio.title": "Javi Radio",
            "radio.placeholder": "Ask a quick question",
            "radio.hint": "Quick questions only. Nothing runs without approval.",
            "radio.busy": "Waiting for the answer.",
            "radio.unavailable": "The assistant is unavailable.",
            "radio.handoff": "Approval needed. Open the Workbench to continue.",
            "radio.disabled": "Javi Radio is disabled in settings.",
            "voice.quiet": "Quiet hours are on."
        }
    },
    es: {
        warm: {
            "tip.start": "Clic derecho en mí para skins, consejos y ajustes.",
            "tip.shell": "Super+Espacio abre el lanzador. Bienvenida tiene el recorrido.",
            "tip.personalize": "Hacé tuyo el shell: Bienvenida tiene los temas.",
            "tip.workspaces": "Los espacios de trabajo ordenan el banco. Mirá Bienvenida.",
            "tip.tools": "Las herramientas están a un clic. Mirá Bienvenida.",
            "tip.learn": "¿Querés saber qué cambió? Bienvenida tiene las notas.",
            "reaction.battery.low": "La batería se está acabando.",
            "reaction.battery.critical": "Batería crítica. Conectá el cargador pronto.",
            "reaction.build.done": "Terminó la compilación.",
            "reaction.build.failed": "Falló la compilación.",
            "reaction.download.done": "Terminó la descarga.",
            "summon.greet": "Acá estoy.",
            "nest.resting": "Descansando",
            "nest.working": "Trabajando",
            "nest.building": "Construyendo",
            "nest.sleeping": "Durmiendo",
            "nest.summoned": "Llamado",
            "nest.hidden": "Oculto",
            "nest.accessible": "Nido de Javi, %1",
            "nest.light.link": "Enlace con el asistente",
            "nest.light.run": "Asistente en marcha",
            "nest.light.approval": "Esperándote",
            "nest.light.radio": "Radio",
            "nest.light.mode": "Modo",
            "nest.art.placeholder": "Arte provisorio, el nido final todavía se está dibujando.",
            "radio.title": "Radio de Javi",
            "radio.placeholder": "Preguntale algo rápido a Javi",
            "radio.hint": "Solo preguntas rápidas. Nada se ejecuta sin vos.",
            "radio.busy": "Escuchando por la radio.",
            "radio.unavailable": "El asistente no está disponible ahora.",
            "radio.handoff": "Esto necesita tu aprobación. Abrí el Workbench para seguir.",
            "radio.disabled": "La Radio de Javi está apagada en los ajustes.",
            "voice.quiet": "Hay horas de silencio. Voy bajito."
        },
        plain: {
            "tip.start": "Clic derecho para skins, consejos y ajustes.",
            "tip.shell": "Super+Espacio abre el lanzador. Ver Bienvenida.",
            "tip.personalize": "Los temas están en Bienvenida, en personalizar.",
            "tip.workspaces": "Los espacios de trabajo se explican en Bienvenida.",
            "tip.tools": "Las herramientas están en Bienvenida.",
            "tip.learn": "Las notas de versión están en Bienvenida.",
            "reaction.battery.low": "Batería baja.",
            "reaction.battery.critical": "Batería crítica. Conectá el cargador.",
            "reaction.build.done": "Compilación terminada.",
            "reaction.build.failed": "Compilación fallida.",
            "reaction.download.done": "Descarga terminada.",
            "summon.greet": "Hola.",
            "nest.resting": "Descansando",
            "nest.working": "Trabajando",
            "nest.building": "Construyendo",
            "nest.sleeping": "Durmiendo",
            "nest.summoned": "Llamado",
            "nest.hidden": "Oculto",
            "nest.accessible": "Nido de Javi, %1",
            "nest.light.link": "Enlace con el asistente",
            "nest.light.run": "Asistente en marcha",
            "nest.light.approval": "Aprobación pendiente",
            "nest.light.radio": "Radio",
            "nest.light.mode": "Modo",
            "nest.art.placeholder": "Arte provisorio. El arte final está pendiente.",
            "radio.title": "Radio de Javi",
            "radio.placeholder": "Hacé una pregunta rápida",
            "radio.hint": "Solo preguntas rápidas. Nada se ejecuta sin aprobación.",
            "radio.busy": "Esperando la respuesta.",
            "radio.unavailable": "El asistente no está disponible.",
            "radio.handoff": "Se necesita aprobación. Abrí el Workbench para seguir.",
            "radio.disabled": "La Radio de Javi está desactivada en los ajustes.",
            "voice.quiet": "Hay horas de silencio."
        }
    }
};

function defaults() {
    return { language: "auto", tone: "warm" };
}

function sanitize(raw) {
    var d = defaults();
    var o = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    if (LANGUAGE_CHOICES.indexOf(o.language) >= 0)
        d.language = o.language;
    if (TONES.indexOf(o.tone) >= 0)
        d.tone = o.tone;
    return d;
}

// "es_AR" / "es-AR" / "es" -> "es"; anything unsupported -> "en".
function languageOf(localeName) {
    var l = String(localeName === undefined || localeName === null ? "" : localeName).toLowerCase().split(/[_.@-]/)[0];
    return LANGS.indexOf(l) >= 0 ? l : "en";
}

// The effective language: the explicit setting, or the shell locale.
function resolveLanguage(settings, localeName) {
    var s = sanitize(settings);
    return s.language === "auto" ? languageOf(localeName) : s.language;
}

// key -> line. Unknown keys return the key itself so a typo is visible
// rather than silent; %1..%9 are replaced from `args`.
function line(settings, localeName, key, args) {
    var s = sanitize(settings);
    var lang = resolveLanguage(s, localeName);
    var text = CATALOG[lang][s.tone][key];
    if (text === undefined)
        text = CATALOG.en[s.tone][key];
    if (text === undefined)
        return String(key);
    if (Array.isArray(args)) {
        for (var i = 0; i < args.length; i++)
            text = text.split("%" + (i + 1)).join(String(args[i]));
    }
    return text;
}

function keys() {
    return Object.keys(CATALOG.en.warm);
}

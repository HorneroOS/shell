.pragma library

// Workbench microcopy, English and Spanish (neutral, friendly,
// concise, no slang). One table, keyed; the UI asks for a key and the
// language is resolved from the system locale (override-able by the
// caller). tests/test_assistant_copy.py keeps both languages in sync.

var STRINGS = {
    "status.disabled": { en: "Assistant off", es: "Asistente apagado" },
    "status.disconnected": { en: "Disconnected", es: "Sin conexión" },
    "status.reconnecting": { en: "Reconnecting…", es: "Reconectando…" },
    "status.degraded": { en: "Gateway incompatible", es: "Gateway incompatible" },
    "status.degraded-isolation": { en: "Connected · not sandboxed", es: "Conectado · sin aislamiento" },
    "status.connected": { en: "Connected", es: "Conectado" },
    "status.running": { en: "Working", es: "Trabajando" },
    "status.awaiting-approval": { en: "Needs your approval", es: "Necesita tu aprobación" },
    "status.awaiting-clarification": { en: "Needs an answer", es: "Necesita una respuesta" },
    "status.blocked": { en: "Blocked by mode", es: "Bloqueado por el modo" },
    "status.failed": { en: "Failed", es: "Falló" },
    "status.unknown": { en: "Checking…", es: "Comprobando…" },

    "phase.starting": { en: "Starting", es: "Iniciando" },
    "phase.streaming": { en: "Streaming", es: "Respondiendo" },
    "phase.cancelling": { en: "Stopping", es: "Deteniendo" },
    "phase.completed": { en: "Done", es: "Listo" },
    "phase.failed": { en: "Failed", es: "Falló" },
    "phase.cancelled": { en: "Stopped", es: "Detenido" },
    "phase.disconnected": { en: "Connection lost", es: "Se perdió la conexión" },
    "phase.blocked": { en: "Blocked", es: "Bloqueado" },
    "phase.awaiting-approval": { en: "Awaiting approval", es: "Esperando aprobaci\u00f3n" },
    "phase.awaiting-clarification": { en: "Awaiting answer", es: "Esperando respuesta" },
    "phase.idle": { en: "Idle", es: "En reposo" },

    "mode.ask": { en: "Ask", es: "Consulta" },
    "mode.agent": { en: "Agent", es: "Agente" },
    "mode.chat": { en: "Chat", es: "Charla" },
    "mode.ask.hint": { en: "Read-only. A run that tries a tool is stopped and denied.", es: "Solo lectura. Una ejecución que intenta usar una herramienta se detiene y se deniega." },
    "mode.agent.hint": { en: "Can act, but asks you first.", es: "Puede actuar, pero te pregunta antes." },
    "mode.chat.hint": { en: "Conversation only. No machine access.", es: "Solo conversación. Sin acceso al equipo." },

    "approval.title": { en: "Approval needed", es: "Se necesita tu aprobación" },
    "approval.what": { en: "What", es: "Qué" },
    "approval.run": { en: "Run", es: "Ejecución" },
    "approval.mode": { en: "Mode", es: "Modo" },
    "approval.scope": { en: "Scope", es: "Alcance" },
    "approval.scope.once": { en: "Only this request, once.", es: "Solo esta solicitud, una vez." },
    "approval.workspace": { en: "Workspace", es: "Espacio de trabajo" },
    "approval.isolation": { en: "Isolation", es: "Aislamiento" },
    "approval.isolation.sandboxed": { en: "Sandboxed (bubblewrap), as reported", es: "Aislado (bubblewrap), según el informe" },
    "approval.isolation.unsandboxed": { en: "Not confirmed sandboxed (systemd only)", es: "Aislamiento no confirmado (solo systemd)" },
    "approval.isolation.unknown": { en: "Unknown", es: "Desconocido" },
    "approval.risk": { en: "Risk", es: "Riesgo" },
    "approval.risk.text": { en: "Judge it from the exact text above. Javi cannot rate it for you.", es: "Júzgalo por el texto exacto de arriba. Javi no puede calificarlo por ti." },
    "approval.stream.closed": { en: "The live stream closed; the run is still waiting for you.", es: "La conexión en vivo se cerró; la ejecución sigue esperando." },
    "approval.allow": { en: "Allow once", es: "Permitir una vez" },
    "approval.truncated": { en: "The request is too long to show in full. It can only be denied.", es: "La solicitud es demasiado larga para mostrarla completa. Solo se puede denegar." },
    "approval.hidden-chars": { en: "Hidden characters are shown as marked codes.", es: "Los caracteres ocultos se muestran como códigos marcados." },
    "approval.unbound": { en: "This request has no id to bind to. It can only be denied.", es: "Esta solicitud no tiene un id al que vincularse. Solo se puede denegar." },
    "approval.mode.unknown": { en: "Unknown (treated as read-only)", es: "Desconocido (tratado como solo lectura)" },
    "approval.request": { en: "Request", es: "Solicitud" },
    "approval.deny": { en: "Deny", es: "Denegar" },
    "approval.deciding": { en: "Sending your decision…", es: "Enviando tu decisión…" },

    "clarify.title": { en: "Javi has a question", es: "Javi tiene una pregunta" },
    "clarify.send": { en: "Send answer", es: "Enviar respuesta" },

    "action.stop": { en: "Stop", es: "Detener" },
    "action.retry": { en: "Retry", es: "Reintentar" },
    "action.copy": { en: "Copy", es: "Copiar" },
    "action.clear": { en: "Clear", es: "Borrar" },
    "action.open-workbench": { en: "Open in Workbench", es: "Abrir en el Workbench" },
    "action.continue-workbench": { en: "Continue in Workbench", es: "Continuar en el Workbench" },
    "action.reconnect": { en: "Reconnect", es: "Reconectar" },

    "quick.hint": { en: "Quick answer, read-only. Tool attempts are stopped and denied.", es: "Respuesta rápida, solo lectura. Los intentos de usar herramientas se detienen y se deniegan." },
    "quick.needs-workbench": { en: "This needs approvals or tools. Continue in the Workbench to decide.", es: "Esto requiere aprobaciones o herramientas. Continúa en el Workbench para decidir." },
    "quick.blocked": { en: "Quick questions never act. Nothing was run.", es: "Las preguntas rápidas nunca actúan. No se ejecutó nada." },

    "mic.recording": { en: "Microphone on", es: "Micrófono encendido" },
    "mic.idle": { en: "Microphone off", es: "Micrófono apagado" },
    "mic.cancel": { en: "Discard recording", es: "Descartar grabación" },
    "mic.send": { en: "Stop and send", es: "Detener y enviar" },
    "mic.auto-stopped": { en: "Recording stopped after 2 minutes.", es: "La grabación se detuvo a los 2 minutos." },

    "timeline.title": { en: "Activity", es: "Actividad" },
    "timeline.empty": { en: "No activity yet.", es: "Todavía no hay actividad." },
    "timeline.note": { en: "Activity the gateway reports. Providers do not expose raw reasoning.", es: "Actividad que informa el gateway. Los proveedores no exponen el razonamiento completo." },
    "artifacts.title": { en: "Artifacts", es: "Artefactos" },
    "artifacts.empty": { en: "Nothing attached in this session.", es: "No hay adjuntos en esta sesión." },
    "artifacts.note": { en: "Files you attached. The backend does not list files the agent creates; open the workspace to see them.", es: "Archivos que adjuntaste. El backend no lista lo que crea el agente; abre el espacio de trabajo para verlos." },
    "history.title": { en: "History", es: "Historial" },
    "history.sessions": { en: "Sessions", es: "Sesiones" },
    "history.model": { en: "Model and mode", es: "Modelo y modo" },
    "history.new": { en: "New session", es: "Sesión nueva" },
    "tab.activity": { en: "Activity", es: "Actividad" },
    "tab.approvals": { en: "Approvals", es: "Aprobaciones" },
    "tab.artifacts": { en: "Artifacts", es: "Artefactos" },
    "tab.history": { en: "Session", es: "Sesi\u00f3n" },
    "handoff.title": { en: "Hand-off", es: "Traspaso" },
    "handoff.from.radio": { en: "From Javi Radio", es: "Desde Javi Radio" },
    "handoff.from.launcher": { en: "From the launcher", es: "Desde el lanzador" },
    "handoff.question": { en: "Question", es: "Pregunta" },
    "handoff.kind.approval": { en: "It asked for approval to:", es: "Pidió aprobación para:" },
    "handoff.kind.clarify": { en: "It asked you a question:", es: "Te hizo una pregunta:" },
    "handoff.kind.blocked": { en: "Ask mode stopped a tool:", es: "El modo Preguntar detuvo una herramienta:" },
    "handoff.nothing-ran": { en: "Quick questions are read-only: this was denied and nothing ran.", es: "Las preguntas rápidas son de solo lectura: se rechazó y no se ejecutó nada." },
    "handoff.how": { en: "To act, run it as Agent and decide each request on its card.", es: "Para actuar, ejecútala como Agente y decide cada solicitud en su tarjeta." },
    "handoff.truncated": { en: "The request is too long to show whole.", es: "La solicitud es demasiado larga para mostrarla entera." },
    "handoff.flagged": { en: "Hidden characters are shown as ⟦U+…⟧.", es: "Los caracteres ocultos se muestran como ⟦U+…⟧." },
    "handoff.run-agent": { en: "Run as Agent", es: "Ejecutar como Agente" },
    "handoff.edit": { en: "Edit first", es: "Editar antes" },
    "handoff.dismiss": { en: "Dismiss", es: "Descartar" },
    "approvals.none": { en: "No pending approvals.", es: "No hay aprobaciones pendientes." },
    "approvals.decided": { en: "Decided this session", es: "Decididas en esta sesión" },
    "approvals.allowed": { en: "allowed once", es: "permitida una vez" },
    "approvals.denied": { en: "denied", es: "denegada" },

    "error.no-answer": { en: "The assistant did not answer. Check the connection and retry.", es: "El asistente no respondió. Revisa la conexión y reintenta." },
    "error.interrupted": { en: "The connection dropped mid-answer. The text above is partial.", es: "Se cortó la conexión a mitad de la respuesta. El texto de arriba está incompleto." },
    "error.disabled": { en: "The assistant is off. Turn it on in Control Center > Javi.", es: "El asistente está apagado. Actívalo en Centro de control > Javi." },
    "thinking": { en: "Javi is thinking", es: "Javi est\u00e1 pensando" },
    "chip.updates": { en: "What updates are pending?", es: "\u00bfQu\u00e9 actualizaciones hay pendientes?" },
    "chip.slow": { en: "Why is my machine slow?", es: "\u00bfPor qu\u00e9 va lento mi equipo?" },
    "chip.themes": { en: "Show me the GTK themes", es: "Mu\u00e9strame los temas GTK" },
    "chip.capabilities": { en: "What can you do?", es: "\u00bfQu\u00e9 puedes hacer?" },
    "workbench.expand": { en: "Expand Workbench", es: "Expandir Workbench" },
    "workbench.collapse": { en: "Collapse Workbench", es: "Contraer Workbench" }
};

function lang(localeName) {
    var n = (localeName || "").toString().toLowerCase();
    return n.indexOf("es") === 0 ? "es" : "en";
}

function t(key, language) {
    var e = STRINGS[key];
    if (!e)
        return key;
    return e[language === "es" ? "es" : "en"] || e.en;
}

function keys() {
    return Object.keys(STRINGS);
}

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
    "phase.idle": { en: "Idle", es: "En reposo" },

    "mode.ask": { en: "Ask", es: "Consulta" },
    "mode.agent": { en: "Agent", es: "Agente" },
    "mode.chat": { en: "Chat", es: "Charla" },
    "mode.ask.hint": { en: "Read-only. Never runs tools.", es: "Solo lectura. Nunca ejecuta herramientas." },
    "mode.agent.hint": { en: "Can act, but asks you first.", es: "Puede actuar, pero te pregunta antes." },
    "mode.chat.hint": { en: "Conversation only. No machine access.", es: "Solo conversación. Sin acceso al equipo." },

    "approval.title": { en: "Approval needed", es: "Se necesita tu aprobación" },
    "approval.what": { en: "What", es: "Qué" },
    "approval.run": { en: "Run", es: "Ejecución" },
    "approval.mode": { en: "Mode", es: "Modo" },
    "approval.scope": { en: "Scope", es: "Alcance" },
    "approval.scope.once": { en: "This one action, once. Nothing else.", es: "Solo esta acción, una vez. Nada más." },
    "approval.workspace": { en: "Workspace", es: "Espacio de trabajo" },
    "approval.isolation": { en: "Isolation", es: "Aislamiento" },
    "approval.isolation.sandboxed": { en: "Sandboxed (bubblewrap)", es: "Aislado (bubblewrap)" },
    "approval.isolation.unsandboxed": { en: "Not sandboxed (systemd only)", es: "Sin aislamiento (solo systemd)" },
    "approval.isolation.unknown": { en: "Unknown", es: "Desconocido" },
    "approval.risk": { en: "Risk", es: "Riesgo" },
    "approval.risk.text": { en: "Judge it from the exact text above. Javi cannot rate it for you.", es: "Júzgalo por el texto exacto de arriba. Javi no puede calificarlo por ti." },
    "approval.stream.closed": { en: "The live stream closed; the run is still waiting for you.", es: "La conexión en vivo se cerró; la ejecución sigue esperando." },
    "approval.allow": { en: "Allow once", es: "Permitir una vez" },
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

    "quick.hint": { en: "Quick answer: read-only, nothing is changed.", es: "Respuesta rápida: solo lectura, no se cambia nada." },
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
    "history.new": { en: "New session", es: "Sesión nueva" },
    "tab.activity": { en: "Activity", es: "Actividad" },
    "tab.approvals": { en: "Approvals", es: "Aprobaciones" },
    "tab.artifacts": { en: "Artifacts", es: "Artefactos" },
    "tab.history": { en: "History", es: "Historial" },
    "approvals.none": { en: "No pending approvals.", es: "No hay aprobaciones pendientes." },
    "approvals.decided": { en: "Decided this session", es: "Decididas en esta sesión" },
    "approvals.allowed": { en: "allowed once", es: "permitida una vez" },
    "approvals.denied": { en: "denied", es: "denegada" },

    "error.no-answer": { en: "The assistant did not answer. Check the connection and retry.", es: "El asistente no respondió. Revisa la conexión y reintenta." },
    "error.interrupted": { en: "The connection dropped mid-answer. The text above is partial.", es: "Se cortó la conexión a mitad de la respuesta. El texto de arriba está incompleto." },
    "error.disabled": { en: "The assistant is off. Turn it on in Control Center > Javi.", es: "El asistente está apagado. Actívalo en Centro de control > Javi." },
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

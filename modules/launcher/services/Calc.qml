pragma Singleton

import "calcparser.js" as CalcParser
import Quickshell
import QtQuick

// Calculator provider logic (shell#250 slice 1): evaluates the
// query with the shell's own safe arithmetic parser
// (calcparser.js). No eval, no Process, no external calculator
// is involved in evaluation; Qalculator/libqalculate is no
// longer consulted for launcher results.
Singleton {
    id: root

    // { ok, value, text } on success, { ok: false, error } else.
    function evaluate(expr: string): var {
        return CalcParser.evaluate(expr);
    }

    function format(value: real): string {
        return CalcParser.format(value);
    }

    function looksLikeExpression(text: string): bool {
        return CalcParser.looksLikeExpression(text);
    }
}

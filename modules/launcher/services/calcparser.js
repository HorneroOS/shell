.pragma library

// Safe arithmetic parser for the launcher calculator provider
// (shell#250 slice 1). Semantics mirror the hornero-calculator
// plugin: tokenizer plus recursive descent for + - * / %,
// parentheses, decimals and unary +/-. No dynamic code execution
// (no eval, no Function, no process) is used anywhere here.
// Division or modulo by zero, malformed input and non-finite
// results are errors, never partial values.

function tokenize(input) {
    var tokens = [];
    var i = 0;
    while (i < input.length) {
        var c = input[i];
        if (c === " " || c === "\t") {
            i++;
            continue;
        }
        if ((c >= "0" && c <= "9") || c === ".") {
            var j = i;
            var dots = 0;
            while (j < input.length && ((input[j] >= "0" && input[j] <= "9") || input[j] === ".")) {
                if (input[j] === ".")
                    dots++;
                j++;
            }
            if (dots > 1)
                return null;
            var value = parseFloat(input.substring(i, j));
            if (!isFinite(value))
                return null;
            tokens.push({
                "type": "number",
                "value": value
            });
            i = j;
            continue;
        }
        if ("+-*/%()".indexOf(c) >= 0) {
            tokens.push({
                "type": c
            });
            i++;
            continue;
        }
        return null;
    }
    return tokens;
}

// Returns { ok: true, value: number, text: string } or
// { ok: false, error: string }. Never throws on bad input.
function evaluate(input) {
    if (typeof input !== "string" || input.trim().length === 0)
        return {
            "ok": false,
            "error": "empty"
        };
    var tokens = tokenize(input);
    if (!tokens || tokens.length === 0)
        return {
            "ok": false,
            "error": "malformed"
        };
    var pos = 0;
    function peek() {
        return pos < tokens.length ? tokens[pos] : null;
    }
    function parseExpr() {
        var v = parseTerm();
        if (v === null)
            return null;
        while (peek() && (peek().type === "+" || peek().type === "-")) {
            var op = tokens[pos++].type;
            var r = parseTerm();
            if (r === null)
                return null;
            v = (op === "+") ? v + r : v - r;
        }
        return v;
    }
    function parseTerm() {
        var v = parseFactor();
        if (v === null)
            return null;
        while (peek() && (peek().type === "*" || peek().type === "/" || peek().type === "%")) {
            var op = tokens[pos++].type;
            var r = parseFactor();
            if (r === null)
                return null;
            if ((op === "/" || op === "%") && r === 0)
                return null;
            if (op === "*")
                v = v * r;
            else if (op === "/")
                v = v / r;
            else
                v = v % r;
        }
        return v;
    }
    function parseFactor() {
        var t = peek();
        if (!t)
            return null;
        if (t.type === "-") {
            pos++;
            var n = parseFactor();
            return n === null ? null : -n;
        }
        if (t.type === "+") {
            pos++;
            return parseFactor();
        }
        if (t.type === "(") {
            pos++;
            var inner = parseExpr();
            if (inner === null || !peek() || peek().type !== ")")
                return null;
            pos++;
            return inner;
        }
        if (t.type === "number") {
            pos++;
            return t.value;
        }
        return null;
    }
    var resultValue = parseExpr();
    if (resultValue === null || pos !== tokens.length || !isFinite(resultValue))
        return {
            "ok": false,
            "error": "malformed"
        };
    return {
        "ok": true,
        "value": resultValue,
        "text": format(resultValue)
    };
}

// Display formatting mirrors the plugin: round to 10 decimal
// places so 0.1 + 0.2 reads "0.3", not the raw double.
function format(value) {
    var rounded = Math.round(value * 10000000000) / 10000000000;
    return String(rounded);
}

// True only when the whole text is a valid expression that also
// contains an operator or parenthesis, so a bare number or word
// is never mistaken for a calculation. The launcher does not
// route bare expressions today (see docs/LAUNCHER.md): this is
// the gate a future bare-calc section must pass first.
function looksLikeExpression(input) {
    if (typeof input !== "string")
        return false;
    if (!/[+\-*\/%()]/.test(input))
        return false;
    return evaluate(input).ok;
}

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

// Offline unit conversion tables (shell#737).
// Linear units store { cat, factor, label } relative to the category base unit.
// Data units use binary (1024-based) multipliers standard in Linux shells.
var LINEAR_UNITS = {
    // Length (base: m)
    "mm": { "cat": "length", "factor": 0.001, "label": "mm" },
    "cm": { "cat": "length", "factor": 0.01, "label": "cm" },
    "m": { "cat": "length", "factor": 1, "label": "m" },
    "km": { "cat": "length", "factor": 1000, "label": "km" },
    "in": { "cat": "length", "factor": 0.0254, "label": "in" },
    "inch": { "cat": "length", "factor": 0.0254, "label": "in" },
    "inches": { "cat": "length", "factor": 0.0254, "label": "in" },
    "ft": { "cat": "length", "factor": 0.3048, "label": "ft" },
    "foot": { "cat": "length", "factor": 0.3048, "label": "ft" },
    "feet": { "cat": "length", "factor": 0.3048, "label": "ft" },
    "yd": { "cat": "length", "factor": 0.9144, "label": "yd" },
    "yard": { "cat": "length", "factor": 0.9144, "label": "yd" },
    "yards": { "cat": "length", "factor": 0.9144, "label": "yd" },
    "mi": { "cat": "length", "factor": 1609.344, "label": "mi" },
    "mile": { "cat": "length", "factor": 1609.344, "label": "mi" },
    "miles": { "cat": "length", "factor": 1609.344, "label": "mi" },
    // Mass (base: g)
    "mg": { "cat": "mass", "factor": 0.001, "label": "mg" },
    "g": { "cat": "mass", "factor": 1, "label": "g" },
    "kg": { "cat": "mass", "factor": 1000, "label": "kg" },
    "oz": { "cat": "mass", "factor": 28.349523125, "label": "oz" },
    "lb": { "cat": "mass", "factor": 453.59237, "label": "lb" },
    "lbs": { "cat": "mass", "factor": 453.59237, "label": "lb" },
    // Data (base: B, binary 1024-based)
    "b": { "cat": "data", "factor": 1, "label": "B" },
    "kb": { "cat": "data", "factor": 1024, "label": "KB" },
    "kib": { "cat": "data", "factor": 1024, "label": "KiB" },
    "mb": { "cat": "data", "factor": 1024 * 1024, "label": "MB" },
    "mib": { "cat": "data", "factor": 1024 * 1024, "label": "MiB" },
    "gb": { "cat": "data", "factor": 1024 * 1024 * 1024, "label": "GB" },
    "gib": { "cat": "data", "factor": 1024 * 1024 * 1024, "label": "GiB" },
    "tb": { "cat": "data", "factor": 1024 * 1024 * 1024 * 1024, "label": "TB" },
    "tib": { "cat": "data", "factor": 1024 * 1024 * 1024 * 1024, "label": "TiB" },
    // Time (base: s)
    "ms": { "cat": "time", "factor": 0.001, "label": "ms" },
    "s": { "cat": "time", "factor": 1, "label": "s" },
    "sec": { "cat": "time", "factor": 1, "label": "s" },
    "secs": { "cat": "time", "factor": 1, "label": "s" },
    "min": { "cat": "time", "factor": 60, "label": "min" },
    "mins": { "cat": "time", "factor": 60, "label": "min" },
    "h": { "cat": "time", "factor": 3600, "label": "h" },
    "hr": { "cat": "time", "factor": 3600, "label": "h" },
    "hrs": { "cat": "time", "factor": 3600, "label": "h" },
    "hour": { "cat": "time", "factor": 3600, "label": "h" },
    "hours": { "cat": "time", "factor": 3600, "label": "h" },
    "d": { "cat": "time", "factor": 86400, "label": "d" },
    "day": { "cat": "time", "factor": 86400, "label": "d" },
    "days": { "cat": "time", "factor": 86400, "label": "d" }
};

var TEMP_UNITS = {
    "c": { "id": "c", "label": "°C" },
    "celsius": { "id": "c", "label": "°C" },
    "f": { "id": "f", "label": "°F" },
    "fahrenheit": { "id": "f", "label": "°F" },
    "k": { "id": "k", "label": "K" },
    "kelvin": { "id": "k", "label": "K" }
};

function convertTemperature(value, fromId, toId) {
    var celsius;
    if (fromId === "c")
        celsius = value;
    else if (fromId === "f")
        celsius = (value - 32) * 5 / 9;
    else
        celsius = value - 273.15;

    if (toId === "c")
        return celsius;
    if (toId === "f")
        return celsius * 9 / 5 + 32;
    return celsius + 273.15;
}

function evaluateUnitConversion(input) {
    var match = input.trim().match(/^(.+?)\s*([a-zA-Z]+)\s+(?:to|in)\s+([a-zA-Z]+)$/i);
    if (!match)
        return null;
    var exprStr = match[1].trim();
    var fromKey = match[2].toLowerCase();
    var toKey = match[3].toLowerCase();
    var parsed = evaluateArithmetic(exprStr);
    if (!parsed.ok)
        return null;

    if (Object.prototype.hasOwnProperty.call(TEMP_UNITS, fromKey) && Object.prototype.hasOwnProperty.call(TEMP_UNITS, toKey)) {
        var fromT = TEMP_UNITS[fromKey];
        var toT = TEMP_UNITS[toKey];
        var tempResult = convertTemperature(parsed.value, fromT.id, toT.id);
        if (!isFinite(tempResult))
            return null;
        return {
            "ok": true,
            "value": tempResult,
            "text": format(tempResult) + " " + toT.label
        };
    }

    if (Object.prototype.hasOwnProperty.call(LINEAR_UNITS, fromKey) && Object.prototype.hasOwnProperty.call(LINEAR_UNITS, toKey)) {
        var fromU = LINEAR_UNITS[fromKey];
        var toU = LINEAR_UNITS[toKey];
        if (fromU.cat !== toU.cat)
            return null;
        var converted = (parsed.value * fromU.factor) / toU.factor;
        if (!isFinite(converted))
            return null;
        return {
            "ok": true,
            "value": converted,
            "text": format(converted) + " " + toU.label
        };
    }

    return null;
}

// Returns { ok: true, value: number, text: string } or
// { ok: false, error: string }. Never throws on bad input.
function evaluate(input) {
    if (typeof input !== "string" || input.trim().length === 0)
        return {
            "ok": false,
            "error": "empty"
        };
    var conv = evaluateUnitConversion(input);
    if (conv)
        return conv;
    return evaluateArithmetic(input);
}

function evaluateArithmetic(input) {
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
    if (evaluateUnitConversion(input) !== null)
        return true;
    if (!/[+\-*\/%()]/.test(input))
        return false;
    return evaluateArithmetic(input).ok;
}

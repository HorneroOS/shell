.pragma library

// Pure number formatting shared by PluginKit Translations (kept free of
// shell singletons so it is exercised directly by qmltestrunner).

// Whole numbers print without a fraction ("17", not "17.00": QML's
// Number.toLocaleString defaults to two decimals); other values keep up to
// `maxDecimals` (default 2) with trailing zeros trimmed. Separator and
// grouping follow `locale` (a Qt locale object).
function number(locale, value, maxDecimals) {
    const n = Number(value);
    if (!isFinite(n))
        return "";
    const decimals = maxDecimals === undefined || maxDecimals === null ? 2 : Math.max(0, Math.floor(maxDecimals));
    if (Number.isInteger(n) || decimals === 0)
        return Math.round(n).toLocaleString(locale, "f", 0);
    const text = n.toLocaleString(locale, "f", decimals);
    const point = locale.decimalPoint;
    const at = text.lastIndexOf(point);
    if (at < 0)
        return text;
    let end = text.length;
    while (end > at + 1 && text[end - 1] === "0")
        end--;
    if (end === at + 1)
        end = at;
    return text.slice(0, end);
}

.pragma library

// Curated accent presets for Appearance > Accent. They are only starting
// points for the user's own accent (appearance.accent); nothing applies
// until the user picks one, and every colour can be replaced by any hex.
// A preset carries one colour per colour mode so it keeps its contrast: the
// pastels are light enough for dark grounds, the deeper twins for light.

var PRESETS = [
    { id: "peach", name: "Peach", group: "kawaii", dark: "#FFB3A0", light: "#C4533A" },
    { id: "mochi", name: "Mochi pink", group: "kawaii", dark: "#FFB5D2", light: "#B83E78" },
    { id: "butter", name: "Butter", group: "kawaii", dark: "#FFE08F", light: "#8F6A00" },
    { id: "matcha", name: "Matcha", group: "kawaii", dark: "#B9E5A0", light: "#3D7A2A" },
    { id: "soda", name: "Soda blue", group: "kawaii", dark: "#A6D6FF", light: "#1F6AA8" },
    { id: "lavender", name: "Lavender", group: "kawaii", dark: "#D2BFFF", light: "#6A47B8" },
    { id: "mint", name: "Mint", group: "kawaii", dark: "#A3EBD4", light: "#1B7A62" }
];

function forMode(preset, mode) {
    return mode === "light" ? preset.light : preset.dark;
}

# Example Companions

A PluginKit 6 **data-only** companion package. It contains two
original characters — Capi, a capybara, and Bitín, a tiny retro
CRT — as validated JSON definitions plus transparent sprite frames.
It contains no executable companion logic: the canonical
`Main.qml` is inert and the Shell never loads it. Trusted native
components render the package data.

See `docs/COMPANION_PLATFORM.md` for the complete authoring
contract. The source sprite sheets and generation prompts are
review evidence, not runtime inputs; the shipped frames were
chroma-keyed, despilled, normalized to a 512 px canvas and
inspected at actual 128 px desktop size on dark and light grounds.

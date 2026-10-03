# Missing theme wallpaper preview

These are matching 1200×540 crops from the same 1200×960 HorneroOS Appearance window, with the Catppuccin Latte theme card hovered and its palette preview settled. They were rendered on 2026-10-02 using the installed Hornero packages and isolated Quickshell/XDG paths under `/tmp`; the unavailable wallpaper is a real missing catalogue asset on this host. The crop keeps the relevant Appearance UI and excludes the unrelated wallpaper collection below it.

- `before-missing-wallpaper.png`: the wallpaper hero was empty, with no reason visible to the user.
- `after-explicit-empty-state.png`: the same hero identifies the missing wallpaper with an icon and “Wallpaper unavailable” while preserving the theme name, description, mode, palette, and advanced details. Theme-list thumbnails without preview art keep their geometry and show a compact unavailable icon.

Unavailable wallpaper tiles are not hover-previewed or selectable, so they cannot stage a broken wallpaper path.

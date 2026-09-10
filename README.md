# shell

The official Hornero OS desktop shell, built with Quickshell, QML and Qt for
Wayland.

## Technologies

- [Quickshell](https://quickshell.org/) + QML + Qt 6
- Wayland, targeting Hyprland
- Native Qt/C++ integrations where QML alone is not enough

## Relationship with dotfiles

This shell will eventually be developed from the reusable Quickshell desktop
shell currently living in
[ulises-jeremias/dotfiles](https://github.com/ulises-jeremias/dotfiles)
(under `home/dot_config/quickshell/`). That migration has **not** happened
yet and will be done deliberately: only the generic, reusable shell moves
here. Personal workstation configuration stays in the dotfiles repository.

## Boundary

The shell is a real desktop component with its own versioning and packaging
lifecycle — not a dotfiles collection. Compositor configuration, terminal
settings and other application defaults belong in
[HorneroOS/config](https://github.com/HorneroOS/config); distribution
composition belongs in [HorneroOS/hornero](https://github.com/HorneroOS/hornero).

## Long-term layout

```text
shell/
├── qml/          # modules, components, services, utils
├── native/       # Qt/C++ integrations
├── assets/       # shell-owned visual assets
├── tests/
└── CMakeLists.txt
```

## Status

Early scaffolding. No shell code lives here yet.

## License

[MIT](LICENSE).

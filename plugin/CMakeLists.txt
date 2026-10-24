add_subdirectory(src/Hornero)

# Stable QML-only extension API. Keep it separate from the internal Hornero
# modules so third-party plugins can import only the reviewed public surface.
install(DIRECTORY qml/Hornero/PluginKit
    DESTINATION "${INSTALL_QMLDIR}/Hornero"
    FILES_MATCHING PATTERN "*.qml" PATTERN "qmldir")

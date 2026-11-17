# Version
add_executable(version version.cpp)
target_compile_definitions(version PRIVATE
    PROJECT_NAME="${PROJECT_NAME}"
    VERSION="${VERSION}"
    GIT_REVISION="${GIT_REVISION}"
    DISTRIBUTOR="${DISTRIBUTOR}"
)
install(TARGETS version DESTINATION ${INSTALL_LIBDIR})

# Hornero Chromatic helper (RFC 0002 §10.1), bench and tests.
add_subdirectory(chromatic)

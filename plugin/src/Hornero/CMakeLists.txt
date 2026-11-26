find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick Concurrent Sql Network DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
# No libcava check: cavaprovider resolves it at runtime via QLibrary
# so a missing/ABI-broken libcava only silences the spectrum.

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

function(qml_module arg_TARGET)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "URI" "SOURCES;LIBRARIES")

    qt_add_qml_module(${arg_TARGET}
        URI ${arg_URI}
        VERSION ${VERSION}
        SOURCES ${arg_SOURCES}
    )

    qt_query_qml_module(${arg_TARGET}
        URI module_uri
        VERSION module_version
        PLUGIN_TARGET module_plugin_target
        TARGET_PATH module_target_path
        QMLDIR module_qmldir
        TYPEINFO module_typeinfo
    )

    message(STATUS "Created QML module ${module_uri}, version ${module_version}")

    set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")
    install(TARGETS ${arg_TARGET} LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
    install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
    install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
    install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")

    target_link_libraries(${arg_TARGET} PRIVATE Qt::Core Qt::Qml ${arg_LIBRARIES})
endfunction()

qml_module(hornero
    URI Hornero
    SOURCES
        cutils.hpp cutils.cpp
        appdb.hpp appdb.cpp
        requests.hpp requests.cpp
        toaster.hpp toaster.cpp
        imageanalyser.hpp imageanalyser.cpp
        translator.hpp translator.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Sql
)

add_subdirectory(Chromatic)
add_subdirectory(Internal)
add_subdirectory(Models)
add_subdirectory(Services)

option(HORNERO_TRANSLATOR_TESTS "Build the shell translator unit tests" ON)
if(HORNERO_TRANSLATOR_TESTS AND EXISTS "${CMAKE_SOURCE_DIR}/tests/i18n/CMakeLists.txt")
    enable_testing()
    add_subdirectory("${CMAKE_SOURCE_DIR}/tests/i18n" "${CMAKE_BINARY_DIR}/tests/i18n")
endif()

# Hornero Chromatic engine (RFC 0002 §3): decode, analysis, inference,
# synthesis and the contrast solver. Qt6 Core/Gui only, no QML.
find_package(Qt6 REQUIRED COMPONENTS Core Gui)

# The gate table (vendored from HorneroOS/config) is compiled in as a
# string constant so the library needs no resource initialisation.
set(CHROMATIC_GATES_JSON "${CMAKE_CURRENT_SOURCE_DIR}/data/contrast-gates.json")
set(CHROMATIC_GATES_HEADER "${CMAKE_CURRENT_BINARY_DIR}/generated/chromatic_gates_data.hpp")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CHROMATIC_GATES_JSON}")
file(READ "${CHROMATIC_GATES_JSON}" CHROMATIC_GATES_CONTENT)
file(WRITE "${CHROMATIC_GATES_HEADER}.in"
    "// Generated from data/contrast-gates.json — do not edit.\n"
    "#pragma once\n"
    "namespace hornero::chromatic::detail {\n"
    "inline constexpr const char kContrastGatesJson[] = R\"gates(${CHROMATIC_GATES_CONTENT})gates\";\n"
    "}\n")
configure_file("${CHROMATIC_GATES_HEADER}.in" "${CHROMATIC_GATES_HEADER}" COPYONLY)

add_library(hornero_chromatic STATIC
    include/hornero/chromatic/analysis.hpp src/analysis.cpp
    include/hornero/chromatic/cache.hpp src/cache.cpp
    include/hornero/chromatic/colour.hpp src/colour.cpp
    include/hornero/chromatic/engine.hpp src/engine.cpp
    include/hornero/chromatic/expected.hpp
    include/hornero/chromatic/json.hpp src/json.cpp
    include/hornero/chromatic/request.hpp src/request.cpp
    include/hornero/chromatic/solver.hpp src/solver.cpp
    include/hornero/chromatic/source.hpp src/source.cpp
    include/hornero/chromatic/synth.hpp src/synth.cpp
    "${CHROMATIC_GATES_HEADER}"
)
target_include_directories(hornero_chromatic
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"
    PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/generated"
)
target_compile_features(hornero_chromatic PUBLIC cxx_std_20)
set_target_properties(hornero_chromatic PROPERTIES POSITION_INDEPENDENT_CODE ON AUTOMOC OFF)
target_compile_definitions(hornero_chromatic PRIVATE QT_NO_CAST_FROM_ASCII QT_NO_CAST_TO_ASCII)
target_link_libraries(hornero_chromatic PUBLIC Qt6::Core Qt6::Gui)

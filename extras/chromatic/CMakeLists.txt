find_package(Qt6 REQUIRED COMPONENTS Core Gui)

# Internal helper for horneroctl: /usr/lib/hornero/hornero-chromatic.
add_executable(hornero-chromatic main.cpp)
target_link_libraries(hornero-chromatic PRIVATE hornero_chromatic Qt6::Core Qt6::Gui)
install(TARGETS hornero-chromatic DESTINATION ${INSTALL_LIBDIR})

# Benchmark (not installed): prints JSON timings for tests/test_chromatic_perf.py.
add_executable(chromatic-bench bench.cpp)
target_link_libraries(chromatic-bench PRIVATE hornero_chromatic Qt6::Core Qt6::Gui)

option(HORNERO_CHROMATIC_TESTS "Build the Hornero Chromatic corpus generator and unit tests" ON)
if(HORNERO_CHROMATIC_TESTS AND EXISTS "${CMAKE_SOURCE_DIR}/tests/chromatic/CMakeLists.txt")
    add_subdirectory("${CMAKE_SOURCE_DIR}/tests/chromatic" "${CMAKE_BINARY_DIR}/tests/chromatic")
endif()

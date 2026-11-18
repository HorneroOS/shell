# QtTest unit suite for the spectrum meter ballistics (not installed).
# The maths is plain C++, so the test compiles the one source file directly
# instead of linking the QML plugin.
find_package(Qt6 REQUIRED COMPONENTS Core Test)

add_executable(spectrum-unit
    unit/test_spectrum.cpp
    "${CMAKE_SOURCE_DIR}/plugin/src/Hornero/Internal/spectrumballistics.cpp"
)
target_include_directories(spectrum-unit PRIVATE "${CMAKE_SOURCE_DIR}/plugin/src/Hornero/Internal")
set_target_properties(spectrum-unit PROPERTIES AUTOMOC ON)
target_link_libraries(spectrum-unit PRIVATE Qt6::Core Qt6::Test)
add_test(NAME spectrum-unit COMMAND spectrum-unit)
set_tests_properties(spectrum-unit PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

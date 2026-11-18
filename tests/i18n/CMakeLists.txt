# QtTest unit suite for the shell translator (ctest target translator-unit).
# Compiles translator.cpp directly so the test does not need the QML plugin.
find_package(Qt6 REQUIRED COMPONENTS Core Qml Test)

add_executable(translator-unit
    unit/test_translator.cpp
    "${CMAKE_SOURCE_DIR}/plugin/src/Hornero/translator.cpp"
    "${CMAKE_SOURCE_DIR}/plugin/src/Hornero/translator.hpp")
set_target_properties(translator-unit PROPERTIES AUTOMOC ON)
target_include_directories(translator-unit PRIVATE "${CMAKE_SOURCE_DIR}/plugin/src/Hornero")
target_compile_definitions(translator-unit PRIVATE
    HORNERO_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
target_link_libraries(translator-unit PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
add_test(NAME translator-unit COMMAND translator-unit)

# Hornero Chromatic test support (not installed): the synthetic corpus
# generator used by tests/test_chromatic_*.py and the QtTest unit suite
# (ctest target chromatic-unit).
find_package(Qt6 REQUIRED COMPONENTS Core Gui Test)

add_executable(chromatic-corpus corpus.cpp)
target_link_libraries(chromatic-corpus PRIVATE Qt6::Core Qt6::Gui)

add_executable(chromatic-unit unit/test_chromatic.cpp)
set_target_properties(chromatic-unit PROPERTIES AUTOMOC ON)
target_link_libraries(chromatic-unit PRIVATE hornero_chromatic Qt6::Core Qt6::Gui Qt6::Test)
add_test(NAME chromatic-unit COMMAND chromatic-unit)
set_tests_properties(chromatic-unit PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

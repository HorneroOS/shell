qml_module(hornero-internal
    URI Hornero.Internal
    SOURCES
        cachingimagemanager.hpp cachingimagemanager.cpp
        circularindicatormanager.hpp circularindicatormanager.cpp
        hyprdevices.hpp hyprdevices.cpp
        hyprextras.hpp hyprextras.cpp
        logindmanager.hpp logindmanager.cpp
        spectrumballistics.hpp spectrumballistics.cpp
        spectrummeter.hpp spectrummeter.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
        Qt::DBus
)

# QtTest unit suite for the spectrum ballistics (ctest: spectrum-unit).
option(HORNERO_SPECTRUM_TESTS "Build the spectrum meter unit tests" ON)
if(HORNERO_SPECTRUM_TESTS AND EXISTS "${CMAKE_SOURCE_DIR}/tests/spectrum/CMakeLists.txt")
    enable_testing()
    add_subdirectory("${CMAKE_SOURCE_DIR}/tests/spectrum" "${CMAKE_BINARY_DIR}/tests/spectrum")
endif()

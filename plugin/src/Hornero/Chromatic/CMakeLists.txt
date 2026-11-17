qml_module(hornero-chromatic-qml
    URI Hornero.Chromatic
    SOURCES
        chromaticengine.hpp chromaticengine.cpp
        chromaticjob.hpp chromaticjob.cpp
        chromaticrequest.hpp chromaticrequest.cpp
    LIBRARIES
        Qt::Gui
        hornero_chromatic
)

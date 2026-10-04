import qs.utils
import Hornero.Internal
import Quickshell
import QtQuick

Image {
    id: root

    property alias path: manager.path

    asynchronous: true
    fillMode: Image.PreserveAspectCrop

    Connections {
        target: QsWindow.window

        function onDevicePixelRatioChanged(): void {
            manager.updateSource();
        }
    }

    // Cache entries are derived from the image source and regenerate on miss.
    // Source paths are stored as absolute paths in the Hornero cache index.
    CachingImageManager {
        id: manager

        item: root
        cacheDir: Qt.resolvedUrl(Paths.imagecache)
    }
}

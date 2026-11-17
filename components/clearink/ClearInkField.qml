import QtQuick
import "../../services/clearink.js" as Model

// Wallpaper luminance field of one clear bar (signal-visual-language
// §12.1/§12.5). When the wallpaper or the screen size changes (never per
// frame) the wallpaper is drawn once, cover-cropped to the screen, into a
// small canvas and reduced to a luminance grid; per-region mean and
// deviation are lookups into that grid. Video wallpapers and unreadable
// files leave the grid empty: tones then follow the theme polarity and keep
// the halo and soft shadow on.
Item {
    id: root

    // Screen-space size of the window the bar lives in.
    required property real screenWidth
    required property real screenHeight
    property string source: ""
    // Only clear bars sample; solid bars never decode the wallpaper.
    property bool active: true

    property var grid: null
    // Bumped when the grid or the layout changed; tones bind to it.
    property int revision: 0
    readonly property bool ready: grid !== null
    readonly property int columns: Model.GRID_COLUMNS
    readonly property int rows: Model.rowsFor(screenWidth, screenHeight)

    visible: false
    width: 0
    height: 0

    // Screen-space rectangle of `item` (the bar window is full screen).
    function rectOf(item: Item): var {
        const p = item.mapToItem(null, 0, 0);
        return {
            x: p.x,
            y: p.y,
            width: item.width,
            height: item.height
        };
    }

    function statsFor(item: Item): var {
        if (!root.grid || !item || item.width <= 0 || item.height <= 0)
            return null;
        return Model.regionStats(root.grid, root.rectOf(item), root.screenWidth, root.screenHeight, Model.REGION_PAD);
    }

    // Layout changed somewhere above a tone's target; coalesced.
    function poke(): void {
        if (root.active)
            pokeTimer.restart();
    }

    function resample(): void {
        root.grid = null;
        root.revision++;
        if (!root.active || !root.source || root.rows <= 0 || !/\.(png|jpe?g|webp|bmp|gif|avif|tiff?)$/i.test(root.source))
            return;
        sampler.begin(root.source);
    }

    onActiveChanged: resampleTimer.restart()
    onSourceChanged: resampleTimer.restart()
    onScreenWidthChanged: resampleTimer.restart()
    onScreenHeightChanged: resampleTimer.restart()
    Component.onCompleted: resampleTimer.restart()

    Timer {
        id: pokeTimer

        interval: 120
        onTriggered: root.revision++
    }

    Timer {
        id: resampleTimer

        interval: 200
        onTriggered: root.resample()
    }

    // Aspect probe: a tiny decode that tells the canvas how to cover-crop
    // the wallpaper to the screen aspect (Image.PreserveAspectCrop).
    Image {
        id: probe

        source: sampler.url
        asynchronous: true
        sourceSize: Qt.size(64, 64)
        visible: false
        onStatusChanged: sampler.requestPaint()
    }

    Canvas {
        id: sampler

        property string url: ""

        function begin(path: string): void {
            if (url !== "")
                unloadImage(url);
            url = path.startsWith("file://") ? path : `file://${path}`;
            loadImage(url);
            requestPaint();
        }

        width: root.columns
        height: Math.max(1, root.rows)
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        visible: false

        onImageLoaded: requestPaint()
        onPaint: {
            if (url === "" || !isImageLoaded(url) || probe.status !== Image.Ready || probe.implicitHeight <= 0)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // Cover-fit: scale to fill, centre, let the canvas clip.
            const imageAspect = probe.implicitWidth / probe.implicitHeight;
            const canvasAspect = width / height;
            const dw = imageAspect > canvasAspect ? height * imageAspect : width;
            const dh = imageAspect > canvasAspect ? height : width / imageAspect;
            ctx.drawImage(url, (width - dw) / 2, (height - dh) / 2, dw, dh);
            root.grid = Model.buildGrid(ctx.getImageData(0, 0, width, height).data, width, height);
            root.revision++;
            // Release the full-size decode; only the grid is kept.
            unloadImage(url);
            url = "";
        }
    }
}

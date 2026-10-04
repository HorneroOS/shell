pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtMultimedia
import Quickshell.Services.UPower

Item {
    id: root

    property string source: Wallpapers.current
    property var current
    property bool completed

    onSourceChanged: {
        if (!source) {
            if (current) {
                current.destroy();
                current = null;
            }
            return;
        }
        if (Images.isVideo(source))
            current = videoComp.createObject(this, { path: source });
        else if (Images.isAnimatedImage(source))
            current = animatedImgComp.createObject(this, { path: source });
        else
            current = imgComp.createObject(this, { path: source });
    }

    Component.onCompleted: {
        completed = true;
        if (!current && source) {
            Qt.callLater(() => {
                if (!current && source) {
                    if (Images.isVideo(source))
                        current = videoComp.createObject(this, { path: source });
                    else if (Images.isAnimatedImage(source))
                        current = animatedImgComp.createObject(this, { path: source });
                    else
                        current = imgComp.createObject(this, { path: source });
                }
            });
        }
    }

    // No wallpaper set: prompt the user
    Loader {
        anchors.fill: parent
        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surface

            StyledRect {
                anchors.centerIn: parent
                width: Math.max(0, Math.min(420, parent.width - Appearance.padding.large * 2))
                implicitHeight: emptyContent.implicitHeight + Appearance.padding.large * 2
                radius: Appearance.rounding.large
                color: Colours.palette.m3surfaceContainer

                Column {
                    id: emptyContent

                    anchors.centerIn: parent
                    width: parent.width - Appearance.padding.large * 2
                    spacing: Appearance.spacing.normal

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "wallpaper"
                        color: Colours.palette.m3primary
                        font.pointSize: 40
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Choose a wallpaper")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.large
                        font.bold: true
                    }

                    StyledText {
                        width: parent.width
                        text: qsTr("Pick an image or video for your desktop background.")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.small * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image & video files")
                            filters: Images.validWallpaperExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            Accessible.name: qsTr("Choose wallpaper")

                            function onClicked(): void {
                                dialog.open();
                            }
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Browse wallpapers")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Appearance.font.size.normal
                        }
                    }
                }
            }
        }
    }

    // ── Video wallpaper (mp4/mkv/webm/avi/mov) ──────────────────────────
    Component {
        id: videoComp

        Item {
            id: vidRoot

            property string path
            readonly property bool isReady: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.playbackState === MediaPlayer.PlayingState || player.playbackState === MediaPlayer.PausedState
            anchors.fill: parent
            opacity: 0

            onIsReadyChanged: {
                if (isReady && opacity === 0)
                    fadeInVid.start();
            }

            MediaPlayer {
                id: player

                source: vidRoot.path ? `file://${vidRoot.path}` : ""
                videoOutput: videoOutput
                audioOutput: null
                loops: MediaPlayer.Infinite

                readonly property bool isCovered: {
                    try {
                        if (!Config.background.video.enabled)
                            return false;

                        if (Config.background.video.pauseOnGameMode && GameMode.enabled)
                            return true;

                        if (Config.background.video.batteryLimitEnabled && Config.background.video.batteryLimit > 0 && UPower.displayDevice && UPower.displayDevice.isPresent && UPower.displayDevice.isLaptopBattery) {
                            if (UPower.displayDevice.state === UPowerDeviceState.Discharging && (UPower.displayDevice.percentage * 100) <= Config.background.video.batteryLimit)
                                return true;
                        }

                        if (Config.background.video.pauseOnFullscreen && Hypr.activeToplevel && Hypr.activeToplevel.lastIpcObject && Hypr.activeToplevel.lastIpcObject.fullscreen) {
                            const winClass = (Hypr.activeToplevel.lastIpcObject.class || "").toLowerCase();
                            const browsers = ["firefox", "brave", "chromium", "chrome", "zen", "thorium", "vivaldi", "opera", "floorp", "waterfox", "librewolf", "edge"];
                            if (browsers.some(b => winClass.includes(b)))
                                return false;
                            return true;
                        }

                        return false;
                    } catch (e) {
                        return false;
                    }
                }

                onIsCoveredChanged: {
                    if (isCovered)
                        player.pause();
                    else if (root.current === vidRoot)
                        player.play();
                }

                onErrorOccurred: (error, errorString) => {
                    if (error !== MediaPlayer.NoError && vidRoot.path) {
                        const p = vidRoot.path;
                        vidRoot.path = "";
                        Qt.callLater(() => {
                            vidRoot.path = p;
                            if (!player.isCovered)
                                player.play();
                        });
                    }
                }

                Component.onCompleted: {
                    play();
                    if (isCovered) {
                        Qt.callLater(() => {
                            if (isCovered)
                                pause();
                        });
                    }
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState)
                        fadeInVid.start();
                }

                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                        fadeInVid.start();
                }
            }

            VideoOutput {
                id: videoOutput

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            NumberAnimation {
                id: fadeInVid

                target: vidRoot
                property: "opacity"
                duration: Appearance.anim.durations.extraLarge
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== vidRoot && root.current?.isReady
                interval: fadeInVid.duration || 500
                onTriggered: {
                    player.stop();
                    player.source = "";
                    vidRoot.destroy();
                }
            }
        }
    }

    // ── Animated image wallpaper (gif/apng) ─────────────────────────────
    // AnimatedImage plays the frames via QMovie; CachingImage would pin a
    // single cached frame and plain Image would only show the first one.
    Component {
        id: animatedImgComp

        AnimatedImage {
            id: animImg

            property string path
            property bool isReady: status === Image.Ready && path !== ""

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: path ? path : ""
            playing: true
            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    fadeInAnimImg.start();
            }

            Anim on opacity {
                id: fadeInAnimImg

                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== animImg && root.current?.isReady
                interval: fadeInAnimImg.duration || 500
                onTriggered: {
                    animImg.source = "";
                    animImg.destroy();
                }
            }
        }
    }

    // ── Static image wallpaper ──────────────────────────────────────────
    Component {
        id: imgComp

        CachingImage {
            id: img

            property bool isReady: status === Image.Ready

            anchors.fill: parent
            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    fadeInImg.start();
            }

            Anim on opacity {
                id: fadeInImg

                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.current?.isReady
                interval: fadeInImg.duration || 500
                onTriggered: {
                    img.source = "";
                    img.destroy();
                }
            }
        }
    }
}
